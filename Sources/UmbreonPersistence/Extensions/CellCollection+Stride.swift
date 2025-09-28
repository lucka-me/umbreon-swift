//
//  CellCollection+Stride.swift
//  UmbreonPersistence
//
//  Created by Lucka on 28/8/2025.
//

import simd
import Foundation
import SphereGeometry

public extension CellCollection {
    static func stride(
        from start: CartesianCoordinate,
        to end: CartesianCoordinate,
        at level: Level
    ) -> Self {
        // TODO: Calculate a better strideInterval from level?
        Swift
            .stride(from: 0, to: 1.0, by: strideInterval / start.arc(to: end))
            .reduce(into: .init()) { result, element in
                let _ = result.insert(
                    .init(
                        .init(rawValue: mix(start.rawValue, end.rawValue, t: element)),
                        at: level
                    )
                )
            }
    }
}

fileprivate let strideInterval: Double = 1 / Earth.radius
