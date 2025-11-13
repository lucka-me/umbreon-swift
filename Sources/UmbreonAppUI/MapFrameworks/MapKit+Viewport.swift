//
//  MapKit+Viewport.swift
//  UmbreonAppUI
//
//  Created by Lucka on 23/3/2025.
//

#if canImport(MapboxMaps)
import MapboxMaps
#else
import MapKit
import SwiftUI
import Turf
#endif

#if !canImport(MapboxMaps)
typealias Viewport = MapCameraPosition
#endif

extension Viewport {
    static var `default`: Self {
#if canImport(MapboxMaps)
        .idle
#else
        .automatic
#endif
    }
}

extension Viewport {
    static func camera(cameraState: CameraState) -> Self {
        .camera(center: cameraState.center, verticalPosition: cameraState.verticalPosition)
    }
    
    static func camera(center: CLLocationCoordinate2D, verticalPosition: Double) -> Self {
#if canImport(MapboxMaps)
        .camera(center: center, zoom: verticalPosition)
#else
        .camera(.init(centerCoordinate: center, distance: verticalPosition))
#endif
    }
}

extension Viewport {
#if canImport(MapboxMaps)
    static let followsUserMinZoom: CGFloat = 12
#else
    static let followsUserMaxDistance: Double = CameraState.distance(of: 12)
#endif
    
    static func followsUser(
        fallback center: LocationCoordinate2D?,
        verticalPosition: Double
    ) -> Self {
#if canImport(MapboxMaps)
        .followPuck(zoom: max(verticalPosition, followsUserMinZoom))
#else
        if let center {
            .userLocation(
                fallback: .camera(
                    center: center,
                    verticalPosition: min(verticalPosition, followsUserMaxDistance)
                )
            )
        } else {
            .userLocation(fallback: .automatic)
        }
#endif
    }
}
    
extension Viewport {
    static func idle(at currentCamera: CameraState?) -> Self {
#if canImport(MapboxMaps)
        .idle
#else
        if let currentCamera {
            .camera(cameraState: currentCamera)
        } else {
            .automatic
        }
#endif
    }
    
#if !canImport(MapboxMaps)
    var isIdle: Bool {
        positionedByUser
    }
#endif
}

extension Viewport {
    static func overview(boundingBox: BoundingBox) -> Self {
#if canImport(MapboxMaps)
        .overview(
            geometry: LineString([ boundingBox.southWest, boundingBox.northEast ]),
            geometryPadding: .init(top: 40, leading: 6, bottom: 40, trailing: 6)
        )
#else
        .region(boundingBox.coordinateRegion)
#endif
    }
}

#if !canImport(MapboxMaps)
fileprivate extension BoundingBox {
    var coordinateRegion: MKCoordinateRegion {
        var center = CLLocationCoordinate2D(
            latitude: (northEast.latitude + southWest.latitude) / 2,
            longitude: (northEast.longitude + southWest.longitude) / 2
        )
        var span = MKCoordinateSpan(
            latitudeDelta: northEast.latitude - southWest.latitude,
            longitudeDelta: northEast.longitude - southWest.longitude
        )
        if northEast.longitude < southWest.longitude {
            center.longitude += 180
            span.longitudeDelta += 360
        }
        
        return .init(center: center, span: span)
    }
}
#endif

