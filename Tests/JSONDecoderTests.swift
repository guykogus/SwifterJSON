//
//  JSONDecoderTests.swift
//  SwifterJSON
//
//  Created by Guy Kogus on 15/10/25.
//

import Foundation
@testable import SwifterJSON
import Testing

struct JSONDecoderTests {
    // MARK: - Helpers

    private func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    private struct Person: Decodable, Equatable {
        let firstName: String
        let lastName: String
        let height: Int
        let dateOfBirth: String
    }

    private struct Simple: Decodable, Equatable {
        let a: Int
        let b: String
        let c: Bool
    }

    private struct Nested: Decodable, Equatable {
        let obj: Simple
        let arr: [Int]
    }

    // MARK: - Single value decoding

    @Test
    func decodeSingleValues() throws {
        let decoder = makeDecoder()

        #expect(try decoder.decode(Bool.self, from: JSON.bool(true)) == true)
        #expect(try decoder.decode(Bool.self, from: JSON.bool(false)) == false)

        #expect(try decoder.decode(String.self, from: JSON.string("hello")) == "hello")

        #expect(try decoder.decode(Int.self, from: JSON.int(42)) == 42)
        // Whole double to Int
        #expect(try decoder.decode(Int.self, from: JSON.double(42.0)) == 42)
        // Int to Double
        #expect(try decoder.decode(Double.self, from: JSON.int(7)) == 7.0)
        #expect(try decoder.decode(Double.self, from: JSON.double(3.5)) == 3.5)

        // Null to Optional
        let stringOpt: String? = try decoder.decode(String?.self, from: .null)
        #expect(stringOpt == nil)
    }

    @Test
    func singleValueTypeMismatchErrors() {
        let decoder = makeDecoder()

        // Non-whole double to Int should fail
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(Int.self, from: JSON.double(1.1))
        }

        // Wrong primitive type
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(String.self, from: JSON.bool(true))
        }

        // Single value container cannot be created for array/object
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(Int.self, from: JSON.array([1, 2, 3]))
        }
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(String.self, from: JSON.object(["a": 1]))
        }
    }

    // MARK: - Keyed containers

    @Test
    func decodeKeyedContainerSuccess() throws {
        let decoder = makeDecoder()
        let json: JSON = [
            "a": 1,
            "b": "two",
            "c": true,
        ]

        let value = try decoder.decode(Simple.self, from: json)
        #expect(value == Simple(a: 1, b: "two", c: true))
    }

    @Test
    func keyedContainerAllKeysAndContains() throws {
        let json: JSON = [
            "x": 1,
            "y": "str",
            "z": false,
        ]

        // Use a custom Decodable to peek into allKeys and contains indirectly by decoding
        struct Probe: Decodable {
            let x: Int
            let y: String
            let z: Bool

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: AnyKey.self)
                // allKeys are the three
                #expect(container.allKeys.count == 3)
                #expect(container.contains(AnyKey("x")))
                #expect(container.contains(AnyKey("y")))
                #expect(container.contains(AnyKey("z")))
                x = try container.decode(Int.self, forKey: AnyKey("x"))
                y = try container.decode(String.self, forKey: AnyKey("y"))
                z = try container.decode(Bool.self, forKey: AnyKey("z"))
            }
        }

        _ = try makeDecoder().decode(Probe.self, from: json)
    }

    @Test
    func keyedContainerMissingKeyAndNullHandling() {
        let decoder = makeDecoder()
        let json: JSON = [
            "present": 1,
            "nullValue": nil,
        ]

        struct Model: Decodable {
            let present: Int
            let missing: String? // Optional should decode as nil when absent
            let nullValue: Int? // Optional should decode nil when value is null
        }

        // Optional decoding should succeed with nils
        let model = try? decoder.decode(Model.self, from: json)
        #expect(model?.present == 1)
        #expect(model?.missing == nil)
        #expect(model?.nullValue == nil)

        // But decoding a non-optional from null should throw valueNotFound
        struct Bad: Decodable { let nullValue: Int }
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(Bad.self, from: json)
        }

        // Decoding a missing non-optional key should throw keyNotFound
        struct MissingBad: Decodable { let missing: Int }
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(MissingBad.self, from: json)
        }
    }

    @Test
    func nestedKeyedAndUnkeyedContainers() throws {
        let decoder = makeDecoder()
        let json: JSON = [
            "obj": [
                "a": 10,
                "b": "bee",
                "c": true,
            ],
            "arr": [1, 2, 3],
        ]

        let value = try decoder.decode(Nested.self, from: json)
        #expect(value == Nested(obj: Simple(a: 10, b: "bee", c: true), arr: [1, 2, 3]))
    }

    @Test
    func nestedContainerTypeMismatchErrors() {
        let decoder = makeDecoder()

        // Expect nested keyed container but got array
        struct ExpectKeyedButArray: Decodable {
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: AnyKey.self)
                #expect(throws: DecodingError.self) {
                    _ = try container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("arr"))
                }
            }
        }

        let json1: JSON = ["arr": [1, 2]]
        _ = try? decoder.decode(ExpectKeyedButArray.self, from: json1)

        // Expect nested unkeyed container but got object
        struct ExpectUnkeyedButObject: Decodable {
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: AnyKey.self)
                #expect(throws: DecodingError.self) {
                    _ = try container.nestedUnkeyedContainer(forKey: AnyKey("obj"))
                }
            }
        }
        let json2: JSON = ["obj": ["a": 1]]
        _ = try? decoder.decode(ExpectUnkeyedButObject.self, from: json2)
    }

    // MARK: - Unkeyed containers

    @Test
    func unkeyedContainerDecodingAndIndexing() throws {
        let decoder = makeDecoder()
        let json: JSON = [1, 2.0, "3", true, nil]

        struct Probe: Decodable {
            let a: Int
            let b: Int
            let c: String
            let d: Bool
            let eIsNil: Bool

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                a = try container.decode(Int.self) // 1
                b = try container.decode(Int.self) // 2.0 as whole -> 2
                c = try container.decode(String.self) // "3"
                d = try container.decode(Bool.self) // true
                eIsNil = try container.decodeNil() // nil
                #expect(container.isAtEnd)
                #expect(container.currentIndex == 5)
            }
        }

        let probe = try decoder.decode(Probe.self, from: json)
        #expect(probe.a == 1 && probe.b == 2 && probe.c == "3" && probe.d == true && probe.eIsNil == true)
    }

    @Test
    func unkeyedContainerOverrunAndTypeMismatch() {
        let decoder = makeDecoder()
        let json: JSON = [1]

        struct Overrun: Decodable {
            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                _ = try c.decode(Int.self) // ok
                // Overrun should throw dataCorrupted
                #expect(throws: DecodingError.self) {
                    _ = try c.decode(Int.self)
                }
            }
        }
        _ = try? decoder.decode(Overrun.self, from: json)

        struct TypeMismatch: Decodable {
            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                #expect(throws: DecodingError.self) {
                    _ = try c.decode(String.self) // first element is Int
                }
            }
        }
        _ = try? decoder.decode(TypeMismatch.self, from: json)
    }

    // MARK: - Decoding model from JSON

    @Test
    func decodeCustomModelFromJSON() throws {
        let decoder = makeDecoder()
        let json: JSON = [
            "firstName": "Guy",
            "lastName": "Kogus",
            "height": 173,
            "dateOfBirth": "1970-01-01T00:00:00Z",
        ]

        let person = try decoder.decode(Person.self, from: json)
        #expect(person == Person(firstName: "Guy", lastName: "Kogus", height: 173, dateOfBirth: "1970-01-01T00:00:00Z"))
    }

    // MARK: - Super decoders and codingPath (spot checks)

    @Test
    func superDecoderAndCodingPathSpotCheck() throws {
        struct Wrapper: Decodable {
            let a: Int
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: AnyKey.self)
                let superDec = try container.superDecoder(forKey: AnyKey("a"))
                // Decoding through super decoder should still succeed
                let single = try superDec.singleValueContainer()
                a = try single.decode(Int.self)
            }
        }

        let json: JSON = ["a": 1]
        let wrapper = try makeDecoder().decode(Wrapper.self, from: json)
        #expect(wrapper.a == 1)
    }

    // MARK: - Performance comparison

    private struct BigModel: Decodable, Equatable {
        struct Item: Decodable, Equatable {
            let id: Int
            let name: String
            let active: Bool
            let score: Double
            let tags: [String]
            let nested: [String: Int]
        }

        let title: String
        let count: Int
        let items: [Item]
    }

    private func makeBigJSON(items: Int) -> JSON {
        let item: (Int) -> JSON = { i in
            [
                "id": .int(i),
                "name": .string("Item \(i)"),
                "active": .bool(i % 2 == 0),
                "score": .double(Double(i) * 0.5),
                "tags": .array([
                    .string("a"),
                    .string("b"),
                    .string("c"),
                    .string(String(i)),
                ]),
                "nested": .object([
                    "a": .int(i),
                    "b": .int(i * 2),
                    "c": .int(i * 3),
                ]),
            ]
        }
        let itemsArray = JSON.array((0 ..< items).map(item))
        return [
            "title": .string("Big Payload"),
            "count": .int(items),
            "items": itemsArray,
        ]
    }

    @Test("JSONDecoder should be >25% faster decoding a JSON object than converting to/from raw data")
    func performanceComparisonSwifterJSONDecoderVsJSONDecoder() throws {
        // Build a sizable JSON payload
        let elementCount = 2000 // adjust for your machine/time budget
        let json = makeBigJSON(items: elementCount)

        // Prepare encoder
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]

        // Warm-up decoder
        let decoder = JSONDecoder()
        do {
            _ = try decoder.decode(BigModel.self, from: json)
            _ = try decoder.decode(BigModel.self, from: encoder.encode(json))
        }

        // Measure
        let iterations = 10
        var swifterTotal: Double = 0
        var foundationTotal: Double = 0

        let clock = ContinuousClock()

        for _ in 0 ..< iterations {
            // JSON timing
            let swifterStart = clock.now
            _ = try decoder.decode(BigModel.self, from: json)
            let swifterEnd = clock.now
            let swifterDur = swifterStart.duration(to: swifterEnd).components
            swifterTotal += Double(swifterDur.seconds) + Double(swifterDur.attoseconds) / 1e18

            // JSONEncoder timing (encode each iteration to match realistic pipeline)
            let foundationStart = clock.now
            _ = try decoder.decode(BigModel.self, from: encoder.encode(json))
            let foundationEnd = clock.now
            let foundationDur = foundationStart.duration(to: foundationEnd).components
            foundationTotal += Double(foundationDur.seconds) + Double(foundationDur.attoseconds) / 1e18
        }

        let swifterAvg = swifterTotal / Double(iterations)
        let foundationAvg = foundationTotal / Double(iterations)

        // Percentage improvement: how much faster SwifterJSONDecoder is vs Foundation
        // improvement = (Foundation - Swifter) / Foundation
        let improvement = (foundationAvg - swifterAvg) / foundationAvg

        // Log the results to help diagnose in CI
        print(String(format: "Swifter avg: %.6fs, Foundation avg: %.6fs, improvement: %.2f%%, iterations: %d, n: %d",
                     swifterAvg, foundationAvg, improvement * 100, iterations, elementCount))

        // Require at least 25% faster
        #expect(improvement >= 0.25, "Expected SwifterJSONDecoder to be at least 25% faster. Improvement: \(Int(improvement * 100))%% (Swifter: \(swifterAvg)s, Foundation: \(foundationAvg)s)")
    }
}

// MARK: - AnyKey helper

private struct AnyKey: CodingKey, Hashable {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        stringValue = string
        intValue = Int(string)
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = Int(stringValue)
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
