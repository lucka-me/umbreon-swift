//
//  RegionProvider.swift
//  UmbreonCore
//
//  Created by Lucka on 14/11/2024.
//

import Foundation
import SphereGeometry
import SwiftData
import Turf

public final class RegionProvider {
    private let container: ModelContainer
    
    private init() {
        do {
            self.container = try .init(
                for: Region.self, RegionFlag.self,
                configurations: .init(
                    url: #bundle.url(forResource: "regions", withExtension: "db")!,
                    allowsSave: false
                )
            )
        } catch {
            fatalError("Unable to create ModelContainer for RegionProvider: \(error)")
        }
    }
}

public extension RegionProvider {
    static let shared = RegionProvider()
    
    subscript(code: RegionCode) -> Region {
        return try! region(of: code, in: .init(container))!
    }
    
    func region(of code: RegionCode) throws -> Region? {
        try region(of: code, in: .init(container))
    }
}

extension RegionProvider : Sendable {
    
}

fileprivate extension RegionProvider {
    func region(of code: RegionCode, in context: ModelContext) throws -> Region? {
        let codeValue = code.rawValue
        var descriptor = FetchDescriptor<Region>(
            predicate: #Predicate { $0.codeValue == codeValue }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
