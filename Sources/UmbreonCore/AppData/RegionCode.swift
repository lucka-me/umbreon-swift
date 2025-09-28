//
//  RegionCode.swift
//  UmbreonCore
//
//  Created by Lucka on 12/10/2024.
//

import Foundation

public struct RegionCode {
    public private(set) var countryCode: String = ""
    public private(set) var subdivisionCode: String? = nil
}

public extension RegionCode {
    static let world = RegionCode(countryCode: "*", subdivisionCode: nil)
    static let ocean = RegionCode(countryCode: "~", subdivisionCode: nil)
    
    var isCountry: Bool {
        subdivisionCode == nil
    }
    
    var isSubdivision: Bool {
        subdivisionCode != nil
    }
    
    var localizedName: String {
        .init(localized: localizedNameResource)
    }
    
    var localizedNameResource: LocalizedStringResource {
        switch self.countryCode {
        case "*": .init("Region.World", bundle: #bundle)
        case "~": .init("Region.Ocean", bundle: #bundle)
        default: .init(.init(rawValue), table: "regions", bundle: #bundle)
        }
    }
    
    func aligningToCountry() -> Self {
        .init(countryCode: countryCode, subdivisionCode: nil)
    }
}

extension RegionCode :
    Comparable,
    CustomStringConvertible,
    Codable,
    Hashable,
    Identifiable,
    RawRepresentable,
    Sendable
{
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.countryCode != rhs.countryCode {
            lhs.countryCode < rhs.countryCode
        } else if
            let lhsSubdivisionCode = lhs.subdivisionCode,
            let rhsSubdivisionCode = rhs.subdivisionCode
        {
            lhsSubdivisionCode < rhsSubdivisionCode
        } else {
            lhs.subdivisionCode == nil
        }
    }
    
    public init?(rawValue: String) {
        guard rawValue != "*", rawValue != "~" else {
            self.countryCode = rawValue
            self.subdivisionCode = nil
            return
        }
        
        guard rawValue.count == 2 || rawValue.count > 3 else {
            return nil
        }
        let countryCode = rawValue.prefix(2)
        guard rawValue.prefix(2).allSatisfy({ $0.isLetter }) else {
            return nil
        }
        
        guard rawValue.count > 3 else {
            // Country
            self.countryCode = .init(countryCode).uppercased()
            self.subdivisionCode = nil
            return
        }
        
        let dividerIndex = rawValue.index(rawValue.startIndex, offsetBy: 2)
        guard rawValue[dividerIndex] == "-" else {
            return nil
        }
        
        self.countryCode = .init(countryCode).uppercased()
        self.subdivisionCode = .init(
            rawValue.suffix(from: rawValue.index(after: dividerIndex))
        )
        .uppercased()
    }
    
    public var description: String {
        rawValue
    }
    
    public var id: String {
        rawValue
    }
    
    public var rawValue: String {
        if let subdivisionCode {
            countryCode + "-" + subdivisionCode
        } else {
            countryCode
        }
    }
}
