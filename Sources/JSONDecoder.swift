//
//  JSONDecoder.swift
//  SwifterJSON
//
//  Created by Guy Kogus on 15/10/25.
//

#if canImport(Foundation)
import Foundation

public extension JSONDecoder {
    func decode<T>(_: T.Type, from: JSON) throws -> T where T: Decodable {
        try T(from: JSONDecoderImpl(codingPath: [], userInfo: [:], json: from))
    }
}

private struct JSONDecoderImpl: Decoder {
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    private let json: JSON

    init(codingPath: [any CodingKey], userInfo: [CodingUserInfoKey: Any], json: JSON) {
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.json = json
    }

    func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        try KeyedDecodingContainer(JSONKeyedDecodingContainer<Key>(codingPath: codingPath, json: json))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        try JSONUnkeyedDecodingContainer(codingPath: codingPath, json: json)
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        try JSONSingleValueDecodingContainer(codingPath: codingPath, json: json)
    }
}

private struct JSONKeyedDecodingContainer<Key>: KeyedDecodingContainerProtocol where Key: CodingKey {
    let codingPath: [any CodingKey]
    let json: JSON

    var allKeys: [Key] {
        guard case let .object(object) = json else { return [] }
        return object.keys.compactMap { Key(stringValue: $0) }
    }

    init(codingPath: [any CodingKey], json: JSON) throws {
        guard case .object = json else {
            throw DecodingError.typeMismatch(
                [String: JSON].self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Expected object for keyed container.")
            )
        }
        self.codingPath = codingPath
        self.json = json
    }

    func contains(_ key: Key) -> Bool {
        json.objectValue?[key.stringValue] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        let value = try value(forKey: key, allowNull: true)
        return value.isNull
    }

    func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let nestedJSON = try value(forKey: key)
        guard case .object = nestedJSON else {
            throw DecodingError.typeMismatch(
                JSON.self,
                DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Keyed container value was not an object.")
            )
        }

        return try KeyedDecodingContainer(JSONKeyedDecodingContainer<NestedKey>(codingPath: codingPath + [key], json: nestedJSON))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        let nestedJSON = try value(forKey: key)
        guard case .array = nestedJSON else {
            throw DecodingError.typeMismatch(
                JSON.self,
                DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Unkeyed container value was not an array.")
            )
        }
        return try JSONUnkeyedDecodingContainer(codingPath: codingPath + [key], json: nestedJSON)
    }

    func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
        guard case let .bool(value) = try value(forKey: key) else {
            throw DecodingError.typeMismatch(Bool.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Expected to decode Bool, but found something else instead."))
        }
        return value
    }

    func decode(_: String.Type, forKey key: Key) throws -> String {
        guard case let .string(value) = try value(forKey: key) else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Expected to decode String, but found something else instead."))
        }
        return value
    }

    func decode(_: Double.Type, forKey key: Key) throws -> Double {
        let value = try value(forKey: key)
        if case let .double(d) = value { return d }
        if case let .int(i) = value { return Double(i) }
        throw DecodingError.typeMismatch(Double.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Expected to decode Double/Int, but found something else instead."))
    }

    func decode(_: Float.Type, forKey key: Key) throws -> Float {
        try Float(decode(Double.self, forKey: key))
    }

    func decode(_: Int.Type, forKey key: Key) throws -> Int {
        let value = try value(forKey: key)
        if case let .int(i) = value { return i }
        if case let .double(d) = value, d == d.rounded() { return Int(d) }
        throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Expected to decode Int/Double(whole), but found something else instead."))
    }

    func decode(_: Int8.Type, forKey key: Key) throws -> Int8 { try Int8(decode(Int.self, forKey: key)) }
    func decode(_: Int16.Type, forKey key: Key) throws -> Int16 { try Int16(decode(Int.self, forKey: key)) }
    func decode(_: Int32.Type, forKey key: Key) throws -> Int32 { try Int32(decode(Int.self, forKey: key)) }
    func decode(_: Int64.Type, forKey key: Key) throws -> Int64 { try Int64(decode(Int.self, forKey: key)) }

    func decode(_: UInt.Type, forKey key: Key) throws -> UInt { try UInt(decode(Int.self, forKey: key)) }
    func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 { try UInt8(decode(Int.self, forKey: key)) }
    func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 { try UInt16(decode(Int.self, forKey: key)) }
    func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 { try UInt32(decode(Int.self, forKey: key)) }
    func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 { try UInt64(decode(Int.self, forKey: key)) }

    func decode<T>(_: T.Type, forKey key: Key) throws -> T where T: Decodable {
        let value = try value(forKey: key, allowNull: true)
        let decoder = JSONDecoderImpl(codingPath: codingPath + [key], userInfo: [:], json: value)
        return try T(from: decoder)
    }

    func superDecoder() throws -> any Decoder {
        JSONDecoderImpl(codingPath: codingPath, userInfo: [:], json: json)
    }

    func superDecoder(forKey key: Key) throws -> any Decoder {
        try JSONDecoderImpl(codingPath: codingPath + [key], userInfo: [:], json: value(forKey: key, allowNull: true))
    }

    private func value(forKey key: Key, allowNull: Bool = false) throws -> JSON {
        guard let value = json[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Missing key: \(key.stringValue)"))
        }
        if !allowNull, value.isNull {
            throw DecodingError.valueNotFound(JSON.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Null value for key: \(key.stringValue)"))
        }
        return value
    }
}

private struct JSONUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let codingPath: [any CodingKey]
    private(set) var count: Int?
    var isAtEnd: Bool { currentIndex >= (count ?? 0) }
    private(set) var currentIndex: Int = 0

    private let array: [JSON]

    init(codingPath: [any CodingKey], json: JSON) throws {
        guard case let .array(array) = json else {
            throw DecodingError.typeMismatch(
                JSON.self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Unkeyed container value was not an array.")
            )
        }
        self.codingPath = codingPath
        self.array = array
        count = array.count
    }

    private mutating func pop() throws -> JSON {
        guard currentIndex < (count ?? 0) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Unkeyed container is at end."))
        }
        defer { currentIndex += 1 }
        return array[currentIndex]
    }

    mutating func decodeNil() throws -> Bool {
        let v = try pop()
        return v.isNull
    }

    mutating func decode(_: Bool.Type) throws -> Bool {
        let v = try pop()
        guard case let .bool(b) = v else {
            throw DecodingError.typeMismatch(Bool.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Bool"))
        }
        return b
    }

    mutating func decode(_: String.Type) throws -> String {
        let v = try pop()
        guard case let .string(s) = v else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected String"))
        }
        return s
    }

    mutating func decode(_: Double.Type) throws -> Double {
        let v = try pop()
        if case let .double(d) = v { return d }
        if case let .int(i) = v { return Double(i) }
        throw DecodingError.typeMismatch(Double.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Double/Int"))
    }

    mutating func decode(_: Float.Type) throws -> Float {
        try Float(decode(Double.self))
    }

    mutating func decode(_: Int.Type) throws -> Int {
        let v = try pop()
        if case let .int(i) = v { return i }
        if case let .double(d) = v, d == d.rounded() { return Int(d) }
        throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int/Double(whole)"))
    }

    mutating func decode(_: Int8.Type) throws -> Int8 { try Int8(decode(Int.self)) }
    mutating func decode(_: Int16.Type) throws -> Int16 { try Int16(decode(Int.self)) }
    mutating func decode(_: Int32.Type) throws -> Int32 { try Int32(decode(Int.self)) }
    mutating func decode(_: Int64.Type) throws -> Int64 { try Int64(decode(Int.self)) }

    mutating func decode(_: UInt.Type) throws -> UInt { try UInt(decode(Int.self)) }
    mutating func decode(_: UInt8.Type) throws -> UInt8 { try UInt8(decode(Int.self)) }
    mutating func decode(_: UInt16.Type) throws -> UInt16 { try UInt16(decode(Int.self)) }
    mutating func decode(_: UInt32.Type) throws -> UInt32 { try UInt32(decode(Int.self)) }
    mutating func decode(_: UInt64.Type) throws -> UInt64 { try UInt64(decode(Int.self)) }

    mutating func decode<T>(_: T.Type) throws -> T where T: Decodable {
        let value = try pop()
        let indexKey = JSONIndexCodingKey(intValue: currentIndex - 1)
        let decoder = JSONDecoderImpl(codingPath: codingPath + [indexKey], userInfo: [:], json: value)
        return try T(from: decoder)
    }

    mutating func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let idxKey = JSONIndexCodingKey(intValue: currentIndex)
        let nestedJSON = try pop()
        guard case .object = nestedJSON else {
            throw DecodingError.typeMismatch(JSON.self, DecodingError.Context(codingPath: codingPath + [idxKey], debugDescription: "Expected object for nested keyed container"))
        }
        return try KeyedDecodingContainer(JSONKeyedDecodingContainer<NestedKey>(codingPath: codingPath + [idxKey], json: nestedJSON))
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        let idxKey = JSONIndexCodingKey(intValue: currentIndex)
        let nestedJSON = try pop()
        return try JSONUnkeyedDecodingContainer(codingPath: codingPath + [idxKey], json: nestedJSON)
    }

    mutating func superDecoder() throws -> any Decoder {
        let idxKey = JSONIndexCodingKey(intValue: currentIndex)
        let value = try pop()
        return JSONDecoderImpl(codingPath: codingPath + [idxKey], userInfo: [:], json: value)
    }
}

private struct JSONSingleValueDecodingContainer: SingleValueDecodingContainer {
    let codingPath: [any CodingKey]
    let json: JSON

    init(codingPath: [any CodingKey], json: JSON) throws {
        // Ensure we are not wrapping an array or object in a single-value container
        switch json {
        case .array, .object:
            throw DecodingError.typeMismatch(
                JSON.self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Single value container cannot be created for arrays or objects.")
            )
        default:
            break
        }
        self.codingPath = codingPath
        self.json = json
    }

    func decodeNil() -> Bool {
        json.isNull
    }

    func decode(_: Bool.Type) throws -> Bool {
        guard case let .bool(b) = json else {
            throw DecodingError.typeMismatch(Bool.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Bool"))
        }
        return b
    }

    func decode(_: String.Type) throws -> String {
        guard case let .string(s) = json else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected String"))
        }
        return s
    }

    func decode(_: Double.Type) throws -> Double {
        if case let .double(d) = json { return d }
        if case let .int(i) = json { return Double(i) }
        throw DecodingError.typeMismatch(Double.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Double/Int"))
    }

    func decode(_: Float.Type) throws -> Float {
        try Float(decode(Double.self))
    }

    func decode(_: Int.Type) throws -> Int {
        if case let .int(i) = json { return i }
        if case let .double(d) = json, d == d.rounded() { return Int(d) }
        throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int/Double(whole)"))
    }

    func decode(_: Int8.Type) throws -> Int8 { try Int8(decode(Int.self)) }
    func decode(_: Int16.Type) throws -> Int16 { try Int16(decode(Int.self)) }
    func decode(_: Int32.Type) throws -> Int32 { try Int32(decode(Int.self)) }
    func decode(_: Int64.Type) throws -> Int64 { try Int64(decode(Int.self)) }

    func decode(_: UInt.Type) throws -> UInt { try UInt(decode(Int.self)) }
    func decode(_: UInt8.Type) throws -> UInt8 { try UInt8(decode(Int.self)) }
    func decode(_: UInt16.Type) throws -> UInt16 { try UInt16(decode(Int.self)) }
    func decode(_: UInt32.Type) throws -> UInt32 { try UInt32(decode(Int.self)) }
    func decode(_: UInt64.Type) throws -> UInt64 { try UInt64(decode(Int.self)) }

    func decode<T>(_: T.Type) throws -> T where T: Decodable {
        try T(from: JSONDecoderImpl(codingPath: codingPath, userInfo: [:], json: json))
    }
}

// MARK: - Helpers

private struct JSONIndexCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(intValue: Int) {
        self.intValue = intValue
        stringValue = "Index \(intValue)"
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = Int(stringValue)
    }
}
#endif
