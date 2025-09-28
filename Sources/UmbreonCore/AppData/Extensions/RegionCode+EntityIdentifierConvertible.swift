//
//  RegionCode+EntityIdentifierConvertible.swift
//  UmbreonCore
//
//  Created by Lucka on 24/8/2025.
//

#if canImport(AppIntents)
import AppIntents

extension RegionCode : EntityIdentifierConvertible {
    public var entityIdentifierString: String {
        rawValue
    }
    
    public static func entityIdentifier(for entityIdentifierString: String) -> RegionCode? {
        .init(rawValue: entityIdentifierString)
    }
}
#endif
