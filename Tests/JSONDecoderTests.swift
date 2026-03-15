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

    private func makeMatchingEncoder(for decoder: JSONDecoder) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.userInfo = decoder.userInfo
        encoder.outputFormatting = [.sortedKeys]

        // Key strategy parity
        switch decoder.keyDecodingStrategy {
        case .useDefaultKeys:
            encoder.keyEncodingStrategy = .useDefaultKeys
        case .convertFromSnakeCase:
            encoder.keyEncodingStrategy = .convertToSnakeCase
        case .custom:
            // No exact inverse; use default (custom tests will assert behavior separately if needed)
            encoder.keyEncodingStrategy = .useDefaultKeys
        @unknown default:
            encoder.keyEncodingStrategy = .useDefaultKeys
        }

        // Date strategy parity
        switch decoder.dateDecodingStrategy {
        case .deferredToDate:
            encoder.dateEncodingStrategy = .deferredToDate
        case .secondsSince1970:
            encoder.dateEncodingStrategy = .secondsSince1970
        case .millisecondsSince1970:
            encoder.dateEncodingStrategy = .millisecondsSince1970
        case .iso8601:
            encoder.dateEncodingStrategy = .iso8601
        #if !os(Linux) && !os(Android)
        case let .formatted(f):
            encoder.dateEncodingStrategy = .formatted(f)
        #endif
        case .custom:
            // No exact inverse for custom; leave default (custom tests will handle this explicitly)
            encoder.dateEncodingStrategy = .deferredToDate
        @unknown default:
            break
        }

        // Data strategy parity
        switch decoder.dataDecodingStrategy {
        case .deferredToData:
            encoder.dataEncodingStrategy = .deferredToData
        case .base64:
            encoder.dataEncodingStrategy = .base64
        case .custom:
            // No exact inverse available; leave default; custom tests will mirror explicitly
            encoder.dataEncodingStrategy = .deferredToData
        @unknown default:
            break
        }

        // Non-conforming float parity
        switch decoder.nonConformingFloatDecodingStrategy {
        case .throw:
            encoder.nonConformingFloatEncodingStrategy = .throw
        case let .convertFromString(positiveInfinity, negativeInfinity, nan):
            encoder.nonConformingFloatEncodingStrategy = .convertToString(
                positiveInfinity: positiveInfinity,
                negativeInfinity: negativeInfinity,
                nan: nan
            )
        @unknown default:
            break
        }

        return encoder
    }

    /// Generic helper: assert parity JSON vs Data for a Decodable & Equatable type
    private func expectParity<T: Decodable & Equatable>(
        _: T.Type,
        json: JSON,
        configure: (JSONDecoder) -> Void = { _ in }
    ) throws {
        let decoder = JSONDecoder()
        configure(decoder)

        // Build matching encoder
        let encoder = makeMatchingEncoder(for: decoder)
        let data = try encoder.encode(json)

        let fromJSON = try decoder.decode(T.self, from: json)
        let fromData = try decoder.decode(T.self, from: data)

        #expect(fromJSON == fromData, "Decoding from JSON and Data should produce the same result.")
    }

    /// Generic helper for expected failure parity
    private func expectBothThrow<T: Decodable>(
        _: T.Type,
        json: JSON,
        configure: (JSONDecoder) -> Void = { _ in }
    ) {
        let decoder = JSONDecoder()
        configure(decoder)
        let encoder = makeMatchingEncoder(for: decoder)
        let data = try? encoder.encode(json)

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(T.self, from: json)
        }
        #expect(throws: DecodingError.self) {
            // If encoding somehow succeeded, ensure Data path also throws; otherwise, force a throw.
            if let data {
                _ = try decoder.decode(T.self, from: data)
            } else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Encoding failed; cannot test parity."))
            }
        }
    }

    // MARK: - Models

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

    // MARK: - Single value parity

    @Test
    func singleValuesParity() throws {
        try expectParity(Bool.self, json: .bool(true))
        try expectParity(String.self, json: .string("hello"))
        try expectParity(Int.self, json: .int(42))
        try expectParity(Double.self, json: .double(3.5))

        // Optional nil parity
        try expectParity(Bool?.self, json: .null)
    }

    @Test
    func singleValueMismatchParity() {
        // Int from non-whole Double
        struct M: Decodable { let v: Int }
        expectBothThrow(M.self, json: ["v": 1.1])

        // Wrong primitive
        struct S: Decodable { let v: String }
        expectBothThrow(S.self, json: ["v": true])

        // Single value container cannot wrap array/object
        expectBothThrow(Int.self, json: .array([1, 2]))
        expectBothThrow(String.self, json: .object(["a": 1]))
    }

    // MARK: - Keyed containers parity

    @Test
    func keyedContainerParity() throws {
        let json: JSON = ["a": 1, "b": "two", "c": true]
        try expectParity(Simple.self, json: json)
    }

    @Test
    func allKeysContainsParity() throws {
        struct Probe: Decodable, Equatable {
            let x: Int; let y: String; let z: Bool
        }
        let json: JSON = ["x": 1, "y": "str", "z": false]
        try expectParity(Probe.self, json: json)
    }

    @Test
    func missingKeyAndNullHandlingParity() throws {
        struct Model: Decodable, Equatable {
            let present: Int
            let missing: String?
            let nullValue: Int?
        }
        let json: JSON = ["present": 1, "nullValue": nil]
        try expectParity(Model.self, json: json)

        struct NonOptionalNull: Decodable { let nullValue: Int }
        expectBothThrow(NonOptionalNull.self, json: json)

        struct MissingNonOptional: Decodable { let missing: Int }
        expectBothThrow(MissingNonOptional.self, json: json)
    }

    // MARK: - Nested containers parity

    @Test
    func nestedContainersParity() throws {
        let json: JSON = [
            "obj": ["a": 10, "b": "bee", "c": true],
            "arr": [1, 2, 3],
        ]
        try expectParity(Nested.self, json: json)
    }

    @Test
    func nestedContainerTypeMismatchParity() {
        struct ExpectKeyedButArray: Decodable {
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: AnyKey.self)
                _ = try container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("arr"))
            }
        }
        expectBothThrow(ExpectKeyedButArray.self, json: ["arr": [1, 2]])

        struct ExpectUnkeyedButObject: Decodable {
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: AnyKey.self)
                _ = try container.nestedUnkeyedContainer(forKey: AnyKey("obj"))
            }
        }
        expectBothThrow(ExpectUnkeyedButObject.self, json: ["obj": ["a": 1]])
    }

    // MARK: - Unkeyed containers parity

    @Test
    func unkeyedParity() throws {
        struct Probe: Decodable, Equatable {
            let a: Int; let b: Int; let c: String; let d: Bool; let e: String?

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                a = try container.decode(Int.self)
                b = try container.decode(Int.self)
                c = try container.decode(String.self)
                d = try container.decode(Bool.self)
                e = try container.decodeIfPresent(String.self)
            }
        }
        let json: JSON = [1, 2.0, "3", true, nil]
        try expectParity(Probe.self, json: json)
    }

    @Test
    func unkeyedOverrunAndTypeMismatchParity() {
        struct Overrun: Decodable {
            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                _ = try c.decode(Int.self)
                _ = try c.decode(Int.self) // overrun
            }
        }
        expectBothThrow(Overrun.self, json: [1])

        struct TypeMismatch: Decodable {
            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                _ = try c.decode(String.self) // first element is Int
            }
        }
        expectBothThrow(TypeMismatch.self, json: [1])
    }

    // MARK: - Model parity

    @Test
    func modelParity() throws {
        struct Person: Decodable, Equatable {
            let firstName: String
            let lastName: String
            let height: Int
            let dateOfBirth: String
        }
        let json: JSON = [
            "firstName": "Guy",
            "lastName": "Kogus",
            "height": 173,
            "dateOfBirth": "1970-01-01T00:00:00Z",
        ]
        try expectParity(Person.self, json: json)
    }

    // MARK: - Strategy parity

    @Test
    func keyDecoding_convertFromSnakeCase_parity() throws {
        struct Model: Decodable, Equatable {
            let firstName: String
            let lastName: String
            let dateOfBirth: Date
        }
        let json: JSON = [
            "first_name": "Guy",
            "last_name": "Kogus",
            "date_of_birth": "1970-01-01T00:00:00Z",
        ]
        try expectParity(Model.self, json: json) { decoder in
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
        }
    }

    @Test
    func customKeyStrategy_parity() throws {
        struct Model: Decodable, Equatable { let valueHere: Int }
        let json: JSON = ["VALUE-HERE": 42]
        try expectParity(Model.self, json: json) { decoder in
            decoder.keyDecodingStrategy = .custom { path in
                let last = path.last!
                let parts = last.stringValue.lowercased().split(separator: "-")
                let transformed = parts.enumerated().map { index, part in
                    index == 0 ? String(part) : part.prefix(1).uppercased() + part.dropFirst()
                }.joined()
                return AnyKey(transformed)
            }
        }
    }

    @Test
    func dateStrategies_parity() throws {
        struct A: Decodable, Equatable { let a: Date }
        struct B: Decodable, Equatable { let b: Date }
        struct C: Decodable, Equatable { let c: Date }
        struct E: Decodable, Equatable { let x: Date }

        try expectParity(A.self, json: ["a": 1000.0]) { $0.dateDecodingStrategy = .secondsSince1970 }
        try expectParity(B.self, json: ["b": 2_000_000.0]) { $0.dateDecodingStrategy = .millisecondsSince1970 }
        try expectParity(C.self, json: ["c": "1970-01-01T00:00:00Z"]) { $0.dateDecodingStrategy = .iso8601 }

        #if !os(Linux) && !os(Android)
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm:ss ZZZ"
        try expectParity(E.self, json: ["x": "1970/01/01 00:00:00 +0000"]) {
            $0.dateDecodingStrategy = .formatted(df)
        }
        #endif
    }

    @Test
    func dateStrategy_custom_parity() throws {
        struct F: Decodable, Equatable { let y: Date }
        let json: JSON = ["y": "1971-xx"]
        try expectParity(F.self, json: json) { decoder in
            decoder.dateDecodingStrategy = .custom { decoder in
                let c = try decoder.singleValueContainer()
                let s = try c.decode(String.self)
                let year = Int(s.prefix(4)) ?? 1970
                return Date(timeIntervalSince1970: TimeInterval((year - 1970) * 31_536_000))
            }
        }
    }

    @Test
    func dataStrategies_parity() throws {
        struct M1: Decodable, Equatable { let d: Data }
        let bytes = Data([0x01, 0x02, 0x03])
        let b64 = bytes.base64EncodedString()
        try expectParity(M1.self, json: ["d": .string(b64)]) {
            $0.dataDecodingStrategy = .base64
        }
    }

    @Test
    func dataStrategy_custom_parity() throws {
        struct M2: Decodable, Equatable { let d: Data }
        try expectParity(M2.self, json: ["d": .string("abc")]) { decoder in
            decoder.dataDecodingStrategy = .custom { decoder in
                let c = try decoder.singleValueContainer()
                let s = try c.decode(String.self)
                return Data(s.utf8)
            }
        }
    }

    @Test
    func nonConformingFloat_convert_parity() throws {
        struct InfinityModel: Decodable, Equatable { let a: Double; let b: Double }
        let infinityJSON: JSON = ["a": .string("INF"), "b": .string("-INF")]
        try expectParity(InfinityModel.self, json: infinityJSON) { decoder in
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN")
        }

        struct M: Decodable, Equatable { let a: Double; let b: Double; let c: Double }
        let json: JSON = ["a": .string("INF"), "b": .string("-INF"), "c": .string("NaN")]
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN")
        let fromJSON = try decoder.decode(M.self, from: json)
        let encoded = try makeMatchingEncoder(for: decoder).encode(json)
        let fromData = try decoder.decode(M.self, from: encoded)
        #expect(fromJSON.a == fromData.a)
        #expect(fromJSON.b == fromData.b)
        #expect(fromJSON.c.isNaN)
        #expect(fromData.c.isNaN)
    }

    @Test
    func nonConformingFloat_throw_parity() {
        struct M: Decodable { let a: Double }
        expectBothThrow(M.self, json: ["a": .string("INF")]) { decoder in
            decoder.nonConformingFloatDecodingStrategy = .throw
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
}
