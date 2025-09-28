//
//  SphereGeometryDemoMap.swift
//  UmbreonAppUI
//
//  Created by Lucka on 11/9/2025.
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

public struct SphereGeometryDemoMap : View {
    @Binding private var value: CellIdentifier
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var viewport = Viewport.idle
    @State private var cellPolygon = PlottablePolygon.world
    
    @StateObject private var baseMapDefaults = BaseMapAppearanceDefaults.shared
    @StateObject private var umbraDefaults = UmbraAppearanceDefaults.shared
    
    private var followCamera: Bool = false
    
    public init(_ value: Binding<CellIdentifier>) {
        self._value = value
    }
    
    public var body: some View {
        mapContent
            .onChange(of: value, initial: true, handleValueChanged)
    }
}

public extension SphereGeometryDemoMap {
    func followCamera(
        _ follow: Bool
    ) -> Self {
        copy(assigning: \.followCamera, to: follow)
    }
}

#if canImport(MapboxMaps)
fileprivate extension SphereGeometryDemoMap {
    @ViewBuilder
    private var mapContent: some View {
        Map(viewport: $viewport) {
            PolygonAnnotation(polygon: cellPolygon)
                .fillColor(umbraDefaults.color(in: colorScheme))
                .fillOpacity(umbraDefaults.opacity)
                .fillOutlineColor(.clear)
        }
        .cameraBounds(.init(maxPitch: 0, minPitch: 0))
        .mapStyle(baseMapDefaults.resolvedMapStyle(in: colorScheme))
        .onCameraChanged { event in
            handleCameraChanged(event.cameraState.center)
        }
    }
}
#else
fileprivate extension SphereGeometryDemoMap {
    @ViewBuilder
    private var mapContent: some View {
        Map(position: $viewport) {
            MapPolygon(cellPolygon)
                .foregroundStyle(umbraDefaults.color(in: colorScheme))
        }
        .mapControls {
            MapScaleView()
            MapCompass()
        }
        .mapStyle(baseMapDefaults.resolvedMapStyle(in: colorScheme))
        .onMapCameraChange(frequency: .continuous) { event in
            handleCameraChanged(event.camera.centerCoordinate)
        }
    }
}
#endif

fileprivate extension SphereGeometryDemoMap {
    func handleValueChanged() {
        let cell = value.cell
        self.cellPolygon = .init(outerRing: cell.plottableRing)
        
        guard !followCamera else {
            return
        }
        
        let viewport = Viewport.camera(
            center: cell.center.locationCoordinate,
            verticalPosition: cell.level.preferredVerticalPosition
        )
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
    
    func handleCameraChanged(_ center: LocationCoordinate2D) {
        guard followCamera else {
            return
        }
        
        self.value = .init(
            center.cartesianCoordinate,
            at: value.level
        )
    }
}

fileprivate extension SphereGeometryDemoMap {
    private func copy<Value>(
        assigning keyPath: WritableKeyPath<Self, Value>,
        to value: Value
    ) -> Self {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}

fileprivate extension Level {
    var preferredVerticalPosition: Double {
#if canImport(MapboxMaps)
        Swift.min(Swift.max(Double(rawValue), 0), 22)
#else
        Earth.radius * .pi * pow(2, 1 - Double(rawValue))
#endif
    }
}
