//
//  Persistence.swift
//  UmbreonPersistence
//
//  Created by Lucka on 23/9/2024.
//

import Foundation
import SphereGeometry
import SwiftData
import UmbreonCore

public actor Persistence : ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    
    public let tessellation: Tessellation
    
    public init(modelContainer: ModelContainer, tessellation: Tessellation = .init()) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: .init(modelContainer))
        self.tessellation = tessellation
    }
}

public extension Persistence {
    func clearAll() throws {
        try modelContext.delete(model: PartialCellCollection.self)
        try resetStatistics()
        try clearHistory()
    }
    
    func clearHistory() throws {
        try modelContext.deleteHistory(HistoryDescriptor<DefaultHistoryTransaction>())
    }
    
    func save() throws {
        try modelContext.save()
    }
}

public extension Persistence {
    @discardableResult
    func insert(
        discovered cells: CellCollection,
        reporting progress: Progress? = nil
    ) async throws -> (cells: CellCollection, area: Double) {
        progress?.totalUnitCount = .init(cells.count)
        
        return try await withThrowingTaskGroup { @Sendable group in
            var lower = cells.startIndex
            while lower < cells.endIndex {
                let element = cells[lower]
                if let partialCell = element.parent(at: PartialCellCollection.instanceLevel) {
                    let upper = cells.index(after: partialCell, since: lower)
                    let slice = cells[ lower ..< upper ]
                    group.addTask {
                        try await self.insert(
                            partial: .init(slice),
                            reporting: progress?.addChild(as: .init(slice.count))
                        )
                    }
                    lower = upper
                } else {
                    let children = element.children(at: PartialCellCollection.instanceLevel)
                    let childProgress = progress?.addChild(for: .init(children.count), as: 1)
                    for child in children {
                        group.addTask {
                            try await self.insert(
                                whole: child,
                                reporting: childProgress?.addChild(as: 1)
                            )
                        }
                    }
                    lower += 1
                }
            }
            
            let inserted: InsertResult = try await group.reduce(into: (.init(), 0)) {
                $0.cells.formUnion($1.cells)
                $0.area += $1.area
            }
            return (.init(inserted.cells), inserted.area)
        }
    }
    
    func refreshStatistics(reporting progress: Progress? = nil) async throws {
        let identifiers = try modelContext.fetchIdentifiers(
            FetchDescriptor<PartialCellCollection>()
        )
        progress?.totalUnitCount = .init(identifiers.count)
        
        try resetStatistics()
        
        try await withThrowingTaskGroup { group in
            for identifier in identifiers {
                group.addTask { [ weak self ] in
                    try await self?.refreshStatistics(
                        for: identifier,
                        reporting: progress?.addChild(as: 1)
                    )
                }
            }
            try await group.waitForAll()
        }
    }
}

fileprivate extension Persistence {
    typealias InsertResult = (cells: Set<CellIdentifier>, area: Double)
    
    @discardableResult
    func insert(
        partial cells: CellCollection,
        reporting progress: Progress?
    ) async throws -> InsertResult {
        progress?.totalUnitCount = 3
        
        let inserted: CellCollection
        if let model = try modelContext.first(matches: .instance(including: cells[0])) {
            inserted = model.merge(cells)
        } else {
            modelContext.insert(PartialCellCollection(cells: cells))
            inserted = cells
        }
        
        guard !inserted.isEmpty else {
            progress?.completedUnitCount = 3
            return ([ ], 0)
        }
        
        progress?.completedUnitCount = 1
        
        let area = try await updateStatistics(
            inserted: inserted,
            reporting: progress?.addChild(as: 2)
        )
        return (.init(inserted), area)
    }
    
    @discardableResult
    func insert(
        whole cell: CellIdentifier,
        reporting progress: Progress?
    ) async throws -> InsertResult {
        progress?.totalUnitCount = 3
        
        let inserted: CellCollection
        if let model = try modelContext.first(matches: .instance(including: cell)) {
            let cells = CellCollection([ cell ])
            inserted = cells.difference(model.detailedCells)
            model.assign(cells)
        } else {
            inserted = [ cell ]
            modelContext.insert(PartialCellCollection(cells: inserted))
        }
        
        guard !inserted.isEmpty else {
            progress?.completedUnitCount = 3
            return ([ ], 0)
        }
        
        progress?.completedUnitCount = 1
        
        let area = try await updateStatistics(
            inserted: inserted,
            reporting: progress?.addChild(as: 2)
        )
        return (.init(inserted), area)
    }
}

fileprivate extension Persistence {
    func refreshStatistics(
        for identifier: PersistentIdentifier,
        reporting progress: Progress?
    ) async throws {
        guard let model = modelContext.model(for: identifier) as? PartialCellCollection else {
            // TODO: Throw an error?
            return
        }
        try await updateStatistics(inserted: model.detailedCells, reporting: progress)
    }
    
    @discardableResult
    func updateStatistics(
        inserted cells: CellCollection,
        reporting progress: Progress? = nil
    ) async throws -> Double {
        progress?.totalUnitCount = 2
        
        let grouped = await tessellation.group(
            cells: cells,
            reporting: progress?.addChild(as: 1)
        )
        
        progress?.completedUnitCount = 1
        let childProgress = progress?.addChild(for: .init(grouped.count) * 2 + 1, as: 1)
        
        let totalArea: Double = try grouped
            .reduce(0) { partial, element in
                let area = element.value.reduce(into: 0) { $0 += $1.cell.area }
                childProgress?.completedUnitCount += 1
                
                try updateStatistics(discoveredArea: area, in: element.key)
                if element.key.isSubdivision {
                    try updateStatistics(
                        discoveredArea: area,
                        in: element.key.aligningToCountry()
                    )
                }
                childProgress?.completedUnitCount += 1
                
                return partial + area
            }
        
        try updateStatistics(discoveredArea: totalArea, in: .world)
        childProgress?.completedUnitCount += 1
        
        return totalArea
    }
    
    func updateStatistics(discoveredArea: Double, in regionCode: RegionCode) throws {
        if let model = try modelContext.first(matches: .region(matches: regionCode)) {
            model.addDiscoveredArea(discoveredArea)
        } else if
            let model = try RegionStatistic(
                regionCode: regionCode,
                discoveredArea: discoveredArea
            )
        {
            modelContext.insert(model)
        } else {
            // The Region entry should always exists.
        }
    }
    
    func resetStatistics() throws {
        try modelContext.enumerate(FetchDescriptor<RegionStatistic>()) { entry in
            entry.resetDiscoveredArea()
        }
    }
}
