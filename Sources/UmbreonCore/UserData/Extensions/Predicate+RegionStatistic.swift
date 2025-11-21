//
//  Predicate+RegionStatistic.swift
//  UmbreonCore
//
//  Created by Lucka on 14/8/2025.
//

import Foundation

public extension Predicate<RegionStatistic> {
    static var all: RegionStatisticPredicateBuilder {
        .init(base: .true)
    }
    
    static var countries: RegionStatisticPredicateBuilder {
        .init(base: #Predicate { $0.subdivisionCode == nil })
    }
    
    static func region(matches regionCode: RegionCode) -> Predicate<RegionStatistic> {
        let countryCode = regionCode.countryCode
        let subdivisionCode = regionCode.subdivisionCode
        return #Predicate {
            $0.countryCode == countryCode &&
            $0.subdivisionCode == subdivisionCode
        }
    }
    
    static func region(matches regionCode: RegionCode) -> RegionStatisticPredicateBuilder {
        .init(base: region(matches: regionCode))
    }
    
    static func subdivisions(of regionCode: RegionCode) -> Predicate<RegionStatistic> {
        let countryCode = regionCode.countryCode
        return #Predicate {
            $0.countryCode == countryCode &&
            $0.subdivisionCode != nil
        }
    }
    
    static func subdivisions(of regionCode: RegionCode) -> RegionStatisticPredicateBuilder {
        .init(base: subdivisions(of: regionCode))
    }
}

public struct RegionStatisticPredicateBuilder {
    private enum FetchLevel {
        case all
        case discovered
        case visible
    }
    
    private let base: Predicate<RegionStatistic>
    private var level = FetchLevel.all
    
    fileprivate init(base: Predicate<RegionStatistic>) {
        self.base = base
    }
    
    public func callAsFunction() -> Predicate<RegionStatistic> {
        switch level {
        case .all:
            return base
        case .discovered:
            return #Predicate {
                base.evaluate($0) && $0.discoveredArea > 0
            }
        case .visible:
            return #Predicate {
                base.evaluate($0) && $0.discoveredArea > 0 && $0.visible
            }
        }
    }
}

public extension RegionStatisticPredicateBuilder {
    var discovered: Self {
        copy(assigning: \.level, to: .discovered)
    }
    
    var visible: Self {
        copy(assigning: \.level, to: .visible)
    }
}

fileprivate extension RegionStatisticPredicateBuilder {
    private func copy<Value>(
        assigning keyPath: WritableKeyPath<Self, Value>,
        to value: Value
    ) -> Self {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}
