//
//  MapKit+CameraState.swift
//  UmbreonAppUI
//
//  Created by Lucka on 23/3/2025.
//

#if canImport(MapboxMaps)
import MapboxMaps
#else
import MapKit
import SphereGeometry
import SwiftUI
#endif

#if !canImport(MapboxMaps)
typealias CameraState = MapCamera
#endif

extension CameraState {
    var verticalPosition: Double {
#if canImport(MapboxMaps)
        zoom
#else
        distance
#endif
    }
    
#if !canImport(MapboxMaps)
    var center: CLLocationCoordinate2D {
        centerCoordinate
    }
    
    var zoom: CGFloat {
        log2((Earth.radius * 2 * .pi) / self.distance) + 1
    }
#endif
}
