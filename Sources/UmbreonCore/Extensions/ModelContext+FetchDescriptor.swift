//
//  ModelContext+FetchDescriptor.swift
//  UmbreonCore
//
//  Created by Lucka on 10/9/2024.
//

import Foundation
import SwiftData

public extension ModelContext {
    func first<T: PersistentModel>(matches predicate: Predicate<T>?) throws -> T? {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }
    
    func map<T: PersistentModel, R>(
        _ fetch: FetchDescriptor<T>,
        batchSize: Int = 5000,
        allowEscapingMutations: Bool = false,
        transform: (T) throws -> R
    ) throws -> [ R ] {
        var results: [ R ] = [ ]
        try enumerate(
            fetch, batchSize: batchSize, allowEscapingMutations: allowEscapingMutations
        ) {
            results.append(try transform($0))
        }
        return results
    }
}

extension ModelContext {
    func contains<T: PersistentModel>(predicate: Predicate<T>?) throws -> Bool {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try fetchCount(descriptor) > 0
    }
}
