//
//  KeyholeMarkupLanguage.swift
//  UmbreonPersistence
//
//  Created by Lucka on 3/9/2025.
//

import Foundation
import SphereGeometry
import System
import Turf
import UmbreonCore

public actor KeyholeMarkupLanguage : CellCollectionConvertible {
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

public extension CellCollectionConvertible where Self == KeyholeMarkupLanguage {
    static func keyholeMarkupLanguage(
        url: URL,
        distanceThreshold: Double
    ) -> KeyholeMarkupLanguage {
        .init(url: url, distanceThreshold: distanceThreshold)
    }
}

fileprivate extension KeyholeMarkupLanguage {
    enum ConvertError: LocalizedError {
        case unableToCreateParser
    }
}

fileprivate final class ParserDelegate : NSObject, XMLParserDelegate {
    typealias Coordinates = AsyncStream<LocationCoordinate2D?>
    
    enum ElementName: String {
        case coordinates
    }
    
    let coordinates: Coordinates
    
    private let continuation: Coordinates.Continuation
    
    private var currentCoordinateContent: String? = nil
        
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
        case .coordinates:
            currentCoordinateContent = ""
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
        case .coordinates:
            sendCoordinates()
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentCoordinateContent?.append(string)
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        continuation.finish()
    }
    
    func terminate() {
        continuation.finish()
    }
    
    private func sendCoordinates() {
        currentCoordinateContent?
            .split(whereSeparator: \.isWhitespace)
            .forEach { content in
                let components = content.split(separator: ",")
                guard
                    components.count >= 2,
                    let longitude = Double(components[0]),
                    let latitude = Double(components[1])
                else {
                    return
                }
                continuation.yield(.init(latitude: latitude, longitude: longitude))
            }
        
        currentCoordinateContent = nil
        continuation.yield(nil)
    }
}
