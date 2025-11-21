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
    typealias InsertResult = (area: Double, cells: CellCollection)
    
    @discardableResult
    func insert(
        discovered cells: CellCollection, reporting progress: Progress? = nil
    ) async throws -> InsertResult {
        progress?.totalUnitCount = 3
        
        var insertedCells = CellCollection()
        
        let insertProgress = progress?.addChild(for: .init(cells.count), as: 1)
        var lower = cells.startIndex
        while lower < cells.endIndex {
            defer {
                insertProgress?.completedUnitCount = .init(lower - cells.startIndex)
            }
            
            let item = cells[lower]
            guard
                let partialCell = item.parent(at: PartialCellCollection.instanceLevel)
            else {
                insertedCells.formUnion(try insert(whole: item))
                lower += 1
                continue
            }
            
            let upper = cells.index(after: partialCell, since: lower)
            let insertedPartial = try insert(
                partial: partialCell,
                children: .init(cells[ lower ..< upper ])
            )
            insertedCells.formUnion(insertedPartial)
            lower = upper
        }
        
        guard !insertedCells.isEmpty else {
            return (.zero, .init())
        }
        
        let groupedCells = await tessellation.group(
            cells: insertedCells, reporting: progress?.addChild(as: 1)
        )
        let totalArea = try insert(
            accumulating: groupedCells,
            reporting: progress?.addChild(as: 1)
        )
        
        return (totalArea, insertedCells)
    }
    
    func refreshStatistics(reporting progress: Progress? = nil) async throws {
        let identifiers = try modelContext.fetchIdentifiers(
            FetchDescriptor<PartialCellCollection>()
        )
        progress?.totalUnitCount = .init(identifiers.count) * 2
        
        try resetStatistics()
        
        try await withThrowingTaskGroup { group in
            for identifier in identifiers {
                group.addTask { [ weak self ] in
                    try await self?.refreshStatistics(for: identifier, reporting: progress)
                }
            }
            try await group.waitForAll()
        }
    }
}

fileprivate extension Persistence {
    func insert(
        partial cell: CellIdentifier,
        children: CellCollection
    ) throws -> CellCollection {
        guard let item = try modelContext.first(matches: .instance(including: cell)) else {
            modelContext.insert(PartialCellCollection(cell: cell, children: children))
            return children
        }
        return item.merge(children)
    }
    
    func insert(whole cell: CellIdentifier) throws -> CellCollection {
        try cell
            .children(at: PartialCellCollection.instanceLevel)
            .reduce(into: .init()) { result, cell in
                guard
                    let item = try modelContext.first(matches: .instance(including: cell))
                else {
                    modelContext.insert(PartialCellCollection(cell: cell, children: [ cell ]))
                    let _ = result.insert(cell)
                    return
                }
                let cells = CellCollection([ cell ])
                result.formUnion(cells.difference(item.detailedCells))
                item.assign(cells)
            }
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
        
        let groupedCells = await tessellation.group(
            cells: model.detailedCells,
            reporting: progress?.addChild(as: 1)
        )
        try insert(
            accumulating: groupedCells,
            reporting: progress?.addChild(as: 1)
        )
    }
}

fileprivate extension Persistence {
    @discardableResult
    func insert(
        accumulating cells: [ RegionCode : CellCollection ],
        reporting progress: Progress? = nil
    ) throws -> Double {
        progress?.totalUnitCount = Int64(cells.count) * 2 + 1
        
        let totalArea: Double = try cells
            .reduce(0) { partial, element in
                let area = element.value.reduce(into: 0) { $0 += $1.cell.area }
                progress?.completedUnitCount += 1
                
                try insert(discoveredArea: area, to: element.key)
                if element.key.isSubdivision {
                    try insert(discoveredArea: area, to: element.key.aligningToCountry())
                }
                progress?.completedUnitCount += 1
                
                return partial + area
            }
        
        try insert(discoveredArea: totalArea, to: .world)
        progress?.completedUnitCount += 1
        
        return totalArea
    }
    
    func insert(discoveredArea: Double, to regionCode: RegionCode) throws {
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
