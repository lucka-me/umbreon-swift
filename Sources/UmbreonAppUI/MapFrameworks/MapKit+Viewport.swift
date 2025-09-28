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
#endif

#if !canImport(MapboxMaps)
typealias Viewport = MapCameraPosition
#endif

extension Viewport {
#if !canImport(MapboxMaps)
    static var idle: Self {
        .automatic
    }
#endif
    
    static func camera(center: CLLocationCoordinate2D, verticalPosition: Double) -> Self {
#if canImport(MapboxMaps)
        .camera(center: center, zoom: verticalPosition)
#else
        .camera(.init(centerCoordinate: center, distance: verticalPosition))
#endif
    }
    
#if !canImport(MapboxMaps)
    var isIdle: Bool {
        !followsUserLocation
    }
#endif
}
