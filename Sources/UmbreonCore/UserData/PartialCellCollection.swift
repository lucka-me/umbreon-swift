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
    // 16 - 1 = 3 + 6 * 2, precisely fits level 6
    // NOTICE: For SwiftData, UInt16 will be *wrapped* to Int16 when persisted, resulted in
    // nagative integer in america and south, and unable to be fetched with predicate, so we leave
    // the leading bit (sign bit for Int16) as 0 to keep the identifier and order of models.
    typealias InstanceIdentifier = UInt16
    
    static let instanceLevel = Level.at.6
    
    static func instanceIdentifier(of cell: CellIdentifier) -> InstanceIdentifier {
        instanceIdentifier(of: cell.rawValue)
    }
    
    static func instanceIdentifier(of value: CellIdentifier.RawValue) -> InstanceIdentifier {
        .init(value >> Self.instanceIdentifierOffset)
    }
    
    var instanceCell: CellIdentifier {
        .init(
            rawValue: (.init(instanceIdentifier) << Self.instanceIdentifierOffset) |
                Self.instanceIdentifierLeastSignificantBit
        )!
    }
}

public extension PartialCellCollection {
    static let coarseLevel = Level.at.12
    static let detailedLevel = Level.at.20
    
    var coarseCells: CellCollection {
        .init(data: coarseCellsData) ?? .init()
    }
    
    var detailedCells: CellCollection {
        .init(data: detailedCellsData) ?? .init()
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
    static let cellIdentifierBitCount = MemoryLayout<CellIdentifier.RawValue>.size * 8
    static let instanceIdentifierBitCount = MemoryLayout<InstanceIdentifier>.size * 8 - 1
    static let instanceIdentifierOffset = cellIdentifierBitCount - instanceIdentifierBitCount
    static let instanceIdentifierLeastSignificantBit: CellIdentifier.RawValue = 1 << (instanceIdentifierOffset - 1)
}
