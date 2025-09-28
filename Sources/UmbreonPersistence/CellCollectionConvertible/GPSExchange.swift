//
//  GPSExchange.swift
//  UmbreonPersistence
//
//  Created by Lucka on 22/9/2024.
//

import Foundation
import SphereGeometry
import System
import Turf
import UmbreonCore

public actor GPSExchange : CellCollectionConvertible {
    public let progress = Progress(totalUnitCount: 1)
    
    private let url: URL
    
    private let distanceThreshold: Double
    
    init(url: URL, distanceThreshold: Double) {
        self.url = url
        self.distanceThreshold = distanceThreshold
    }
    
    public func convert() async throws -> CellCollection {
        let delegate = ParserDelegate()
        let parseTask = Task.detached {
            guard let parser = XMLParser(contentsOf: self.url) else {
                throw ConvertError.unableToCreateParser
            }
            parser.delegate = delegate
            if !parser.parse() {
                delegate.terminate()
                if let error = parser.parserError {
                    throw error
                } else {
                    throw Errno.canceled
                }
            }
        }
        
        let cells = try await delegate.coordinates.strideCells(
            at: PartialCellCollection.detailedLevel,
            breakWhenFurtherThan: distanceThreshold
        )
        
        try await parseTask.value
        
        progress.completedUnitCount = 1
        
        return cells
    }
}

public extension CellCollectionConvertible where Self == GPSExchange {
    static func gpsExchange(url: URL, distanceThreshold: Double) -> GPSExchange {
        .init(url: url, distanceThreshold: distanceThreshold)
    }
}

fileprivate extension GPSExchange {
    enum ConvertError: LocalizedError {
        case unableToCreateParser
    }
}

fileprivate final class ParserDelegate : NSObject, XMLParserDelegate {
    typealias Coordinates = AsyncStream<LocationCoordinate2D?>
    
    enum ElementName: String {
        case route = "rte"
        case routePoints = "rtept"
        case waypoint = "wpt"
        
        case track = "trk"
        case trackSegment = "trkseg"
        case trackPoint = "trkpt"
    }
    
    let coordinates: Coordinates
    
    private let continuation: Coordinates.Continuation
        
    override init() {
        let (stream, continuation) = Coordinates.makeStream()
        self.coordinates = stream
        self.continuation = continuation
    }
    
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [ String : String ] = [ : ]
    ) {
        switch ElementName(rawValue: elementName) {
        case .trackPoint, .waypoint:
            continuation.yield(Self.parseCoordinate(from: attributeDict))
        default:
            break
        }
    }
    
    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch ElementName(rawValue: elementName) {
        case .routePoints, .trackSegment:
            continuation.yield(nil)
        default:
            break
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        continuation.finish()
    }
    
    func terminate() {
        continuation.finish()
    }
    
    private static func parseCoordinate(
        from attributes: [ String : String ]
    ) -> LocationCoordinate2D? {
        guard
            let longitudeValue = attributes["lon"],
            let latitudeValue = attributes["lat"],
            let longitude = Double(longitudeValue),
            let latitude = Double(latitudeValue)
        else {
            return nil
        }
        return .init(latitude: latitude, longitude: longitude)
    }
}
