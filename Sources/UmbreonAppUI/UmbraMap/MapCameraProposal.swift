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
    public let positionedByUser: Bool
    
    public let followsUser: Bool
    
    let center: LocationCoordinate2D?
    let verticalPosition: Double?
    
    let boundingBox: BoundingBox?
    
    init(
        positionedByUser: Bool,
        followsUser: Bool = false,
        center: LocationCoordinate2D? = nil,
        verticalPosition: Double? = nil,
        boundingBox: BoundingBox? = nil
    ) {
        self.positionedByUser = positionedByUser
        self.followsUser = followsUser
        self.center = center
        self.verticalPosition = verticalPosition
        self.boundingBox = boundingBox
    }
}

public extension MapCameraProposal {
    static var idle: Self {
        .init(positionedByUser: false)
    }
    
    static func camera(center: LocationCoordinate2D, verticalPosition: Double) -> Self {
        .init(
            positionedByUser: false,
            center: center,
            verticalPosition: verticalPosition
        )
    }
    
    static func overview(boundingBox: BoundingBox) -> Self {
        .init(positionedByUser: false, boundingBox: boundingBox)
    }
}

public extension MapCameraProposal {
    static var followsUser: Self {
        .init(positionedByUser: false, followsUser: true)
    }
    
    static func followsUserWithFallback(
        center: LocationCoordinate2D, verticalPosition: Double
    ) -> Self {
        .init(
            positionedByUser: false,
            followsUser: true,
            center: center,
            verticalPosition: verticalPosition
        )
    }
}

extension MapCameraProposal : Equatable, Sendable {
    
}

extension MapCameraProposal {
    static var positionedByUser: Self {
        .init(positionedByUser: true)
    }
}
    
extension MapCameraProposal {
#if canImport(MapboxMaps)
    static let defaultVerticalPosition = Viewport.followsUserMinZoom
#else
    static let defaultVerticalPosition = Viewport.followsUserMaxDistance
#endif
    
    func viewport(currentCamera: CameraState?) -> Viewport {
        let verticalPosition = verticalPosition ??
            currentCamera?.verticalPosition ??
            Self.defaultVerticalPosition
        
        return if let boundingBox {
            .overview(boundingBox: boundingBox)
        } else if followsUser {
            .followsUser(
                fallback: center ?? currentCamera?.center,
                verticalPosition: verticalPosition
            )
        } else if let center {
            .camera(center: center, verticalPosition: verticalPosition)
        } else {
            .idle(at: currentCamera)
        }
    }
}
