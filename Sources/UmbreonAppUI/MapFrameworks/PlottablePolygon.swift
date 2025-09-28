//
//  PlottablePolygon.swift
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

#if canImport(MapboxMaps)
typealias PlottablePolygon = Polygon
#else
typealias PlottablePolygon = MKPolygon
#endif

extension PlottablePolygon {
    static var world: PlottablePolygon {
        .init(outerRing: .world)
    }
}

#if !canImport(MapboxMaps)
extension PlottablePolygon {
    convenience init(outerRing: Ring, innerRings: [ Ring ] = [ ]) {
        self.init(
            coordinates: outerRing.coordinates,
            count: outerRing.coordinates.count,
            interiorPolygons: innerRings.map {
                .init(coordinates: $0.coordinates, count: $0.coordinates.count)
            }
        )
    }
}
#endif

extension Ring {
#if canImport(MapboxMaps)
    static let world = Ring(coordinates: CoordinateBounds.world.shape)
#else
    static let world = Ring(
        coordinates: [
            .init(latitude: -90, longitude: -180),
            .init(latitude: -90, longitude:    0),
            .init(latitude: -90, longitude:  180),
            .init(latitude:  90, longitude:  180),
            .init(latitude:  90, longitude:    0),
            .init(latitude:  90, longitude: -180),
            .init(latitude: -90, longitude: -180),
        ]
    )
#endif
}

#if canImport(MapboxMaps)
fileprivate extension CoordinateBounds {
    var shape: [ LocationCoordinate2D ] {
        [
            self.southwest,
            self.southeast,
            self.northeast,
            self.northwest,
            self.southwest,
        ]
    }
}
#endif
