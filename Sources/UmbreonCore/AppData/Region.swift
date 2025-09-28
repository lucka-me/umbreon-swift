//
//  RegionMetadata.swift
//  UmbreonCore
//
//  Created by Lucka on 12/10/2024.
//

import CoreLocation
import Foundation
import SphereGeometry
import SwiftData
import Turf

#if canImport(SwiftUI)
import SwiftUI
#endif

@Model
public final class Region {
    @available(iOS 18, macOS 15, *)
    #Index([ \Region.codeValue ])
    
    @Relationship(inverse: \Region.parent)
    public private(set) var subdivisions: [ Region ] = [ ]
    
    public private(set) var area: Double
    public private(set) var parent: Region?
    
    private(set) var flag: RegionFlag? = nil
    private(set) var codeValue: String
    
    private var north: LocationDegrees
    private var south: LocationDegrees
    private var east: LocationDegrees
    private var west: LocationDegrees
    
    private init(
        area: Double,
        code: RegionCode
    ) {
        self.area = area
        self.codeValue = code.rawValue
        self.north = kCLLocationCoordinate2DInvalid.latitude
        self.south = kCLLocationCoordinate2DInvalid.latitude
        self.east = kCLLocationCoordinate2DInvalid.longitude
        self.west = kCLLocationCoordinate2DInvalid.longitude
    }
}

public extension Region {
    var boundingBox: BoundingBox? {
        let southWest = southWest
        let northEast = northEast
        guard let southWest, let northEast else {
            return nil
        }
        return .init(southWest: southWest, northEast: northEast)
    }
    
    var code: RegionCode {
        .init(rawValue: codeValue)!
    }
    
    var imageData: Data? {
        self.flag?.imageData
    }
    
    var localizedName: String {
        self.code.localizedName
    }
    
    var localizedNameResource: LocalizedStringResource {
        self.code.localizedNameResource
    }
    
    var northEast: LocationCoordinate2D? {
        guard
            self.north != kCLLocationCoordinate2DInvalid.latitude,
            self.east != kCLLocationCoordinate2DInvalid.longitude
        else {
            return nil
        }
        return .init(latitude: self.north, longitude: self.east)
    }
    
    var southWest: LocationCoordinate2D? {
        guard
            self.south != kCLLocationCoordinate2DInvalid.latitude,
            self.west != kCLLocationCoordinate2DInvalid.longitude
        else {
            return nil
        }
        return .init(latitude: self.south, longitude: self.west)
    }
}

extension Region : AreaMeasurable {
    
}

#if canImport(SwiftUI)
public extension Region {
    var flagImage: Image {
        self.flag?.image ?? .init(size: .zero) { _ in }
    }
}
#endif // canImport(SwiftUI)
