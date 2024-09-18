//
//  JSON.swift
//  PassengerApp
//
//  Created by Guy Kogus on 21/12/2018.
//  Copyright © 2018 Guy Kogus. All rights reserved.
//

/// A JSON object.
public enum JSON: Hashable, Sendable {
    /// A null object.
    case null
    /// A boolean value (true/false).
    case bool(_ value: Bool)
    /// A whole number integer value.
    case int(_ value: Int)
    /// A floating point value.
    case double(_ value: Double)
    /// A string value.
    case string(_ value: String)
    /// An array of JSON objects.
    case array(_ value: [JSON])
    /// A dictionary of string keys to JSON objects.
    case object(_ value: [String: JSON])
}

// MARK: - Initialisers

public extension JSON {
    /// Initialise a boolean value (true/false).
    ///
    /// - Parameter value: `true` or `false`
    init(_ value: Bool) {
        self = .bool(value)
    }

    /// Initialise an integer value.
    ///
    /// - Parameter value: An `Int` value.
    init(_ value: Int) {
        self = .int(value)
    }

    /// Initialise an integer value.
    ///
    /// - Parameter value: Any value representable by `BinaryInteger`.
    init(_ value: some BinaryInteger) {
        self = .int(Int(value))
    }

    /// Initialise a floating point value.
    ///
    /// - Parameter value: A `Double` value.
    init(_ value: Double) {
        self = .double(value)
    }

    /// Initialise a floating point value.
    ///
    /// - Parameter value: Any value representable by `BinaryFloatingPoint`.
    init(_ value: some BinaryFloatingPoint) {
        self = .double(Double(value))
    }

    /// Initialise a string value.
    ///
    /// - Parameter value: A `String` value.
    init(_ value: String) {
        self = .string(value)
    }

    /// Initialise a string value.
    ///
    /// - Parameter value: Any value representable by `StringProtocol`.
    init(_ value: some StringProtocol) {
        self = .string(String(value))
    }

    /// Initialise an array of JSON objects.
    ///
    /// - Parameter value: An `Array` of `JSON` objects.
    init(_ value: [JSON]) {
        self = .array(value)
    }

    /// Initialise an array of JSON objects.
    ///
    /// - Parameter value: A `Sequence` of `JSON` objects.
    init(_ value: some Sequence<JSON>) {
        self = .array([JSON](value))
    }

    /// Initialise a dictionary of string keys to JSON objects.
    ///
    /// - Parameter value: A `Dictionary` of `String` keys to `JSON` objects.
    init(_ value: [String: JSON]) {
        self = .object(value)
    }
}

// MARK: - Helpers

public extension JSON {
    /// Helper function to check if the value is null.
    var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }

    /// Helper function to get the boolean value, if possible.
    var boolValue: Bool? {
        guard case let .bool(value) = self else { return nil }
        return value
    }

    /// Helper function to get the integer value, if possible.
    var intValue: Int? {
        switch self {
        case .null, .bool, .string, .array, .object:
            nil
        case let .int(value):
            value
        case let .double(value):
            (value == value.rounded()) ? Int(value) : nil
        }
    }

    /// Helper function to get the floating point value, if possible.
    var doubleValue: Double? {
        switch self {
        case .null, .bool, .string, .array, .object:
            nil
        case let .int(value):
            Double(value)
        case let .double(value):
            value
        }
    }

    /// Helper function to get the string value, if possible.
    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    /// Helper function to get the array value, if possible.
    var arrayValue: [JSON]? {
        guard case let .array(value) = self else { return nil }
        return value
    }

    /// Helper function to get the object value, if possible.
    var objectValue: [String: JSON]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    /// Helper function to get the number of contained values, if possible.
    var count: Int? {
        switch self {
        case .null, .bool, .int, .double, .string:
            nil
        case let .array(value):
            value.count
        case let .object(value):
            value.count
        }
    }

    /// Helper function to provide access to the values of the array, if possible.
    ///
    /// An index check is performed to avoid out-of-bounds exceptions.
    ///
    /// - Parameter index: The index of the array
    subscript(index: Int) -> JSON? {
        get {
            guard case let .array(value) = self,
                  index < value.count else { return nil }
            return value[index]
        }
        set {
            guard case var .array(value) = self,
                  index < value.count else { return }
            if let newValue {
                value[index] = newValue
            } else {
                value[index] = .null
            }
            self = .array(value)
        }
    }

    /// Helper function to provide access to the values of the dictionary, if possible.
    ///
    /// - Parameter key: The key for retrieving the value from the dictionary.
    subscript(key: String) -> JSON? {
        get {
            objectValue?[key]
        }
        set {
            guard case var .object(value) = self else { return }
            if newValue == nil {
                value[key] = .null
            } else {
                value[key] = newValue
            }
            self = .object(value)
        }
    }
}

// MARK: - Codable

extension JSON: Codable {
    enum CodableError: Error {
        case unknownType
    }

    private enum CodingKeys: CodingKey {
        case string(value: String)
        case int(value: Int)

        var stringValue: String {
            switch self {
            case let .string(value):
                value
            case let .int(value):
                "Index \(value)"
            }
        }

        init?(stringValue: String) {
            self = .string(value: stringValue)
        }

        var intValue: Int? {
            switch self {
            case let .string(value):
                Int(value)
            case let .int(value):
                value
            }
        }

        init?(intValue: Int) {
            self = .int(value: intValue)
        }
    }

    public init(from decoder: any Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            var object = [String: JSON]()
            for key in container.allKeys {
                object[key.stringValue] = try container.decode(JSON.self, forKey: key)
            }
            self = .object(object)
        } else if var arrayContainer = try? decoder.unkeyedContainer() {
            var array = [JSON]()
            array.reserveCapacity(arrayContainer.count ?? 0)
            while !arrayContainer.isAtEnd {
                try array.append(arrayContainer.decode(JSON.self))
            }
            self = .array(array)
        } else {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let string = try? container.decode(String.self) {
                self = .string(string)
            } else if let int = try? container.decode(Int.self) {
                self = .int(int)
            } else if let double = try? container.decode(Double.self) {
                self = .double(double)
            } else if let bool = try? container.decode(Bool.self) {
                self = .bool(bool)
            } else {
                throw CodableError.unknownType
            }
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .bool(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .int(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .double(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .array(value):
            var container = encoder.unkeyedContainer()
            for obj in value {
                try container.encode(obj)
            }
        case let .object(value):
            var container = encoder.container(keyedBy: CodingKeys.self)
            for (key, value) in value {
                try container.encode(value, forKey: JSON.CodingKeys(stringValue: key)!)
            }
        }
    }
}

#if canImport(Foundation)
import Foundation

// MARK: - JSON decoding

public extension JSON {
    enum JSONStringError: Error {
        case nonUtf8Json
    }

    /// Initialise using raw JSON data.
    /// - Parameters:
    ///   - jsonData: The JSON data to decode.
    ///   - decoder: The JSON decoder that will convert the JSON data.
    init(jsonData: Data, decoder: JSONDecoder = JSONDecoder()) throws {
        self = try decoder.decode(JSON.self, from: jsonData)
    }

    /// Initialise using a raw JSON string.
    /// - Parameters:
    ///   - jsonString: The JSON string to decode.
    ///   - decoder: The JSON decoder that will convert the JSON data.
    /// - Throws: `JSONStringError.nonUtf8Json` if the string is not encoded as UTF-8.
    init(jsonString: String, decoder: JSONDecoder = JSONDecoder()) throws {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw JSONStringError.nonUtf8Json
        }
        try self.init(jsonData: jsonData, decoder: decoder)
    }
}

// MARK: - Codable Conversion

// Convert between JSON and Codable types

public extension JSON {
    /// Initialise using an encodable value.
    /// - Parameter value: An object conforming to `Encodable`.
    /// - Parameter encoder: The encoder to use for generating the JSON data.
    init(encodableValue value: some Encodable, encoder: JSONEncoder = JSONEncoder()) throws {
        self = try JSONDecoder().decode(JSON.self, from: encoder.encode(value))
    }

    /// Returns a value of the type you specify, decoded from a JSON object.
    /// - Parameter type: The type of the value to decode from the supplied JSON object.
    /// - Parameter decoder: The JSON decoder that will convert the JSON object.
    func decode<T>(_: T.Type = T.self, decoder: JSONDecoder = JSONDecoder()) throws -> T where T: Decodable {
        try decoder.decode(T.self, from: JSONEncoder().encode(self))
    }
}
#endif

// MARK: - Raw values

// Generally used for compatibility with other libraries.

public extension JSON {
    /// Helper function for getting values as `Any`, if possible.
    ///
    /// Arrays and dictionaries will convert nested values to their `rawValue` equivalents, where possible.
    /// - `null` -> `nil`
    /// - `bool` -> `Bool`
    /// - `integer` -> `Int`
    /// - `double` -> `Double`
    /// - `string` -> `String`
    /// - `array` -> `[Any?]`
    /// - `object` -> `[String: Any?]`
    var rawValue: Any? {
        switch self {
        case .null:
            nil
        case let .bool(value):
            value
        case let .int(value):
            value
        case let .double(value):
            value
        case let .string(value):
            value
        case let .array(value):
            value.map(\.rawValue)
        case let .object(value):
            [String: Any?](uniqueKeysWithValues: value.lazy.map { ($0, $1.rawValue) })
        }
    }

    /// Helper function to get the raw array value, if possible.
    var arrayRawValue: [Any]? {
        rawValue as? [Any]
    }

    /// Helper function to get the raw dictionary value, if possible.
    var dictionaryRawValue: [String: Any]? {
        rawValue as? [String: Any]
    }

    /// Attempt to initialize a `JSON` object from `Any` value.
    ///
    /// Arrays and dictionaries will convert nested values to their `JSON` equivalents, where possible.
    /// - `nil` -> `null`
    /// - `Bool` -> `bool`
    /// - `Int` -> `integer`
    /// - `Double` -> `double`
    /// - `String` -> `string`
    /// - `[Any?]` -> `array`
    /// - `[String: Any?]` -> `object`
    ///
    /// - Parameter rawValue: The value whose type will be checked for creating a `JSON` object.
    init?(rawValue: Any?) {
        switch rawValue {
        case nil:
            self = .null
        case let intValue as Int:
            self = .int(intValue)
        case let doubleValue as Double:
            self = .double(doubleValue)
        case let boolValue as Bool:
            self = .bool(boolValue)
        case let stringValue as String:
            self = .string(stringValue)
        case let arrayValue as [Any]:
            self = .array(arrayValue.compactMap { JSON(rawValue: $0) })
        case let objectValue as [String: Any]:
            self = .object(objectValue.compactMapValues { JSON(rawValue: $0) })
        default:
            return nil
        }
    }
}

// MARK: - CustomStringConvertible

extension JSON: CustomStringConvertible {
    fileprivate static let descriptionSeparator = ", "

    public var description: String {
        switch self {
        case .null:
            "null"
        case let .bool(value):
            value ? "true" : "false"
        case let .string(value):
            "\"\(value)\""
        case let .int(value):
            String(value)
        case let .double(value):
            String(value)
        case let .array(value):
            "[\(value.map(\.description).joined(separator: JSON.descriptionSeparator))]"
        case let .object(value):
            "{\(value.map { "\"\($0)\": \($1.description)" }.joined(separator: JSON.descriptionSeparator))}"
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension JSON: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .null:
            "<NULL>:\(description)"
        case .bool:
            "<BOOL>:\(description)"
        case .string:
            "<STRING>:\(description)"
        case .int:
            "<INT>:\(description)"
        case .double:
            "<DOUBLE>:\(description)"
        case let .array(value):
            "<ARRAY>:[\(value.map(\.debugDescription).joined(separator: JSON.descriptionSeparator))]"
        case let .object(value):
            "<OBJECT>:{\(value.map { "\"\($0)\": \($1.debugDescription)" }.joined(separator: JSON.descriptionSeparator))}"
        }
    }
}

// MARK: - Expressible Literals

extension JSON: ExpressibleByNilLiteral {
    public init(nilLiteral _: ()) {
        self = .null
    }
}

extension JSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSON: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension JSON: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension JSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSON...) {
        self = .array(elements)
    }
}

extension JSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSON)...) {
        self = .object([String: JSON](uniqueKeysWithValues: elements))
    }
}
