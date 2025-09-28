//
//  BoundingBox+CellAlgebra.swift
//  UmbreonAppUI
//
//  Created by Lucka on 4/9/2025.
//

import SphereGeometry
import Turf

extension BoundingBox : CellAlgebra {
    func relation(with cell: Cell) -> CellRelation {
        let vertices = cell.vertices.map(\.locationCoordinate)
        
        return switch vertices.count(where: { self.contains($0) }) {
        case 0: if intersects(cell.boundingBox(vertices: vertices)) {
            .intersect
        } else {
            .disjoint
        }
        case 4: .contain
        default: .intersect
        }
    }
}

fileprivate extension BoundingBox {
    func intersects(_ other: Self) -> Bool {
        longitudeIntersects(other) && latitudeIntersects(other)
    }
    
    private func latitudeIntersects(_ other: Self) -> Bool {
        if self.southWest.latitude <= other.southWest.latitude {
            other.southWest.latitude <= self.northEast.latitude
        } else {
            self.southWest.latitude <= other.northEast.latitude
        }
    }
    
    private func longitudeIntersects(_ other: Self) -> Bool {
        return if self.northEast.longitude < self.southWest.longitude {
            other.northEast.longitude < other.southWest.longitude ||
            other.southWest.longitude <= self.northEast.longitude ||
            other.northEast.longitude >= self.southWest.longitude
        } else if other.northEast.longitude < other.southWest.longitude {
            other.southWest.longitude <= self.northEast.longitude ||
            other.northEast.longitude >= self.southWest.longitude
        } else {
            other.southWest.longitude <= self.northEast.longitude &&
            other.northEast.longitude >= self.southWest.longitude
        }
    }
}

extension Cell {
    func boundingBox(vertices: [ LocationCoordinate2D ]) -> BoundingBox {
        guard level > .min else {
            return switch zone {
            case .africa: .init(
                southWest: .init(latitude: -45, longitude: -45),
                northEast: .init(latitude: 45, longitude: 45)
            )
            case .asia: .init(
                southWest: .init(latitude: -45, longitude: 45),
                northEast: .init(latitude: 45, longitude: 135)
            )
            case .north: .init(
                southWest: .init(latitude: 45, longitude: -180),
                northEast: .init(latitude: 90, longitude: 180)
            )
            case .pacific: .init(
                southWest: .init(latitude: -45, longitude: 135),
                northEast: .init(latitude: 45, longitude: -135)
            )
            case .america: .init(
                southWest: .init(latitude: -45, longitude: -135),
                northEast: .init(latitude: 45, longitude: -45)
            )
            case .south: .init(
                southWest: .init(latitude: -90, longitude: -180),
                northEast: .init(latitude: -45, longitude: 180)
            )
            }
        }
        
        return .init(
            southWest: .init(
                latitude: min(
                    vertices[0].latitude,
                    vertices[1].latitude,
                    vertices[2].latitude,
                    vertices[3].latitude
                ),
                longitude: min(
                    vertices[0].longitude,
                    vertices[1].longitude,
                    vertices[2].longitude,
                    vertices[3].longitude
                )
            ),
            northEast: .init(
                latitude: max(
                    vertices[0].latitude,
                    vertices[1].latitude,
                    vertices[2].latitude,
                    vertices[3].latitude
                ),
                longitude: max(
                    vertices[0].longitude,
                    vertices[1].longitude,
                    vertices[2].longitude,
                    vertices[3].longitude
                )
            )
        )
    }
}
