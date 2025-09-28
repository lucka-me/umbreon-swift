//
//  Sequence+Interpolate.swift
//  UmbreonPersistence
//
//  Created by Lucka on 28/8/2025.
//

import simd
import Foundation
import SphereGeometry
import Turf

public extension AsyncSequence where Element == LocationCoordinate2D? {
    func strideCells(
        at level: Level,
        breakWhenFurtherThan threshold: Double
    ) async throws -> CellCollection {
        // Use Set to buffer cells, preventing formUnion(:) which is extremely slow.
        typealias Result = (Set<CellIdentifier>, CartesianCoordinate?)
        
        let thresholdArc = threshold / Earth.radius
        
        let result = try await self.reduce(into: Result(.init(), nil)) { result, element in
            guard let current = element?.cartesianCoordinate else {
                result.1 = nil
                return
            }
            
            if let previous = result.1, previous.arc(to: current) <= thresholdArc {
                // Reverse the start and end to exclude the previous
                result.0.formUnion(
                    CellCollection.stride(from: current, to: previous, at: level)
                )
            } else {
                result.0.insert(.init(current, at: level))
            }
            
            result.1 = current
        }
        
        return .init(result.0)
    }
    
    func strideCells(
        at level: Level,
        breakWhenFurtherThan threshold: Double,
        operation: (CellCollection) async throws -> Void
    ) async throws {
        let thresholdArc = threshold / Earth.radius
        
        let _ = try await self
            .map {
                $0?.cartesianCoordinate
            }
            .reduce(nil) { previous, current -> CartesianCoordinate? in
                guard let current else {
                    return nil
                }
                
                let cells: CellCollection = if let previous {
                    if previous.arc(to: current) > thresholdArc {
                        .init([ .init(current, at: level) ])
                    } else {
                        // Reverse the start and end to exclude the previous
                        .stride(from: current, to: previous, at: level)
                    }
                } else {
                    .init([ .init(current, at: level) ])
                }
                
                try await operation(cells)
                
                return current
            }
    }
}

public extension Sequence<LocationCoordinate2D> {
    func strideCells(
        at level: Level,
        breakWhenFurtherThan threshold: Double
    ) -> CellCollection {
        // Use Set to buffer cells, preventing formUnion(:) which is extremely slow.
        typealias Result = (Set<CellIdentifier>, CartesianCoordinate?)
        
        let thresholdArc = threshold / Earth.radius
        
        let result = self.reduce(into: Result(.init(), nil)) { result, element in
            let current = element.cartesianCoordinate
            
            if let previous = result.1, previous.arc(to: current) <= thresholdArc {
                // Reverse the start and end to exclude the previous
                result.0.formUnion(
                    CellCollection.stride(from: current, to: previous, at: level)
                )
            } else {
                result.0.insert(.init(current, at: level))
            }
            
            result.1 = current
        }
        
        return .init(result.0)
    }
}
