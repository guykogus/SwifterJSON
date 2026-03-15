//
//  JSONTests.swift
//  SwifterJSONTests
//
//  Created by Guy Kogus on 22/12/2018.
//  Copyright © 2018 Guy Kogus. All rights reserved.
//

import Foundation
@testable import SwifterJSON
import Testing

struct JSONTests {
    enum Dummy {
        static let null = JSON.null
        static let bool = JSON.bool(false)
        static let int = JSON.int(0)
        static let double = JSON.double(0)
        static let string = JSON.string("")
        static let array = JSON.array([])
        static let object = JSON.object([:])
    }

    enum Example {
        static let array: [JSON] = [1, 1, 2, 3, 5, 8, 13]
        static let object: JSON = [
            "foo": "bar",
            "fib": JSON(array),
            "life": 42,
            "nothing": nil,
            "apple": [
                "address": [
                    "street": "1 Infinite Loop",
                    "city": "Cupertino",
                    "state": "CA",
                    "zip": "95014",
                ],
            ],
        ]
    }

    struct Person: Codable, Equatable {
        let firstName: String
        let lastName: String
        let height: Int
        let dateOfBirth: Date

        static let person = Person(
            firstName: "Guy",
            lastName: "Kogus",
            height: 173,
            dateOfBirth: Date(timeIntervalSince1970: 0)
        )
        static let json = JSON([
            "first_name": "Guy",
            "last_name": "Kogus",
            "height": 173,
            "date_of_birth": "1970-01-01T00:00:00Z",
        ])
    }

    @Test
    func testNull() {
        #expect(!Dummy.bool.isNull)
        #expect(!Dummy.int.isNull)
        #expect(!Dummy.double.isNull)
        #expect(!Dummy.string.isNull)
        #expect(!Dummy.array.isNull)
        #expect(!Dummy.object.isNull)

        #expect(Dummy.null.isNull)
    }

    @Test
    func testBool() {
        #expect(Dummy.null.boolValue == nil)
        #expect(Dummy.int.boolValue == nil)
        #expect(Dummy.double.boolValue == nil)
        #expect(Dummy.string.boolValue == nil)
        #expect(Dummy.array.boolValue == nil)
        #expect(Dummy.object.boolValue == nil)

        #expect(Dummy.bool.boolValue != nil)
        #expect(JSON.bool(false).boolValue == false)
        #expect(JSON.bool(true).boolValue == true)
    }

    @Test
    func testInt() {
        #expect(Dummy.null.intValue == nil)
        #expect(Dummy.bool.intValue == nil)
        #expect(Dummy.string.intValue == nil)
        #expect(Dummy.array.intValue == nil)
        #expect(Dummy.object.intValue == nil)

        #expect(Dummy.double.intValue == 0)
        #expect(JSON.double(Double.leastNormalMagnitude).intValue == nil)
        #expect(JSON.double(Double.leastNonzeroMagnitude).intValue == nil)

        #expect(Dummy.int.intValue == 0)
        let positive: JSON = 123
        #expect(positive.intValue == 123)
        let negative: JSON = -123
        #expect(negative.intValue == -123)
    }

    @Test
    func testDouble() {
        #expect(Dummy.null.doubleValue == nil)
        #expect(Dummy.bool.doubleValue == nil)
        #expect(Dummy.string.doubleValue == nil)
        #expect(Dummy.array.doubleValue == nil)
        #expect(Dummy.object.doubleValue == nil)

        #expect(Dummy.int.doubleValue == 0)
        #expect(Dummy.double.doubleValue == 0)
        let positive: JSON = 123.0
        #expect(positive.doubleValue == 123)
        let negative: JSON = -123.0
        #expect(negative.doubleValue == -123)
    }

    @Test
    func numbers() throws {
        let numbersString = "[-0, 0, 0.0, 0.1]"
        let decoder = JSONDecoder()
        let doublesJSON = try decoder.decode(JSON.self, from: #require(numbersString.data(using: .utf8)))
        #expect(doublesJSON[0]?.intValue == 0)
        #expect(doublesJSON[1]?.intValue == 0)
        #expect(doublesJSON[2]?.intValue == 0)
        #expect(doublesJSON[3]?.intValue == nil)
        #expect(doublesJSON[0]?.doubleValue == 0)
        #expect(doublesJSON[1]?.doubleValue == 0)
        #expect(doublesJSON[2]?.doubleValue == 0)
        #expect(doublesJSON[3]?.doubleValue == 0.1)
    }

    @Test
    func testString() {
        #expect(Dummy.null.stringValue == nil)
        #expect(Dummy.bool.stringValue == nil)
        #expect(Dummy.int.stringValue == nil)
        #expect(Dummy.double.stringValue == nil)
        #expect(Dummy.array.stringValue == nil)
        #expect(Dummy.object.stringValue == nil)

        #expect(Dummy.string.stringValue != nil)
        let string: JSON = "Hello world"
        #expect(string.stringValue == "Hello world")
    }

    @Test
    func testArray() {
        #expect(Dummy.null.arrayValue == nil)
        #expect(Dummy.bool.arrayValue == nil)
        #expect(Dummy.int.arrayValue == nil)
        #expect(Dummy.double.arrayValue == nil)
        #expect(Dummy.string.arrayValue == nil)
        #expect(Dummy.object.arrayValue == nil)

        #expect(Dummy.array.arrayValue == [])

        #expect(Dummy.null[0] == nil)
        #expect(Dummy.bool[0] == nil)
        #expect(Dummy.int[0] == nil)
        #expect(Dummy.double[0] == nil)
        #expect(Dummy.string[0] == nil)
        #expect(Dummy.object[0] == nil)

        let array: JSON = ["foo", "bar", 5, 8.0, [nil]]
        #expect(array.count == 5)
        #expect(array[0]?.stringValue == "foo")
        #expect(array[1]?.stringValue == "bar")
        #expect(array[2]?.intValue == 5)
        #expect(array[3]?.doubleValue == 8.0)
        #expect(array[4]?.count == 1)
        #expect(array[4]?[0]?.isNull == true)
        #expect(array[4]?[1] == nil)
        #expect(array[5] == nil)

        var newArray = array
        newArray[2] = nil
        #expect(newArray[2]?.isNull == true)
        #expect(array[2]?.intValue == 5)
        newArray[3] = 8
        #expect(newArray[3]?.intValue == 8)
    }

    @Test
    func testObject() {
        #expect(Dummy.null.objectValue == nil)
        #expect(Dummy.bool.objectValue == nil)
        #expect(Dummy.int.objectValue == nil)
        #expect(Dummy.double.objectValue == nil)
        #expect(Dummy.string.objectValue == nil)
        #expect(Dummy.array.objectValue == nil)

        #expect(Dummy.object.objectValue == [:])

        #expect(Dummy.null[""] == nil)
        #expect(Dummy.bool[""] == nil)
        #expect(Dummy.int[""] == nil)
        #expect(Dummy.double[""] == nil)
        #expect(Dummy.string[""] == nil)
        #expect(Dummy.array[""] == nil)

        let object: JSON = [
            "foo": "bar",
            "fib": [1, 1, 2, 3, 5, 8, 13],
            "life": 42,
            "nothing": nil,
            "apple": [
                "address": [
                    "street": "1 Infinite Loop",
                    "city": "Cupertino",
                    "state": "CA",
                    "zip": "95014",
                ],
            ],
        ]
        #expect(object.count == 5)
        #expect(object["foo"]?.stringValue == "bar")
        #expect(object["fib"]?[4]?.intValue == 5)
        #expect(object["life"]?.intValue == 42)
        #expect(object["nothing"]?.isNull == true)
        #expect(object["apple"]?["address"]?.count == 4)
        #expect(object["apple"]?["address"]?["city"] == "Cupertino")

        var newObject = object
        newObject["apple"]?["address"] = nil
        #expect(newObject["apple"]?["address"]?["city"] == nil)
        #expect(newObject["apple"]?["address"]?.isNull == true)
        #expect(object["apple"]?["address"]?["city"] == "Cupertino")
        newObject["life"] = "great"
        #expect(newObject["life"]?.stringValue == "great")
    }

    @Test
    func codable() throws {
        // Example taken from https://json.org/example.html
        let stringValue = """
        {"glossary":{"GlossDiv":{"GlossList":{"GlossEntry":{"Abbrev":"ISO 8879:1986","Acronym":"SGML","GlossDef":{"GlossSeeAlso":["GML","XML"],"para":"A meta-markup language, used to create markup languages such as DocBook."},"GlossSee":"markup","GlossTerm":"Standard Generalized Markup Language","ID":"SGML","SortAs":"SGML"}},"title":"S"},"title":"example glossary"}}
        """
        let jsonValue: JSON = [
            "glossary": [
                "GlossDiv": [
                    "GlossList": [
                        "GlossEntry": [
                            "Abbrev": "ISO 8879:1986",
                            "Acronym": "SGML",
                            "GlossDef": [
                                "GlossSeeAlso": [
                                    "GML",
                                    "XML",
                                ],
                                "para": "A meta-markup language, used to create markup languages such as DocBook.",
                            ],
                            "GlossSee": "markup",
                            "GlossTerm": "Standard Generalized Markup Language",
                            "ID": "SGML",
                            "SortAs": "SGML",
                        ],
                    ],
                    "title": "S",
                ],
                "title": "example glossary",
            ],
        ]

        #expect(
            try JSONDecoder().decode(JSON.self, from: #require(stringValue.data(using: .utf8))) == jsonValue
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(jsonValue)
        #expect(try #require(String(data: encoded, encoding: .utf8)) == stringValue)
    }

    @Test
    func helperInitialisers() throws {
        #expect(JSON(true) == true)
        #expect(JSON(Int8(127)) == 127)
        #expect(try abs(#require(JSON(Float(3.141)).doubleValue) - 3.141) <= 0.0001)

        let string = "Hello world"
        #expect(JSON(string[string.startIndex ..< string.endIndex]) == JSON(string))

        #expect(JSON(Example.array.lazy) == JSON(Example.array))
    }

    @Test
    func rawValues() {
        #expect(Example.object["foo"]?.rawValue as? String == "bar")
        #expect(Example.object["fib"]?.rawValue as? [Int] == [1, 1, 2, 3, 5, 8, 13])
        #expect(Example.object["life"]?.rawValue as? Int == 42)
        #expect(Example.object["nothing"]?.rawValue == nil)
        #expect((Example.object.rawValue as? [String: Any?])?.keys.contains("nothing") == true)
        #expect(Example.object["apple"]?["address"]?.rawValue as? [String: String] == [
            "street": "1 Infinite Loop",
            "city": "Cupertino",
            "state": "CA",
            "zip": "95014",
        ])

        #expect(JSON(rawValue: nil) == .null)
        #expect(JSON(rawValue: false) == .bool(false))
        #expect(JSON(rawValue: true) == .bool(true))
        #expect(JSON(rawValue: 0) == .int(0))
        #expect(JSON(rawValue: 1) == .int(1))
        #expect(JSON(rawValue: NSNumber(0)) == .int(0))
        #expect(JSON(rawValue: NSNumber(1)) == .int(1))
        #expect(JSON(rawValue: NSNumber(0.0)) == .int(0))
        #expect(JSON(rawValue: NSNumber(1.0)) == .int(1))
        #expect(JSON(rawValue: NSNumber(0.5)) == .double(0.5))
        #expect(JSON(rawValue: 42) == .int(42))
        #expect(JSON(rawValue: 1.0) == .double(1.0))
        #expect(JSON(rawValue: "foo") == .string("foo"))
        #expect(JSON(rawValue: ["foo"]) == .array(["foo"]))
        #expect(JSON(rawValue: ["foo": "bar"]) == .object(["foo": "bar"]))
        #expect(JSON(rawValue: Date()) == nil)
    }

    #if canImport(Foundation)
    @Test
    func initJsonData() throws {
        let jsonString = "{\"foo\": \"bar\"}"
        let string = try JSON(jsonData: #require(jsonString.data(using: .utf8)))
        #expect(string.rawValue as? [String: String] == ["foo": "bar"])
    }

    @Test
    func initJsonString() throws {
        let jsonString = "{\"foo\": \"bar\"}"
        let string = try JSON(jsonString: jsonString)
        #expect(string.rawValue as? [String: String] == ["foo": "bar"])
    }

    @Test
    func initEncodableValue() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let json = try JSON(encodableValue: Person.person, encoder: encoder)
        #expect(json == Person.json)

        let string = try JSON(encodableValue: JSON("foo"))
        #expect(string == "foo")
    }

    @Test
    func testDecode() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let person = try Person.json.decode(Person.self, decoder: decoder)
        #expect(person == Person.person)

        let string = try JSON("foo").decode() as String
        #expect(string == "foo")
    }
    #endif
}
