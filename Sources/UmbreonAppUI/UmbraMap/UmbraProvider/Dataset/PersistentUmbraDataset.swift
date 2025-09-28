//
//  PersistentUmbraDataset.swift
//  UmbreonAppUI
//
//  Created by Lucka on 11/3/2025.
//

import Foundation
import SphereGeometry
import SwiftData
import UmbreonCore

@ModelActor
public actor PersistentUmbraDataset : UmbraDataset {
    public let queryLevel = PartialCellCollection.instanceLevel
    
    @MainActor
    public var updateSubject: UpdateSubject? {
        Self.globalUpdateSubject
    }
    
    public func query(in cells: CellCollection, at resolution: Level) throws -> CellCollection {
        guard !cells.isEmpty else {
            return .init()
        }
        return switch resolution {
        case .min ... PartialCellCollection.instanceLevel:
            try queryEntireEntries()
        case PartialCellCollection.instanceLevel ... PartialCellCollection.coarseLevel:
            try queryChildren(in: cells, at: resolution, from: \.coarseCellsData)
        default:
            try queryChildren(in: cells, at: resolution, from: \.detailedCellsData)
        }
    }
}

public extension PersistentUmbraDataset {
    @MainActor
    static func updated(_ cells: CellCollection) {
        globalUpdateSubject.send(cells.expand(to: PartialCellCollection.instanceLevel))
    }
}

public extension UmbraDataset where Self == PersistentUmbraDataset {
    static func persistent(container: ModelContainer) -> Self {
        .init(modelContainer: container)
    }
}

fileprivate extension PersistentUmbraDataset {
    @MainActor
    static let globalUpdateSubject = UpdateSubject()
    
    func queryChildren(
        in cells: CellCollection,
        at resolution: Level,
        from keyPath: KeyPath<PartialCellCollection, Data>
    ) throws -> CellCollection {
        let identifiers: Set<PartialCellCollection.InstanceIdentifier> = cells
            .aligned(at: PartialCellCollection.instanceLevel)
            .reduce(into: [ ]) {
                $0.insert(PartialCellCollection.instanceIdentifier(of: $1))
            }
        var descriptor = FetchDescriptor<PartialCellCollection>()
        descriptor.predicate = #Predicate {
            identifiers.contains($0.instanceIdentifier)
        }
        descriptor.propertiesToFetch = [ keyPath ]
        var collection: [ CellIdentifier ] = [ ]
        try modelContext.enumerate(descriptor) { item in
            collection.append(
                contentsOf: CellCollection(data: item[keyPath: keyPath])!.expand(to: resolution)
            )
        }
        return .init(collection)
    }
    
    func queryEntireEntries() throws -> CellCollection {
        var collection: [ CellIdentifier ] = [ ]
        var descriptor = FetchDescriptor<PartialCellCollection>()
        descriptor.propertiesToFetch = [ \.instanceIdentifier ]
        try modelContext.enumerate(descriptor) { item in
            collection.append(item.instanceCell)
        }
        return .init(collection)
    }
}
