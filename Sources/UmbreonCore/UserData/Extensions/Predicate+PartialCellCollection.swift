//
//  Predicate+PartialCellCollection.swift
//  UmbreonCore
//
//  Created by Lucka on 15/8/2025.
//

import Foundation
import SphereGeometry

public extension Predicate<PartialCellCollection> {
    static func instance(including cell: CellIdentifier) -> Predicate<PartialCellCollection> {
        let identifier = PartialCellCollection.instanceIdentifier(of: cell)
        return #Predicate<PartialCellCollection> { $0.instanceIdentifier == identifier }
    }
}
