//
//  PartialCellCollection.swift
//  UmbreonCore
//
//  Created by Lucka on 20/9/2024.
//

import Foundation
import SphereGeometry
import SwiftData

@Model
public final class PartialCellCollection {
    @available(iOS 18, macOS 15, *)
    #Index<PartialCellCollection>([ \.instanceIdentifier ])
    
    public private(set) var instanceIdentifier: InstanceIdentifier
    
    public private(set) var coarseCellsData: Data
    
    @Attribute(.externalStorage)
    public private(set) var detailedCellsData: Data
    
    public init(cell: CellIdentifier, children: CellCollection) {
        self.instanceIdentifier = Self.instanceIdentifier(of: cell)
        self.coarseCellsData = children.expand(to: Self.coarseLevel).data
        self.detailedCellsData = children.data
    }
}

public extension PartialCellCollection {
    typealias InstanceIdentifier = UInt16
    
    static let instanceLevel = Level.at.6
    static let coarseLevel = Level.at.12
    static let detailedLevel = Level.at.20
    
    static func instanceIdentifier(of cell: CellIdentifier) -> InstanceIdentifier {
        instanceIdentifier(of: cell.rawValue)
    }
    
    static func instanceIdentifier(of value: CellIdentifier.RawValue) -> InstanceIdentifier {
        .init(value >> Self.instanceIdentifierOffset)
    }
    
    var coarseCells: CellCollection {
        .init(data: coarseCellsData) ?? .init()
    }
    
    var detailedCells: CellCollection {
        .init(data: detailedCellsData) ?? .init()
    }
    
    var instanceCell: CellIdentifier {
        .init(rawValue: .init(instanceIdentifier) << Self.instanceIdentifierOffset)!
    }
    
    func assign(_ cells: CellCollection) {
        coarseCellsData = cells.expand(to: Self.coarseLevel).data
        detailedCellsData = cells.data
    }
    
    func merge(_ cells: CellCollection) -> CellCollection {
        let difference = cells.difference(detailedCells)
        coarseCellsData = coarseCells.union(difference.expand(to: Self.coarseLevel)).data
        detailedCellsData = detailedCells.union(difference).data
        return difference
    }
}

fileprivate extension PartialCellCollection {
    static let totalBitCount = MemoryLayout<CellIdentifier.RawValue>.size * 8
    static let instanceIdentifierBitCount = MemoryLayout<InstanceIdentifier>.size * 8   // 16 = 3 + 6 * 2 + 1, precisely fits level 6
    static let instanceIdentifierOffset = totalBitCount - instanceIdentifierBitCount
}
