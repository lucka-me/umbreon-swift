//
//  Cell+Polygon.swift
//  UmbreonAppUI
//
//  Created by Lucka on 15/9/2025.
//

import simd
import SphereGeometry
import Turf

extension Cell {
    var plottableRing: Ring {
        guard level > .min else {
            return self.zone.plottableRing
        }
        
        let vertices = self.vertices

        var lowerLeftLocation = vertices[0].locationCoordinate
        var lowerRightLocation = vertices[1].locationCoordinate
        var upperRightLocation = vertices[2].locationCoordinate
        let upperLeftLocation = vertices[3].locationCoordinate
        
        if coordinate.j == LeafCoordinate.scalarMiddle ||
            vertices[2].i == LeafCoordinate.scalarMiddle
        {
            // Fix the edge sticking with the Antimerdian, +180 to -180
            switch coordinate.zone {
            case .pacific:
                if coordinate.j == LeafCoordinate.scalarMiddle {
                    lowerLeftLocation.longitude = -180
                    lowerRightLocation.longitude = -180
                }
            case .north:
                if (coordinate.j == LeafCoordinate.scalarMiddle) &&
                    (coordinate.i >= LeafCoordinate.scalarMiddle)
                {
                    lowerLeftLocation.longitude = -180
                    lowerRightLocation.longitude = -180
                }
            case .south:
                if (vertices[2].i == LeafCoordinate.scalarMiddle) &&
                    (vertices[2].j <= LeafCoordinate.scalarMiddle)
                {
                    lowerRightLocation.longitude = -180
                    upperRightLocation.longitude = -180
                }
            default: break
            }
        }
        
        let shape = [
            lowerLeftLocation,
            lowerRightLocation,
            upperRightLocation,
            upperLeftLocation,
        ]
        
        return if level > .at.8 {
            .init(coordinates: shape)
        } else {
            .init(
                coordinates: LocationCoordinate2D.stride(coordinates: shape)
            )
        }
    }
}

fileprivate extension CartesianCoordinate {
    static func stride(after start: Self, to end: Self) -> [ Self ] {
        Swift
            .stride(from: 0.1, to: 1.0, by: 0.1)
            .map {
                .init(rawValue: mix(start.rawValue, end.rawValue, t: $0))
            }
    }
}

fileprivate extension LocationCoordinate2D {
    static func stride(coordinates: [ Self ]) -> [ Self ] {
        typealias PartialResult = (previous: Self, result: [ Self ])
        return coordinates.reduce(
            into: PartialResult(coordinates.last!, [ ])
        ) { result, element in
            var strided = CartesianCoordinate
                .stride(
                    after: result.previous.cartesianCoordinate,
                    to: element.cartesianCoordinate
                )
                .map(\.locationCoordinate)
#if canImport(MapboxMaps)
            if result.previous.longitude > 180 || element.longitude > 180 {
                for (index, _) in strided.enumerated() {
                    if strided[index].longitude < 0 {
                        strided[index].longitude += 360
                    }
                }
            }
#endif
            result.result.append(contentsOf: strided)
            result.result.append(element)
            result.previous = element
        }
        .result
    }
}

fileprivate extension Zone {
    static private let vertexLatitude: Double = atan(1 / sqrt(2)) / .pi * 180
    
    var plottableRing: Ring {
        let coordinates: [ LocationCoordinate2D ] = switch self {
        case .africa:
            LocationCoordinate2D.stride(
                coordinates: [
                    .init(latitude:  Self.vertexLatitude, longitude: -45),
                    .init(latitude:  Self.vertexLatitude, longitude:  45),
                    .init(latitude: -Self.vertexLatitude, longitude:  45),
                    .init(latitude: -Self.vertexLatitude, longitude: -45),
                ]
            )
        case .asia:
            LocationCoordinate2D.stride(
                coordinates: [
                    .init(latitude:  Self.vertexLatitude, longitude:  45),
                    .init(latitude:  Self.vertexLatitude, longitude: 135),
                    .init(latitude: -Self.vertexLatitude, longitude: 135),
                    .init(latitude: -Self.vertexLatitude, longitude:  45),
                ]
            )
        case .north:
            // For MapKit, the order matters, not sure why.
            LocationCoordinate2D.stride(
                coordinates: [
                    .init(latitude: 45, longitude: -180),
                    .init(latitude: Self.vertexLatitude, longitude: -135),
                    .init(latitude: Self.vertexLatitude, longitude:  -45),
                    .init(latitude: Self.vertexLatitude, longitude:   45),
                    .init(latitude: Self.vertexLatitude, longitude:  135),
                    .init(latitude: 45, longitude:  180),
                    .init(latitude: 90, longitude:  180),
                    .init(latitude: 90, longitude: -180),
                ]
            )
        case .pacific:
#if canImport(MapboxMaps)
            // For Mapbox, shape crossing antimeridian should never wrap.
            LocationCoordinate2D.stride(
                coordinates: [
                    .init(latitude:  Self.vertexLatitude, longitude: 135),
                    .init(latitude:  Self.vertexLatitude, longitude: 225),
                    .init(latitude: -Self.vertexLatitude, longitude: 225),
                    .init(latitude: -Self.vertexLatitude, longitude: 135),
                ]
            )
#else
            // For MapKit, plotting unwrapped coordinates is not supported,
            // wrapped shape will be plotted properly
            LocationCoordinate2D.stride(
                coordinates: [
                    .init(latitude:  Self.vertexLatitude, longitude:  135),
                    .init(latitude:  Self.vertexLatitude, longitude: -135),
                    .init(latitude: -Self.vertexLatitude, longitude: -135),
                    .init(latitude: -Self.vertexLatitude, longitude:  135),
                ]
            )
#endif
        case .america:
            LocationCoordinate2D.stride(
                coordinates: [
                    .init(latitude:  Self.vertexLatitude, longitude: -135),
                    .init(latitude:  Self.vertexLatitude, longitude:  -45),
                    .init(latitude: -Self.vertexLatitude, longitude:  -45),
                    .init(latitude: -Self.vertexLatitude, longitude: -135),
                ]
            )
        case .south:
            LocationCoordinate2D.stride(
                coordinates: [
                    .init(latitude: -45, longitude: -180),
                    .init(latitude: -Self.vertexLatitude, longitude: -135),
                    .init(latitude: -Self.vertexLatitude, longitude:  -45),
                    .init(latitude: -Self.vertexLatitude, longitude:   45),
                    .init(latitude: -Self.vertexLatitude, longitude:  135),
                    .init(latitude: -45, longitude:  180),
                    .init(latitude: -90, longitude:  180),
                    .init(latitude: -90, longitude: -180),
                ]
            )
        }
        
        return .init(coordinates: coordinates)
    }
}
