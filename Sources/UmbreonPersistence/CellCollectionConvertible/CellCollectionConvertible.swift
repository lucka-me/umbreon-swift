//
//  CellCollectionConvertible.swift
//  UmbreonPersistence
//
//  Created by Lucka on 23/11/2024.
//

import Foundation
import SphereGeometry

public protocol CellCollectionConvertible : Actor {
    var progress: Progress { get }
    func convert() async throws -> CellCollection
}
