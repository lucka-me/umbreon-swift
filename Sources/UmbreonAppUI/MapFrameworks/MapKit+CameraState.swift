//
//  MapKit+CameraState.swift
//  UmbreonAppUI
//
//  Created by Lucka on 23/3/2025.
//

import SphereGeometry

#if canImport(MapboxMaps)
import MapboxMaps
#else
import MapKit
import SwiftUI
import Turf
#endif

#if !canImport(MapboxMaps)
typealias CameraState = MapCamera
#endif

extension CameraState {
    init(center: LocationCoordinate2D, verticalPosition: Double) {
#if canImport(MapboxMaps)
        self.init(
            center: center,
            padding: .zero,
            zoom: verticalPosition,
            bearing: .zero,
            pitch: .zero
        )
#else
        self.init(centerCoordinate: center, distance: verticalPosition)
#endif
    }
}

extension CameraState {
    static func zoom(of distance: Double) -> CGFloat {
        log2((Earth.radius * 2 * .pi) / distance) + 1
    }
    
    static func distance(of zoom: CGFloat) -> Double {
        (Earth.radius * 2 * .pi) / Darwin.pow(2, zoom)
    }
}

extension CameraState {
    var verticalPosition: Double {
#if canImport(MapboxMaps)
        zoom
#else
        distance
#endif
    }
    
#if !canImport(MapboxMaps)
    var center: LocationCoordinate2D {
        centerCoordinate
    }
    
    var zoom: CGFloat {
        Self.zoom(of: self.distance)
    }
#endif
}
