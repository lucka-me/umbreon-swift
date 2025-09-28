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
    typealias InsertResult = (area: Measurement<UnitArea>, cells: CellCollection)
    
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
            return (.init(value: .zero, unit: .squareKilometers), insertedCells)
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
    
    func refreshStatistics(reporting progress: Progress) async throws {
        progress.totalUnitCount = 3
        
        try resetStatistics()
        
        // TODO: Enumerate and classify?
        
        // Union all cells
        var fetchDescriptor = FetchDescriptor<PartialCellCollection>()
        fetchDescriptor.propertiesToFetch = [ \.detailedCellsData ]
        let unionProgress = progress
            .addChild(for: .init(try modelContext.fetchCount(fetchDescriptor)), as: 1)
        var cells = CellCollection()
        try modelContext.enumerate(fetchDescriptor) { collection in
            cells.formUnion(collection.detailedCells)
            unionProgress.completedUnitCount += 1
        }
        
        // Group
        let groupedCells = await tessellation
            .group(cells: cells, reporting: progress.addChild(as: 1))
        
        // Insert areas
        let _ = try insert(accumulating: groupedCells, reporting: progress.addChild(as: 1))
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
    func insert(
        accumulating cells: [ RegionCode : CellCollection ],
        reporting progress: Progress? = nil
    ) throws -> Measurement<UnitArea> {
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
        
        return .init(value: totalArea, unit: .squareMeters)
    }
    
    func insert(discoveredArea: Double, to regionCode: RegionCode) throws {
        if let item = try modelContext.first(matches: .region(matches: regionCode)) {
            item.addDiscoveredArea(discoveredArea)
        } else {
            modelContext.insert(
                RegionStatistic(regionCode: regionCode, discoveredArea: discoveredArea)
            )
        }
    }
    
    func resetStatistics() throws {
        try modelContext.enumerate(FetchDescriptor<RegionStatistic>()) { entry in
            entry.resetDiscoveredArea()
        }
    }
}
