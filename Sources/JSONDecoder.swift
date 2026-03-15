//
//  JSONDecoder.swift
//  SwifterJSON
//
//  Created by Guy Kogus on 15/10/25.
//

#if canImport(Foundation)
import Foundation

public extension JSONDecoder {
    func decode<T: Decodable>(_: T.Type, from: JSON) throws -> T {
        try T(from: JSONDecoderImpl(
            codingPath: [],
            userInfo: userInfo,
            json: from,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        ))
    }
}

private struct JSONDecoderImpl: Decoder {
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    private let json: JSON

    // Strategies
    let keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy
    let dateDecodingStrategy: JSONDecoder.DateDecodingStrategy
    let dataDecodingStrategy: JSONDecoder.DataDecodingStrategy
    let nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy

    init(
        codingPath: [any CodingKey],
        userInfo: [CodingUserInfoKey: Any],
        json: JSON,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy,
        dataDecodingStrategy: JSONDecoder.DataDecodingStrategy,
        nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy
    ) {
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.json = json
        self.keyDecodingStrategy = keyDecodingStrategy
        self.dateDecodingStrategy = dateDecodingStrategy
        self.dataDecodingStrategy = dataDecodingStrategy
        self.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
    }

    func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
        try KeyedDecodingContainer(JSONKeyedDecodingContainer<Key>(
            codingPath: codingPath,
            json: json,
            userInfo: userInfo,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        ))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        try JSONUnkeyedDecodingContainer(
            codingPath: codingPath,
            json: json,
            userInfo: userInfo,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        )
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        try JSONSingleValueDecodingContainer(
            codingPath: codingPath,
            json: json,
            userInfo: userInfo,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        )
    }
}

private struct JSONKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let codingPath: [any CodingKey]
    let json: JSON
    let userInfo: [CodingUserInfoKey: Any]
    let keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy
    let dateDecodingStrategy: JSONDecoder.DateDecodingStrategy
    let dataDecodingStrategy: JSONDecoder.DataDecodingStrategy
    let nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy

    var allKeys: [Key] {
        guard case let .object(object) = json else { return [] }
        return object.keys.compactMap { jsonKey in
            switch keyDecodingStrategy {
            case .useDefaultKeys:
                return Key(stringValue: jsonKey)
            case .convertFromSnakeCase:
                let camel = JSONKeyMapping.convertFromSnakeCase(jsonKey)
                return Key(stringValue: camel)
            case let .custom(mapper):
                let temp = AnyTempKey(stringValue: jsonKey)
                let mapped = mapper(codingPath + [temp])
                return Key(stringValue: mapped.stringValue)
            @unknown default:
                return Key(stringValue: jsonKey)
            }
        }
    }

    init(
        codingPath: [any CodingKey],
        json: JSON,
        userInfo: [CodingUserInfoKey: Any],
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy,
        dataDecodingStrategy: JSONDecoder.DataDecodingStrategy,
        nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy
    ) throws {
        guard case .object = json else {
            throw DecodingError.typeMismatch(
                [String: JSON].self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Expected object for keyed container.")
            )
        }
        self.codingPath = codingPath
        self.json = json
        self.userInfo = userInfo
        self.keyDecodingStrategy = keyDecodingStrategy
        self.dateDecodingStrategy = dateDecodingStrategy
        self.dataDecodingStrategy = dataDecodingStrategy
        self.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
    }

    func contains(_ key: Key) -> Bool {
        json.objectValue?[actualJSONKey(for: key)] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        let value = try value(forKey: key, allowNull: true)
        return value.isNull
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        let nestedJSON = try value(forKey: key)
        guard case .object = nestedJSON else {
            throw DecodingError.typeMismatch(
                JSON.self,
                DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Keyed container value was not an object.")
            )
        }

        return try KeyedDecodingContainer(JSONKeyedDecodingContainer<NestedKey>(
            codingPath: codingPath + [key],
            json: nestedJSON,
            userInfo: userInfo,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        ))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        let nestedJSON = try value(forKey: key)
        guard case .array = nestedJSON else {
            throw DecodingError.typeMismatch(
                JSON.self,
                DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Unkeyed container value was not an array.")
            )
        }
        return try JSONUnkeyedDecodingContainer(
            codingPath: codingPath + [key],
            json: nestedJSON,
            userInfo: userInfo,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        )
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
        try decodeFloatingForKey(key) as Double
    }

    func decode(_: Float.Type, forKey key: Key) throws -> Float {
        try decodeFloatingForKey(key) as Float
    }

    func decode(_: Int.Type, forKey key: Key) throws -> Int {
        let value = try value(forKey: key)
        if case let .int(i) = value { return i }
        if case let .double(d) = value, d == d.rounded() { return Int(d) }
        throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Expected to decode Int/Double(whole), but found something else instead."))
    }

    func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
        try Int8(decode(Int.self, forKey: key))
    }

    func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
        try Int16(decode(Int.self, forKey: key))
    }

    func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
        try Int32(decode(Int.self, forKey: key))
    }

    func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
        try Int64(decode(Int.self, forKey: key))
    }

    func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
        try UInt(decode(Int.self, forKey: key))
    }

    func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try UInt8(decode(Int.self, forKey: key))
    }

    func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try UInt16(decode(Int.self, forKey: key))
    }

    func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try UInt32(decode(Int.self, forKey: key))
    }

    func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try UInt64(decode(Int.self, forKey: key))
    }

    func decode<T: Decodable>(_: T.Type, forKey key: Key) throws -> T {
        let value = try value(forKey: key, allowNull: true)
        let path = codingPath + [key]
        if T.self == Date.self {
            let date = try decodeDateFromJSON(
                from: value,
                at: path,
                userInfo: userInfo,
                keyDecodingStrategy: keyDecodingStrategy,
                dateDecodingStrategy: dateDecodingStrategy,
                dataDecodingStrategy: dataDecodingStrategy,
                nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
            )
            return date as! T
        }
        if T.self == Data.self {
            let data = try decodeDataFromJSON(
                from: value,
                at: path,
                userInfo: userInfo,
                keyDecodingStrategy: keyDecodingStrategy,
                dateDecodingStrategy: dateDecodingStrategy,
                dataDecodingStrategy: dataDecodingStrategy,
                nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
            )
            return data as! T
        }
        let decoder = JSONDecoderImpl(
            codingPath: path,
            userInfo: userInfo,
            json: value,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        )
        return try T(from: decoder)
    }

    func superDecoder() throws -> any Decoder {
        JSONDecoderImpl(
            codingPath: codingPath,
            userInfo: userInfo,
            json: json,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        )
    }

    func superDecoder(forKey key: Key) throws -> any Decoder {
        try JSONDecoderImpl(
            codingPath: codingPath + [key],
            userInfo: userInfo,
            json: value(forKey: key, allowNull: true),
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        )
    }

    // MARK: - Helpers

    private func actualJSONKey(for key: Key) -> String {
        switch keyDecodingStrategy {
        case .useDefaultKeys:
            return key.stringValue
        case .convertFromSnakeCase:
            return JSONKeyMapping.convertToSnakeCase(key.stringValue)
        case let .custom(mapper):
            guard case let .object(object) = json else {
                return key.stringValue
            }
            for jsonKey in object.keys {
                let temp = AnyTempKey(stringValue: jsonKey)
                let mapped = mapper(codingPath + [temp])
                if mapped.stringValue == key.stringValue {
                    return jsonKey
                }
            }
            return key.stringValue
        @unknown default:
            return key.stringValue
        }
    }

    private func value(forKey key: Key, allowNull: Bool = false) throws -> JSON {
        let lookupKey = actualJSONKey(for: key)
        guard let value = json[lookupKey] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Missing key: \(key.stringValue)"))
        }
        if !allowNull, value.isNull {
            throw DecodingError.valueNotFound(JSON.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Null value for key: \(key.stringValue)"))
        }
        return value
    }

    private func decodeFloatingForKey<T: BinaryFloatingPoint>(_ key: Key) throws -> T {
        try decodeFloatingFromJSON(
            from: value(forKey: key),
            codingPath: codingPath + [key],
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        )
    }
}

private struct JSONUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let codingPath: [any CodingKey]
    private(set) var count: Int?
    var isAtEnd: Bool {
        currentIndex >= (count ?? 0)
    }

    private(set) var currentIndex: Int = 0

    private let array: [JSON]

    // strategies and userInfo
    let userInfo: [CodingUserInfoKey: Any]
    let keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy
    let dateDecodingStrategy: JSONDecoder.DateDecodingStrategy
    let dataDecodingStrategy: JSONDecoder.DataDecodingStrategy
    let nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy

    init(
        codingPath: [any CodingKey],
        json: JSON,
        userInfo: [CodingUserInfoKey: Any],
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy,
        dataDecodingStrategy: JSONDecoder.DataDecodingStrategy,
        nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy
    ) throws {
        guard case let .array(array) = json else {
            throw DecodingError.typeMismatch(
                JSON.self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Unkeyed container value was not an array.")
            )
        }
        self.codingPath = codingPath
        self.array = array
        count = array.count
        self.userInfo = userInfo
        self.keyDecodingStrategy = keyDecodingStrategy
        self.dateDecodingStrategy = dateDecodingStrategy
        self.dataDecodingStrategy = dataDecodingStrategy
        self.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
    }

    private mutating func pop() throws -> JSON {
        guard currentIndex < (count ?? 0) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Unkeyed container is at end."))
        }
        defer { currentIndex += 1 }
        return array[currentIndex]
    }

    mutating func decodeNil() throws -> Bool {
        guard currentIndex < (count ?? 0) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Unkeyed container is at end."))
        }
        if array[currentIndex].isNull {
            currentIndex += 1
            return true
        }
        return false
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
        try decodeFloating() as Double
    }

    mutating func decode(_: Float.Type) throws -> Float {
        try decodeFloating() as Float
    }

    mutating func decode(_: Int.Type) throws -> Int {
        let v = try pop()
        if case let .int(i) = v { return i }
        if case let .double(d) = v, d == d.rounded() { return Int(d) }
        throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int/Double(whole)"))
    }

    mutating func decode(_: Int8.Type) throws -> Int8 {
        try Int8(decode(Int.self))
    }

    mutating func decode(_: Int16.Type) throws -> Int16 {
        try Int16(decode(Int.self))
    }

    mutating func decode(_: Int32.Type) throws -> Int32 {
        try Int32(decode(Int.self))
    }

    mutating func decode(_: Int64.Type) throws -> Int64 {
        try Int64(decode(Int.self))
    }

    mutating func decode(_: UInt.Type) throws -> UInt {
        try UInt(decode(Int.self))
    }

    mutating func decode(_: UInt8.Type) throws -> UInt8 {
        try UInt8(decode(Int.self))
    }

    mutating func decode(_: UInt16.Type) throws -> UInt16 {
        try UInt16(decode(Int.self))
    }

    mutating func decode(_: UInt32.Type) throws -> UInt32 {
        try UInt32(decode(Int.self))
    }

    mutating func decode(_: UInt64.Type) throws -> UInt64 {
        try UInt64(decode(Int.self))
    }

    mutating func decode<T: Decodable>(_: T.Type) throws -> T {
        let value = try pop()
        let indexKey = JSONIndexCodingKey(intValue: currentIndex - 1)
        let path = codingPath + [indexKey]
        if T.self == Date.self {
            let date = try decodeDateFromJSON(
                from: value,
                at: path,
                userInfo: userInfo,
                keyDecodingStrategy: keyDecodingStrategy,
                dateDecodingStrategy: dateDecodingStrategy,
                dataDecodingStrategy: dataDecodingStrategy,
                nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
            )
            return date as! T
        }
        if T.self == Data.self {
            let data = try decodeDataFromJSON(
                from: value,
                at: path,
                userInfo: userInfo,
                keyDecodingStrategy: keyDecodingStrategy,
                dateDecodingStrategy: dateDecodingStrategy,
                dataDecodingStrategy: dataDecodingStrategy,
                nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
            )
            return data as! T
        }
        let decoder = JSONDecoderImpl(
            codingPath: path,
            userInfo: userInfo,
            json: value,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        )
        return try T(from: decoder)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        let idxKey = JSONIndexCodingKey(intValue: currentIndex)
        let nestedJSON = try pop()
        guard case .object = nestedJSON else {
            throw DecodingError.typeMismatch(JSON.self, DecodingError.Context(codingPath: codingPath + [idxKey], debugDescription: "Expected object for nested keyed container"))
        }
        return try KeyedDecodingContainer(JSONKeyedDecodingContainer<NestedKey>(
            codingPath: codingPath + [idxKey],
            json: nestedJSON,
            userInfo: userInfo,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        ))
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        let idxKey = JSONIndexCodingKey(intValue: currentIndex)
        let nestedJSON = try pop()
        return try JSONUnkeyedDecodingContainer(
            codingPath: codingPath + [idxKey],
            json: nestedJSON,
            userInfo: userInfo,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        )
    }

    mutating func superDecoder() throws -> any Decoder {
        let idxKey = JSONIndexCodingKey(intValue: currentIndex)
        let value = try pop()
        return JSONDecoderImpl(
            codingPath: codingPath + [idxKey],
            userInfo: userInfo,
            json: value,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        )
    }

    // MARK: - helpers

    private mutating func decodeFloating<T: BinaryFloatingPoint>() throws -> T {
        let value = try pop()
        let indexKey = JSONIndexCodingKey(intValue: currentIndex - 1)
        return try decodeFloatingFromJSON(
            from: value,
            codingPath: codingPath + [indexKey],
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        )
    }
}

private struct JSONSingleValueDecodingContainer: SingleValueDecodingContainer {
    let codingPath: [any CodingKey]
    let json: JSON

    let userInfo: [CodingUserInfoKey: Any]
    let keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy
    let dateDecodingStrategy: JSONDecoder.DateDecodingStrategy
    let dataDecodingStrategy: JSONDecoder.DataDecodingStrategy
    let nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy

    init(
        codingPath: [any CodingKey],
        json: JSON,
        userInfo: [CodingUserInfoKey: Any],
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy,
        dataDecodingStrategy: JSONDecoder.DataDecodingStrategy,
        nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy
    ) throws {
        self.codingPath = codingPath
        self.json = json
        self.userInfo = userInfo
        self.keyDecodingStrategy = keyDecodingStrategy
        self.dateDecodingStrategy = dateDecodingStrategy
        self.dataDecodingStrategy = dataDecodingStrategy
        self.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
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
        try decodeFloating() as Double
    }

    func decode(_: Float.Type) throws -> Float {
        try decodeFloating() as Float
    }

    func decode(_: Int.Type) throws -> Int {
        if case let .int(i) = json { return i }
        if case let .double(d) = json, d == d.rounded() { return Int(d) }
        throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int/Double(whole)"))
    }

    func decode(_: Int8.Type) throws -> Int8 {
        try Int8(decode(Int.self))
    }

    func decode(_: Int16.Type) throws -> Int16 {
        try Int16(decode(Int.self))
    }

    func decode(_: Int32.Type) throws -> Int32 {
        try Int32(decode(Int.self))
    }

    func decode(_: Int64.Type) throws -> Int64 {
        try Int64(decode(Int.self))
    }

    func decode(_: UInt.Type) throws -> UInt {
        try UInt(decode(Int.self))
    }

    func decode(_: UInt8.Type) throws -> UInt8 {
        try UInt8(decode(Int.self))
    }

    func decode(_: UInt16.Type) throws -> UInt16 {
        try UInt16(decode(Int.self))
    }

    func decode(_: UInt32.Type) throws -> UInt32 {
        try UInt32(decode(Int.self))
    }

    func decode(_: UInt64.Type) throws -> UInt64 {
        try UInt64(decode(Int.self))
    }

    func decode<T: Decodable>(_: T.Type) throws -> T {
        if T.self == Date.self {
            let date = try decodeDateFromJSON(
                from: json,
                at: codingPath,
                userInfo: userInfo,
                keyDecodingStrategy: keyDecodingStrategy,
                dateDecodingStrategy: dateDecodingStrategy,
                dataDecodingStrategy: dataDecodingStrategy,
                nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
            )
            return date as! T
        }
        if T.self == Data.self {
            let data = try decodeDataFromJSON(
                from: json,
                at: codingPath,
                userInfo: userInfo,
                keyDecodingStrategy: keyDecodingStrategy,
                dateDecodingStrategy: dateDecodingStrategy,
                dataDecodingStrategy: dataDecodingStrategy,
                nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
            )
            return data as! T
        }
        return try T(from: JSONDecoderImpl(
            codingPath: codingPath,
            userInfo: userInfo,
            json: json,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        ))
    }

    // MARK: - helpers

    private func decodeFloating<T: BinaryFloatingPoint>() throws -> T {
        try decodeFloatingFromJSON(
            from: json,
            codingPath: codingPath,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        )
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

private struct AnyTempKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        intValue = Int(stringValue)
    }

    init?(intValue: Int) {
        self.intValue = intValue
        stringValue = String(intValue)
    }
}

private func decodeFloatingFromJSON<T: BinaryFloatingPoint>(
    from json: JSON,
    codingPath: [any CodingKey],
    nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy
) throws -> T {
    if case let .double(value) = json { return T(value) }
    if case let .int(value) = json { return T(value) }
    if case let .string(value) = json {
        switch nonConformingFloatDecodingStrategy {
        case let .convertFromString(positiveInfinity, negativeInfinity, nan):
            if value == positiveInfinity { return T.infinity }
            if value == negativeInfinity { return -T.infinity }
            if value == nan { return T.nan }
        case .throw:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "String value '\(value)' does not match non-conforming float symbols."
                )
            )
        @unknown default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Unsupported nonConformingFloatDecodingStrategy."
                )
            )
        }
    }
    throw DecodingError.typeMismatch(
        T.self,
        DecodingError.Context(codingPath: codingPath, debugDescription: "Expected to decode \(T.self)")
    )
}

private func decodeDateFromJSON(
    from json: JSON,
    at path: [any CodingKey],
    userInfo: [CodingUserInfoKey: Any],
    keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
    dateDecodingStrategy: JSONDecoder.DateDecodingStrategy,
    dataDecodingStrategy: JSONDecoder.DataDecodingStrategy,
    nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy
) throws -> Date {
    switch dateDecodingStrategy {
    case .deferredToDate:
        return try Date(from: JSONDecoderImpl(
            codingPath: path,
            userInfo: userInfo,
            json: json,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        ))
    case .secondsSince1970:
        if let value = json.doubleValue { return Date(timeIntervalSince1970: value) }
    case .millisecondsSince1970:
        if let value = json.doubleValue { return Date(timeIntervalSince1970: value / 1000.0) }
    case .iso8601:
        if case let .string(value) = json {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: value) { return date }
        }
    #if !os(Linux) && !os(Android) && !os(WASI)
    case let .formatted(formatter):
        if case let .string(value) = json, let date = formatter.date(from: value) { return date }
    #endif
    case let .custom(block):
        return try block(JSONDecoderImpl(
            codingPath: path,
            userInfo: userInfo,
            json: json,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        ))
    @unknown default:
        break
    }
    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: path, debugDescription: "Invalid date value"))
}

private func decodeDataFromJSON(
    from json: JSON,
    at path: [any CodingKey],
    userInfo: [CodingUserInfoKey: Any],
    keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy,
    dateDecodingStrategy: JSONDecoder.DateDecodingStrategy,
    dataDecodingStrategy: JSONDecoder.DataDecodingStrategy,
    nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy
) throws -> Data {
    switch dataDecodingStrategy {
    case .deferredToData:
        return try Data(from: JSONDecoderImpl(
            codingPath: path,
            userInfo: userInfo,
            json: json,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        ))
    case .base64:
        if case let .string(value) = json, let data = Data(base64Encoded: value) { return data }
    case let .custom(block):
        return try block(JSONDecoderImpl(
            codingPath: path,
            userInfo: userInfo,
            json: json,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy
        ))
    @unknown default:
        break
    }
    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: path, debugDescription: "Invalid data value"))
}

private enum JSONKeyMapping {
    static func convertFromSnakeCase(_ stringKey: String) -> String {
        guard !stringKey.isEmpty else { return stringKey }
        var result = ""
        var capitalizeNext = false
        for ch in stringKey {
            if ch == "_" {
                capitalizeNext = true
                continue
            }
            if capitalizeNext {
                result.append(ch.uppercased())
                capitalizeNext = false
            } else {
                result.append(ch)
            }
        }
        return result
    }

    static func convertToSnakeCase(_ stringKey: String) -> String {
        guard !stringKey.isEmpty else { return stringKey }
        var result = ""
        for ch in stringKey {
            if ch.isUppercase {
                result.append("_")
                result.append(ch.lowercased())
            } else {
                result.append(ch)
            }
        }
        return result
    }
}
#endif
