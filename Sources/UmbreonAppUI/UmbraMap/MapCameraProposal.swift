//
//  MapCameraProposal.swift
//  UmbreonAppUI
//
//  Created by Lucka on 18/8/2025.
//

import CoreLocation

#if os(iOS)
import MapboxMaps
#else
import MapKit
import Turf
#endif

public struct MapCameraProposal {
    public let isReportedByMap: Bool
    
    public let followUser: Bool
    
    let center: LocationCoordinate2D?
    let verticalPosition: Double?
    
    let boundingBox: BoundingBox?
    
    init(
        isReportedByMap: Bool,
        followUser: Bool = false,
        center: LocationCoordinate2D? = nil,
        verticalPosition: Double? = nil,
        boundingBox: BoundingBox? = nil
    ) {
        self.isReportedByMap = isReportedByMap
        self.followUser = followUser
        self.center = center
        self.verticalPosition = verticalPosition
        self.boundingBox = boundingBox
    }
}

public extension MapCameraProposal {
    static var followUser: Self {
        .init(isReportedByMap: false, followUser: true)
    }
    
    static var idle: Self {
        .init(isReportedByMap: false)
    }
    
    static func camera(center: LocationCoordinate2D, verticalPosition: Double) -> Self {
        .init(
            isReportedByMap: false,
            center: center,
            verticalPosition: verticalPosition
        )
    }
    
    static func followUserWithFallback(
        center: LocationCoordinate2D, verticalPosition: Double
    ) -> Self {
        .init(
            isReportedByMap: false,
            followUser: true,
            center: center,
            verticalPosition: verticalPosition
        )
    }
    
    static func overview(boundingBox: BoundingBox) -> Self {
        .init(isReportedByMap: false, boundingBox: boundingBox)
    }
}

extension MapCameraProposal : Equatable, Sendable {
    
}

extension MapCameraProposal {
    static var pannedByUser: Self {
        .init(isReportedByMap: true)
    }
    
    func viewport(currentZoom: CGFloat?) -> Viewport {
        if let boundingBox {
#if canImport(MapboxMaps)
            .overview(
                geometry: LineString([ boundingBox.southWest, boundingBox.northEast ]),
                geometryPadding: .init(top: 40, leading: 6, bottom: 40, trailing: 6)
            )
#else
            .region(boundingBox.coordinateRegion)
#endif
        } else if followUser {
#if canImport(MapboxMaps)
            .followPuck(zoom: verticalPosition ?? currentZoom ?? 16)
#else
            if let center, let verticalPosition {
                .userLocation(
                    fallback: .camera(center: center, verticalPosition: verticalPosition)
                )
            } else {
                .userLocation(fallback: .automatic)
            }
#endif
        } else if let center, let verticalPosition {
            .camera(center: center, verticalPosition: verticalPosition)
        } else {
            .idle
        }
    }
}

#if !canImport(MapboxMaps)
fileprivate extension BoundingBox {
    var coordinateRegion: MKCoordinateRegion {
        var center = CLLocationCoordinate2D(
            latitude: (northEast.latitude + southWest.latitude) / 2,
            longitude: (northEast.longitude + southWest.longitude) / 2
        )
        var span = MKCoordinateSpan(
            latitudeDelta: northEast.latitude - southWest.latitude,
            longitudeDelta: northEast.longitude - southWest.longitude
        )
        if northEast.longitude < southWest.longitude {
            center.longitude += 180
            span.longitudeDelta += 360
        }
        
        return .init(center: center, span: span)
    }
}
#endif
