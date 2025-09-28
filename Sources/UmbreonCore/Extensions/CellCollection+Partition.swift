//
//  CellCollection+Partition.swift
//  UmbreonCore
//
//  Created by Lucka on 12/10/2024.
//

import SphereGeometry

public extension CellCollection {
    func partition(by other: Self) -> (intersection: Self, difference: Self) {
        // TODO: Improve the algorithm?
        (
            self.intersection(other),
            self.difference(other)
        )
    }
}
