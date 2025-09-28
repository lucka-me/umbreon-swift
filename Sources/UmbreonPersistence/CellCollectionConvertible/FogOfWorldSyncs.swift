//
//  FogOfWorldSyncs.swift
//  UmbreonPersistence
//
//  Created by Lucka on 5/9/2024.
//

import Compression
import Foundation
import SphereGeometry
import Turf
import UmbreonCore

public actor FogOfWorldSyncs : CellCollectionConvertible {
    public let progress: Progress
    
    private let urls: [ URL ]
    
    fileprivate init(url: URL) throws {
        self.urls = if try url.isDirectory {
            try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        } else {
            [ url ]
        }
        
        // decompress + parse
        self.progress = .init(totalUnitCount: .init(urls.count * 3))
    }
    
    public func convert() async throws -> CellCollection {
        try await withThrowingTaskGroup(of: CellCollection.self) { @Sendable group in
            for url in urls {
                group.addTask {
                    guard
                        let tileUpperLeft = Tile.upperLeft(
                            from: url.lastPathComponent
                        )
                    else {
                        throw Self.makeInvalidFileNameError(from: url)
                    }
                    
                    let sourceHandle = try FileHandle(forReadingFrom: url)
                    // Magic header of zlib file, Compression does not support the magic
                    guard
                        let header = try sourceHandle.read(upToCount: 2),
                        header.count == 2 && header.starts(with: [ 0x78, 0x5E ])
                    else {
                        throw ConvertError.incorrectHeader
                    }
                    
                    let inputFilter = try InputFilter(.decompress, using: .zlib) { length in
                        try sourceHandle.read(upToCount: length)
                    }
                    var data = Data()
                    while let page = try inputFilter.readData(ofLength: 1024) {
                        data.append(page)
                    }
                    await self.makeProgress()
                    
                    return try Self.convert(decompressed: data, tileUpperLeft: tileUpperLeft)
                }
            }
            
            return try await group.reduce(into: .init()) { result, element in
                result.formUnion(element)
                await makeProgress()
            }
        }
    }
}

public extension CellCollectionConvertible where Self == FogOfWorldSyncs {
    static func fogOfWorldSyncs(url: URL) throws -> FogOfWorldSyncs {
        try .init(url: url)
    }
}

extension FogOfWorldSyncs {
    static func convert(compressed data: Data, from url: URL) throws -> CellCollection {
        guard let tileUpperLeft = Tile.upperLeft(from: url.lastPathComponent) else {
            throw makeInvalidFileNameError(from: url)
        }
        
        // Magic header of zlib file, Compression does not support the magic
        guard data.count > 2, data.starts(with: [ 0x78, 0x5E ]) else {
            throw ConvertError.incorrectHeader
        }
        
        var readPosition = 2
        let inputFilter = try InputFilter(.decompress, using: .zlib) { length in
            let readEnd = min(data.count, readPosition + length)
            defer {
                readPosition = readEnd
            }
            return data[readPosition ..< readEnd]
        }
        
        var decompressedData = Data()
        while let page = try inputFilter.readData(ofLength: 1024) {
            decompressedData.append(page)
        }
        
        return try convert(decompressed: decompressedData, tileUpperLeft: tileUpperLeft)
    }
}

fileprivate extension FogOfWorldSyncs {
    enum ConvertError: LocalizedError {
        case blockOverflow(block: UInt16)
        case incorrectDataSize(size: Int)
        case incorrectHeader
    }
    
    static func makeInvalidFileNameError(from url: URL) -> CocoaError {
        .init(
            .fileReadInvalidFileName,
            userInfo: [ NSFilePathErrorKey : url.lastPathComponent ]
        )
    }
    
    static func convert(
        decompressed data: Data, tileUpperLeft: Grid.Coordinate
    ) throws -> CellCollection {
        guard data.count >= Block.LabelSection.byteSize else {
            throw ConvertError.incorrectDataSize(size: data.count)
        }
        
        let cells = try (0 ..< Block.LabelSection.count)
            .flatMap { labelIndex -> [ CellIdentifier ] in
                let label = data.withUnsafeBytes { buffer in
                    buffer.load(
                        fromInstanceOffset: labelIndex,
                        as: Block.LabelSection.Label.self
                    )
                }
                guard label > 0 else {
                    return [ ]
                }
                
                let blockOffset = Block.byteOffset(of: label)
                guard data.count >= (blockOffset + Block.byteSize) else {
                    throw ConvertError.blockOverflow(block: label)
                }
                
                let blockData = data[blockOffset ..< blockOffset + Block.matrixByteSize]
                let blockUpperLeft = Block.upperLeft(of: labelIndex, in: tileUpperLeft)
                
                return blockData.enumerated()
                    .flatMap { byteIndex, byte -> [ CellIdentifier ] in
                        guard byte > 0 else {
                            return [ ]
                        }
                        return (0 ..< 8).compactMap { bitIndex in
                            let bit: Data.Element = 1 << bitIndex
                            guard byte & bit == bit else {
                                return nil
                            }
                            
                            let (offsetY, offsetX) = (byteIndex * 8 + (7 - bitIndex))
                                .quotientAndRemainder(dividingBy: Grid.countInBlockAxis)
                            let coordinate = Grid.centerLocationCoordinate(
                                inBlock: blockUpperLeft,
                                offsetX: offsetX,
                                offsetY: offsetY
                            )
                            return coordinate.cellIdentifier(
                                at: PartialCellCollection.detailedLevel
                            )
                        }
                    }
            }
        return .init(cells)
    }
    
    func makeProgress() {
        progress.completedUnitCount += 1
    }
}

fileprivate struct Tile {
    static let countInMercatorAxis = 512
    
    static func upperLeft(from filename: String) -> Grid.Coordinate? {
        guard filename.count > 6 else {
            return nil
        }
        
        let idRange = filename.index(filename.startIndex, offsetBy: 4) ..< filename.index(filename.endIndex, offsetBy: -2)
        var id = 0
        for character in filename[idRange] {
            guard let value = map(character: character) else {
                return nil
            }
            id = id * 10 + value
        }
        
        let (y, x) = id.quotientAndRemainder(dividingBy: Self.countInMercatorAxis)
        guard x < Self.countInMercatorAxis, y < Self.countInMercatorAxis else {
            return nil
        }
        
        return .init(x: x * Grid.countInTileAxis, y: y * Grid.countInTileAxis)
    }
    
    static private func map(character: Character) -> Int? {
        switch character {
        case "o": 0
        case "l": 1
        case "h": 2
        case "w": 3
        case "j": 4
        case "s": 5
        case "k": 6
        case "t": 7
        case "r": 8
        case "i": 9
        default: nil
        }
    }
}

fileprivate struct Block {
    struct LabelSection {
        typealias Index = Int
        typealias Label = UInt16
        
        static let count = countInTileAxis * countInTileAxis
        static let byteSize = count * MemoryLayout<Label>.size
    }

    static let countInTileAxis = 128
    static let tileCodeByteSize = 3
    static let matrixByteSize = (Grid.countInBlockAxis * Grid.countInBlockAxis) / 8
    static let byteSize = matrixByteSize + tileCodeByteSize
    
    static func byteOffset(of label: LabelSection.Label) -> Int {
        LabelSection.byteSize + (Int(label - 1) * byteSize)
    }
    
    static func upperLeft(
        of labelIndex: LabelSection.Index, in tileUpperLeft: Grid.Coordinate
    ) -> Grid.Coordinate {
        let (y, x) = labelIndex.quotientAndRemainder(dividingBy: Self.countInTileAxis)
        return tileUpperLeft &+ [ x * Grid.countInBlockAxis, y * Grid.countInBlockAxis ]
    }
}

fileprivate struct Grid {
    typealias Coordinate = SIMD2<Int>
    
    static let countInBlockAxis = 64    ///< Bit
    static let countInTileAxis = Block.countInTileAxis * Self.countInBlockAxis
    static let countInMercatorAxis = Tile.countInMercatorAxis * Self.countInTileAxis
    
    static func centerLocationCoordinate(
        inBlock upperLeft: Coordinate, offsetX: Coordinate.Scalar, offsetY: Coordinate.Scalar
    ) -> LocationCoordinate2D {
        .init(
            latitude: atan(sinh(.pi - ((Double(upperLeft.y + offsetY) + 0.5) / Double(Self.countInMercatorAxis) * 2 * .pi))) / .pi * 180,
            longitude: (Double(upperLeft.x + offsetX) + 0.5) / Double(Self.countInMercatorAxis) * 360 - 180
        )
    }
}

fileprivate extension UnsafeRawBufferPointer {
    func load<T>(fromInstanceOffset offset: Int = 0, as type: T.Type) -> T {
        load(fromByteOffset: offset * MemoryLayout<T>.size, as: type)
    }
}
