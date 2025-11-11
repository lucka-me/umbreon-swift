//
//  UmbraProvider.swift
//  UmbreonAppUI
//
//  Created by Lucka on 10/9/2024.
//

import Combine
import UmbreonCore
import SphereGeometry
import Turf

actor UmbraProvider {
    private(set) var rings: [ Ring ] = [ ]
    
    private let dataset: UmbraDataset
    private let queryLevel: Level
    
    private var enlightendCells = CellCollection()
    private var quriedCells = CellCollection()
    private var quriedResolution = Level.max
    
    public init(dataset: UmbraDataset) {
        self.dataset = dataset
        self.queryLevel = dataset.queryLevel
    }
}

extension UmbraProvider {
    enum RequestRange {
        case world
        case regional(box: BoundingBox)
    }
    
    enum Request : Sendable {
        case camaraChanged(range: RequestRange, resolution: Level)
        case datasetUpdated(cells: CellCollection)
    }
    
    func request(_ request: Request) async throws -> Bool {
        switch request {
        case .camaraChanged(let range, let resolution):
            try await self.request(in: range, at: resolution)
        case .datasetUpdated(let cells):
            try await self.request(checking: cells)
        }
    }
}

fileprivate extension UmbraProvider {
    func request(in range: RequestRange, at resolution: Level) async throws -> Bool {
        let queryCells: CellCollection = switch range {
        case .world: .wholeSphere
        case .regional(let box): box.cells(at: queryLevel)
        }
        
        guard (resolution != quriedResolution) || (queryCells != quriedCells) else {
            return false
        }
        
        // Query
        if resolution > self.quriedResolution {
            // Zoom in
            enlightendCells = try await dataset.query(in: queryCells, at: resolution)
        } else {
            // Pan / zoom out
            enlightendCells.formIntersection(queryCells)
            if resolution < quriedResolution {
                enlightendCells.expanding(to: resolution)
            }
            
            let difference = queryCells.difference(quriedCells)
            if !difference.isEmpty {
                enlightendCells.formUnion(
                    try await dataset.query(in: difference, at: resolution)
                )
            }
        }
        
        quriedResolution = resolution
        quriedCells = queryCells
        
        if enlightendCells.isEmpty {
            rings.removeAll()
        } else {
            updateShape()
        }
        
        return true
    }
    
    func request(checking cells: CellCollection) async throws -> Bool {
        guard !cells.isEmpty else {
            enlightendCells = [ ]
            rings.removeAll()
            return true
        }
        
        let filtered = cells.intersection(quriedCells)
        
        guard !filtered.isEmpty, !enlightendCells.contains(filtered) else {
            return false
        }
        
        let updatedCells = try await dataset.query(in: filtered, at: quriedResolution)
        guard !enlightendCells.contains(updatedCells) else {
            return false
        }
        
        enlightendCells.formUnion(updatedCells)
        
        updateShape()
        return true
    }
    
    func updateShape() {
        rings = enlightendCells
            .rings(at: quriedResolution)
            .map { shape in
                Polygon(outerRing: .init(coordinates: shape))
                    .smooth(iterations: 2)
                    .outerRing
            }
    }
}
