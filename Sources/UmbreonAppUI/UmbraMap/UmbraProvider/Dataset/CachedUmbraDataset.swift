//
//  CachedUmbraDataset.swift
//  UmbreonAppUI
//
//  Created by Lucka on 11/3/2025.
//

import SphereGeometry

public struct CachedUmbraDataset : UmbraDataset {
    public let queryLevel = Level.at.6  // Just keep same as PersistentUmbraDataset
    
    public let cells: CellCollection
    
    public init(cells: CellCollection) {
        self.cells = cells
    }
    
    public var updateSubject: UpdateSubject? {
        nil
    }
    
    public func query(in cells: CellCollection, at resolution: Level) -> CellCollection {
        guard !cells.isEmpty else {
            return .init()
        }
        return self.cells.intersection(cells).expand(to: resolution)
    }
}

public extension UmbraDataset where Self == CachedUmbraDataset {
    static func cached(cells: CellCollection) -> Self {
        .init(cells: cells)
    }
}
