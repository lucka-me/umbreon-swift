//
//  CellCollection+Shape.swift
//  UmbreonAppUI
//
//  Created by Lucka on 17/9/2024.
//

import Foundation
import SphereGeometry
import Turf

extension CellCollection {
    func rings(at level: Level) -> [ [ LocationCoordinate2D ] ] {
        var generator = ShapeGenerator(at: level)
        generator.insert(self)
        return generator.generate()
    }
}

fileprivate struct ShapeGenerator {
    private let step: Block.Scalar

    private var blocks: [ Block.Key : Block ] = [ : ]
    
    init(at level: Level) {
        self.step = LeafCoordinate.step(at: level)
    }
    
    mutating func generate() -> [ [ LocationCoordinate2D ] ] {
        var shapes: [ [ LocationCoordinate2D ] ] = [ ]
        while var block = blocks.popFirst() {
            let zone = block.key.zone
            let coordinateTransform = Block.Hemisphere.of(block: block.key).coordinateTransform
            while !block.value.isEmpty {
                let leafCoordinateShape = block.value.popShape()
                shapes.append(
                    leafCoordinateShape.map { coordinateTransform(zone, $0) }
                )
            }
        }
        return shapes
    }
    
    mutating func insert(_ cells: CellCollection) {
        var lower = cells.startIndex
        repeat {
            let reginKey = Self.regionKey(for: cells[lower])
            let upper = cells.index(after: reginKey, since: lower)
            
            typealias EdgeSource = (
                horizontal: [ Block.Edge ],
                vertical: [ Block.Edge ]
            )
            
            // TODO: Is it possible to maintain order and remove duplicated element when insert edges?
            var source: EdgeSource = cells[ lower ..< upper ]
                .reduce(into: ([], [])) { result, item in
                    let cell = item.cell
                    let length = LeafCoordinate.step(at: cell.level)
                    
                    for distance in stride(from: 0, to: length, by: .init(step)) {
                        result.horizontal.append(
                            .init(
                                row: cell.coordinate.j,
                                column: cell.coordinate.i + distance
                            )
                        )
                        result.horizontal.append(
                            .init(
                                row: cell.coordinate.j + length,
                                column: cell.coordinate.i + distance
                            )
                        )
                        
                        result.vertical.append(
                            .init(
                                row: cell.coordinate.i,
                                column: cell.coordinate.j + distance
                            )
                        )
                        result.vertical.append(
                            .init(
                                row: cell.coordinate.i + length,
                                column: cell.coordinate.j + distance
                            )
                        )
                    }
                }
            
            blocks[reginKey] = .init(
                step: step,
                horizontal: Self.buildEdgeDictionary(&source.horizontal),
                vertical: Self.buildEdgeDictionary(&source.vertical)
            )
            
            lower = upper
        } while lower < cells.endIndex
    }
}

fileprivate extension ShapeGenerator {
    static func regionKey(for cellIdentifier: CellIdentifier) -> Block.Key {
        let zone = cellIdentifier.zone
        return switch zone {
        case .africa, .asia, .america: .whole(zone: zone)
        default: cellIdentifier.parent(at: .at.1)!
        }
    }
    
    static func buildEdgeDictionary(
        _ edges: inout [ Block.Edge ]
    ) -> Block.EdgeDictionary {
        edges.sort()
        
        // TODO: Simplify the following code
        var result: Block.EdgeDictionary = [ : ]
        var currentRow: Block.Row? = nil
        var currentColumns: Set<Block.Column> = [ ]
        var index = 0
        let lastIndex = edges.count - 1
        repeat {
            if currentRow != edges[index].row {
                // Start of new row
                if !currentColumns.isEmpty {
                    result[currentRow!] = currentColumns
                    currentColumns.removeAll()
                }
                
                currentRow = edges[index].row
            }
            
            if edges[index] != edges[index + 1] {
                // Different edges, add current one
                currentColumns.insert(edges[index].column)
            } else {
                // Same edges, skip
                index += 1
            }
            
            index += 1
        } while index < lastIndex
        
        if index == lastIndex {
            // The last two are not same, add the last one
            if currentRow != edges[index].row {
                // Last row
                if !currentColumns.isEmpty {
                    result[currentRow!] = currentColumns
                }
                // New row
                result[edges[index].row] = [ edges[index].column ]
            } else {
                // Same row
                currentColumns.insert(edges[index].column)
                result[currentRow!] = currentColumns
            }
        } else if !currentColumns.isEmpty {
            // The last two are the same, add the last row
            result[currentRow!] = currentColumns
        }
        
        return result
    }
}

fileprivate struct Block {
    let step: Scalar
    
    var horizontal: EdgeDictionary = [ : ]
    var vertical: EdgeDictionary = [ : ]
}

fileprivate extension Block {
    typealias Key = CellIdentifier
    
    typealias Scalar = LeafCoordinate.Scalar
    
    typealias Row = Scalar
    typealias Column = Scalar
    
    typealias EdgeDictionary = [ Row : Set<Column> ]
    
    enum Direction {
        case right
        case up
        case left
        case down
    }
    
    enum Hemisphere {
        case easternEdge
        case westernEdge
        case other
    }
    
    struct Edge {
        let row: Row
        let column: Column
    }
    
    var isEmpty: Bool {
        horizontal.isEmpty || vertical.isEmpty
    }
    
    mutating func popShape() -> [ LeafCoordinate.Coordinate ] {
        var shape = popFirstEdge()
        var directions = Array(repeating: Direction.right, count: 3)
        repeat {
            shape.append(search(from: shape.last!, directions: &directions))
            if
                directions[0] == directions[2],
                directions[0].isHorizontal != directions[1].isHorizontal
            {
                // Cut the corners
                if shape[shape.count - 3] % [ step, step ] == .zero {
                    switch directions[0] {
                    case .right: shape[shape.count - 3].x -= step / 2
                    case .up: shape[shape.count - 3].y -= step / 2
                    case .left: shape[shape.count - 3].x += step / 2
                    case .down: shape[shape.count - 3].y += step / 2
                    }
                    switch directions[1] {
                    case .right: shape[shape.count - 2].x -= step / 2
                    case .up: shape[shape.count - 2].y -= step / 2
                    case .left: shape[shape.count - 2].x += step / 2
                    case .down: shape[shape.count - 2].y += step / 2
                    }
                    switch directions[2] {
                    case .right: shape.insert(
                        shape[shape.count - 1] &- [ step / 2, 0 ], at: shape.count - 1
                    )
                    case .up: shape.insert(
                        shape[shape.count - 1] &- [ 0, step / 2 ], at: shape.count - 1
                    )
                    case .left: shape.insert(
                        shape[shape.count - 1] &+ [ step / 2, 0 ], at: shape.count - 1
                    )
                    case .down: shape.insert(
                        shape[shape.count - 1] &+ [ 0, step / 2 ], at: shape.count - 1
                    )
                    }
                } else {
                    switch directions[2] {
                    case .right: shape[shape.count - 2].x += step / 2
                    case .up: shape[shape.count - 2].y += step / 2
                    case .left: shape[shape.count - 2].x -= step / 2
                    case .down: shape[shape.count - 2].y -= step / 2
                    }
                }
            }
        } while shape.first != shape.last
        return shape
    }
    
    private mutating func popFirstEdge() -> [ LeafCoordinate.Coordinate ] {
        var element = horizontal.first!
        let edge = Edge(row: element.key, column: element.value.popFirst()!)
        if element.value.isEmpty {
            horizontal.remove(at: horizontal.startIndex)
        } else {
            horizontal.updateValue(element.value, forKey: element.key)
        }
        return [
            Direction.left.endCoordinate(of: edge, by: step),
            Direction.right.endCoordinate(of: edge, by: step)
        ]
    }

    private mutating func search(
        from coordinate: LeafCoordinate.Coordinate, directions: inout [ Direction ]
    ) -> LeafCoordinate.Coordinate {
        var result: LeafCoordinate.Coordinate? = nil
        for candidateDirection in directions[2].searchCandidates {
            guard !candidateDirection.willExceedZoneBoundary(from: coordinate) else {
                continue
            }
            let expectedEdge = candidateDirection.expectedEdge(from: coordinate, by: step)
            if candidateDirection.isHorizontal {
                guard horizontal.pop(item: expectedEdge) else {
                    continue
                }
            } else {
                guard vertical.pop(item: expectedEdge) else {
                    continue
                }
            }
            result = candidateDirection.endCoordinate(of: expectedEdge, by: step)
            directions.removeFirst()
            directions.append(candidateDirection)
            break
        }
        return result!
    }
}

extension Block.Edge : Comparable {
    static func < (lhs: Block.Edge, rhs: Block.Edge) -> Bool {
        if lhs.row != rhs.row {
            lhs.row < rhs.row
        } else {
            lhs.column < rhs.column
        }
    }
}

fileprivate extension Block.Direction {
    var searchCandidates: [ Self ] {
        switch self {
        case .right: [ .up, .right, .down ]
        case .up: [ .left, .up, .right ]
        case .left: [ .down, .left, .up ]
        case .down: [ .right, .down, .left ]
        }
    }
    
    var isHorizontal: Bool {
        switch self {
        case .right, .left:
            true
        case .up, .down:
            false
        }
    }
    
    func endCoordinate(
        of edge: Block.Edge, by step: Block.Scalar
    ) -> LeafCoordinate.Coordinate {
        switch self {
        case .right: .init(x: edge.column + step, y: edge.row)
        case .up: .init(x: edge.row, y: edge.column + step)
        case .left: .init(x: edge.column, y: edge.row)
        case .down: .init(x: edge.row, y: edge.column)
        }
    }
    
    func expectedEdge(
        from coordinate: LeafCoordinate.Coordinate, by step: Block.Scalar
    ) -> Block.Edge {
        switch self {
        case .right: .init(row: coordinate.y, column: coordinate.x)
        case .up: .init(row: coordinate.x, column: coordinate.y)
        case .left: .init(row: coordinate.y, column: coordinate.x - step)
        case .down: .init(row: coordinate.x, column: coordinate.y - step)
        }
    }
    
    func willExceedZoneBoundary(from coordinate: LeafCoordinate.Coordinate) -> Bool {
        switch self {
        case .right: coordinate.x == LeafCoordinate.scalarMax
        case .up: coordinate.y == LeafCoordinate.scalarMax
        case .left: coordinate.x == 0
        case .down: coordinate.y == 0
        }
    }
}

fileprivate extension Block.Hemisphere {
    static func of(block key: Block.Key) -> Self {
        let topBits = (key.rawValue >> 59) & 0b11
        return switch key.zone {
        case .north:
            switch topBits {
            case 2: .westernEdge
            case 3: .easternEdge
            default: other
            }
        case .pacific:
            switch topBits {
            case 0, 1: .easternEdge
            default: .westernEdge
            }
        case .south:
            switch topBits {
            case 0: .westernEdge
            case 1: .easternEdge
            default: other
            }
        default:
            other
        }
    }
    
    var coordinateTransform : (Zone, LeafCoordinate.Coordinate) -> LocationCoordinate2D {
        switch self {
        case .easternEdge:
            { zone, leaf in
                var location = LeafCoordinate(zone: zone, i: leaf.x, j: leaf.y)
                    .locationCoordinate
                if location.longitude < 0 {
                    location.longitude += 360
                }
                return location
            }
        case .westernEdge:
            { zone, leaf in
                var location = LeafCoordinate(zone: zone, i: leaf.x, j: leaf.y)
                    .locationCoordinate
                if location.longitude > 0 {
                    location.longitude -= 360
                }
                return location
            }
        case .other:
            { zone, leaf in
                LeafCoordinate(zone: zone, i: leaf.x, j: leaf.y)
                    .locationCoordinate
            }
        }
    }
}

fileprivate extension Block.EdgeDictionary {
    mutating func pop(item: Block.Edge) -> Bool {
        guard
            var element = self[item.row],
            let index = element.firstIndex(of: item.column)
        else {
            return false
        }
        element.remove(at: index)
        if element.isEmpty {
            self.removeValue(forKey: item.row)
        } else {
            self.updateValue(element, forKey: item.row)
        }
        return true
    }
}
