//
//  UmbraDataset.swift
//  UmbreonAppUI
//
//  Created by Lucka on 10/9/2024.
//

import Combine
import SphereGeometry

public protocol UmbraDataset : Sendable {
    typealias UpdateSubject = PassthroughSubject<CellCollection, Never>
    
    @MainActor
    var updateSubject: UpdateSubject? { get }
    
    var queryLevel: Level { get }
    
    func query(in cells: CellCollection, at resolution: Level) async throws -> CellCollection
}
