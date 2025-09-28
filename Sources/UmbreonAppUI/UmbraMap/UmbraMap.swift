//
//  UmbraMap.swift
//  UmbreonAppUI
//
//  Created by Lucka on 1/9/2024.
//

import CoreLocation
import SphereGeometry
import SwiftUI

#if canImport(MapboxMaps)
import MapboxMaps
#else
import MapKit
import Turf
#endif

public struct UmbraMap : View {
    @Binding private var cameraProposal: MapCameraProposal
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var context = Context()
    @State private var datasetUpdate = UmbraDataset.UpdateSubject()
    @State private var viewport = Viewport.idle
    
    @State private var umbra = PlottablePolygon.world
    
    @StateObject private var baseMapDefaults = BaseMapAppearanceDefaults.shared
    @StateObject private var umbraDefaults = UmbraAppearanceDefaults.shared
    
    private let makeDataset: @Sendable () -> UmbraDataset
    
    private var showPuck: Bool = false
    private var storeCamera: ((CLLocationCoordinate2D, Double) -> Void)? = nil
    
    public init<Dataset: UmbraDataset>(
        camera: Binding<MapCameraProposal> = .constant(.idle),
        dataset: @autoclosure @escaping @Sendable () -> Dataset
    ) {
        self._cameraProposal = camera
        self.makeDataset = dataset
    }
    
    public var body: some View {
        mapContent
            .onAppear(perform: setupView)
            .onChange(of: cameraProposal, handleCameraProposal)
            .onChange(of: viewport, handleViewport)
            .onDisappear(perform: terminate)
            .task(priority: .high, viewTask)
            .onReceive(datasetUpdate, perform: context.requestUpdate(in:))
    }
}
    
public extension UmbraMap {
    func onCameraDisappear(
        perform action: @escaping (CLLocationCoordinate2D, Double) -> Void
    ) -> Self {
        copy(assigning: \.storeCamera, to: action)
    }
    
    func showPuck(_ show: Bool) -> Self {
        copy(assigning: \.showPuck, to: show)
    }
}

#if canImport(MapboxMaps)
fileprivate extension UmbraMap {
    @ViewBuilder
    private var mapContent: some View {
        MapReader { proxy in
            Map(viewport: $viewport) {
                if showPuck {
                    Puck2D(bearing: .heading)
                        .showsAccuracyRing(true)
                }
                
                GeoJSONSource(id: "umbra")
                    .data(.feature(.init(geometry: umbra)))
                
                FillLayer(id: "umbra-fill", source: "umbra")
                    .fillColor(umbraDefaults.color(in: colorScheme))
                    .fillOpacity(umbraDefaults.opacity)
                    .fillOutlineColor(.clear)
            }
            .cameraBounds(.init(maxPitch: 0, minPitch: 0))
            .mapStyle(baseMapDefaults.resolvedMapStyle(in: colorScheme))
            .onCameraChanged { event in
                guard
                    let map = proxy.map,
                    event.cameraState != context.latestCamera
                else {
                    return
                }
                context.handleCameraChanged(event.cameraState, in: map)
            }
            .onAppear {
                if let map = proxy.map {
                    context.handleCameraChanged(map.cameraState, in: map)
                }
            }
        }
    }
}
#else
fileprivate extension UmbraMap {
    @ViewBuilder
    private var mapContent: some View {
        Map(position: $viewport) {
            if showPuck {
                UserAnnotation()
            }
            
            MapPolygon(umbra)
                .foregroundStyle(umbraDefaults.color(in: colorScheme))
        }
        .mapControls {
            MapScaleView()
            MapCompass()
        }
        .mapStyle(baseMapDefaults.resolvedMapStyle(in: colorScheme))
        .onMapCameraChange(frequency: .continuous) { update in
            guard update.camera != context.latestCamera else {
                return
            }
            context.handleCameraChanged(update)
        }
    }
}
#endif

fileprivate extension UmbraMap {
    func setupView() {
        guard !cameraProposal.isReportedByMap else {
            return
        }
        self.viewport = cameraProposal.viewport(currentZoom: nil)
    }
    
    func terminate() {
        if let camera = context.latestCamera {
            storeCamera?(camera.center, camera.verticalPosition)
        }
        context.terminate()
    }
    
    nonisolated private func viewTask() async {
        let dataset = makeDataset()
        let requests = await MainActor.run {
            if let updateSubject = dataset.updateSubject {
                datasetUpdate = updateSubject
            }
            return context.requests
        }
        
        let provider = UmbraProvider(dataset: dataset)
        
        for await request in requests {
            guard let request else {
                break
            }
            
            do {
                guard try await provider.request(request) else {
                    continue
                }
            } catch {
                print(error)
            }
            
            let shape = PlottablePolygon(
                outerRing: .world,
                innerRings: await provider.rings
            )
            
            await MainActor.run {
                self.umbra = shape
            }
        }
    }
}

fileprivate extension UmbraMap {
    private func handleCameraProposal() {
        guard !cameraProposal.isReportedByMap else {
            return
        }
        let viewport = cameraProposal.viewport(currentZoom: context.latestCamera?.zoom)
#if canImport(MapboxMaps)
        withViewportAnimation(.fly) {
            self.viewport = viewport
        }
#else
        withAnimation(.easeInOut) {
            self.viewport = viewport
        }
#endif
    }
    
    private func handleViewport() {
        if viewport.isIdle, !cameraProposal.isReportedByMap {
            // Be triggered by user panning
            cameraProposal = .pannedByUser
        }
    }
}

fileprivate extension UmbraMap {
    private func copy<Value>(
        assigning keyPath: WritableKeyPath<Self, Value>,
        to value: Value
    ) -> Self {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}

fileprivate final class Context {
    typealias Request = UmbraProvider.Request
    typealias Requests = AsyncStream<Request?>
    
    let requests: Requests
    
    private(set) var latestCamera: CameraState? = nil
    
    private let continuation: Requests.Continuation
    
    init() {
        let (stream, continuation) = Requests.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.requests = stream
        self.continuation = continuation
    }
    
#if canImport(MapboxMaps)
    func handleCameraChanged(_ camera: CameraState, in map: MapboxMap) {
        latestCamera = camera
        
        continuation.yield(
            .camaraChanged(
                range: map.requestRange(for: camera),
                resolution: camera.preferredResolution
            )
        )
    }
#else
    func handleCameraChanged(_ context: MapCameraUpdateContext) {
        latestCamera = context.camera
        
        continuation.yield(
            .camaraChanged(
                range: context.requestRange,
                resolution: context.camera.preferredResolution
            )
        )
    }
#endif
    
    func requestUpdate(in cells: CellCollection) {
        continuation.yield(.datasetInserted(cells: cells))
    }
    
    func terminate() {
        continuation.yield(nil)
        continuation.finish()
    }
}

fileprivate extension CameraState {
    var preferredResolution: Level {
        .clamp(.init(floor(zoom)) + 6, max: .visibleResolution)
    }
}

fileprivate extension Level {
    static let visibleResolution = Self.at.18
}

fileprivate extension LocationCoordinate2D {
     static func wrap(latitude: LocationDegrees, longitude: LocationDegrees) -> Self {
        let wrapped = if longitude < -180 {
            longitude + 360
        } else if longitude > 180 {
            longitude - 360
        } else {
            longitude
        }
        
        return .init(latitude: latitude, longitude: wrapped)
    }
}

#if canImport(MapboxMaps)
fileprivate extension MapboxMap {
    func requestRange(for cameraState: CameraState) -> UmbraProvider.RequestRange {
        guard cameraState.zoom >= 3 else {
            return .world
        }
        
        let bounds = coordinateBoundsUnwrapped(for: .init(cameraState: cameraState))
        let latitudeSpan = bounds.latitudeSpan
        let north = min(bounds.north + latitudeSpan, 90)
        let south = max(bounds.south - latitudeSpan, -90)
        
        let longitudeSpan = bounds.longitudeSpan
        let east: LocationDegrees
        let west: LocationDegrees
        if longitudeSpan < 120 {
            east = bounds.east + longitudeSpan
            west = bounds.west - longitudeSpan
        } else {
            east = 180
            west = -180
        }
        
        return .regional(
            box: .init(
                southWest: .wrap(latitude: south, longitude: west),
                northEast: .wrap(latitude: north, longitude: east)
            )
        )
    }
}
#else
fileprivate extension MapCameraUpdateContext {
    var requestRange: UmbraProvider.RequestRange {
        guard camera.zoom > 3 else {
            return .world
        }
        
        let center = region.center
        let span = region.span
        
        let north = min(center.latitude + span.latitudeDelta, 90)
        let south = max(center.latitude - span.latitudeDelta, -90)
        
        let east: LocationDegrees
        let west: LocationDegrees
        if span.longitudeDelta < 180 {
            east = center.longitude + span.longitudeDelta
            west = center.longitude - span.longitudeDelta
        } else {
            east = 180
            west = -180
        }
        
        return .regional(
            box: .init(
                southWest: .wrap(latitude: south, longitude: west),
                northEast: .wrap(latitude: north, longitude: east)
            )
        )
    }
}
#endif
