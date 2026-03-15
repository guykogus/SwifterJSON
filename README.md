# SwifterJSON

[![CI](https://github.com/guykogus/SwifterJSON/actions/workflows/platform-tests.yml/badge.svg)](https://github.com/guykogus/SwifterJSON/actions/workflows/platform-tests.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fguykogus%2FSwifterJSON%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/guykogus/SwifterJSON)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fguykogus%2FSwifterJSON%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/guykogus/SwifterJSON)
[![SPM Compatible](https://img.shields.io/badge/SPM-Compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**JSON in Swift — the way it should be.**

SwifterJSON is a lightweight, type-safe Swift `enum` for working with JSON data that doesn't map to a fixed `Codable` model. It leverages Swift's `Codable` infrastructure, so you can decode arbitrary JSON into a strongly-typed `JSON` value and traverse or mutate it with clean subscript syntax — no casting required.

## Features

- **Type-safe enum** — every JSON value is represented as a `JSON` case (`null`, `bool`, `int`, `double`, `string`, `array`, `object`)
- **Codable** — decode from `Data`/`String` via standard `JSONDecoder`; encode back via `JSONEncoder`
- **Subscript access** — chain `[key]` and `[index]` subscripts to drill into nested structures
- **Mutable** — modify deeply nested values in-place with subscript assignment
- **Literal expressible** — create `JSON` values directly from Swift literals (strings, numbers, arrays, dictionaries, `nil`)
- **Codable interop** — convert between `JSON` and any `Codable` type without round-tripping through `Data`
- **Raw value bridging** — convert to/from `Any` for interop with APIs that use untyped dictionaries
- **Sendable & Hashable** — safe for concurrent use and usable as dictionary keys
- **Cross-platform** — iOS, macOS, tvOS, watchOS, visionOS, Linux, and Android

## Requirements

| Dependency | Minimum |
|---|---|
| Swift | 6.0+ |
| iOS | 15.0+ |
| macOS | 11.0+ |
| tvOS | 15.0+ |
| watchOS | 8.0+ |
| visionOS | 1.0+ |
| Linux | Swift 6.0 toolchain |
| Android | Swift 6.0 toolchain |

## Installation

### Swift Package Manager

Add SwifterJSON as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/guykogus/SwifterJSON.git", from: "4.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SwifterJSON"]
)
```

Or in Xcode: **File > Add Package Dependencies…** and enter `https://github.com/guykogus/SwifterJSON.git`.

## Usage

### The problem

In the modern era of `Codable` it is rare that we need to handle JSON data manually. But sometimes the structure isn't known in advance — server-driven UI, feature flags, analytics payloads, etc.

Given this JSON:

```json
{
  "Apple": {
    "address": {
      "street": "1 Infinite Loop",
      "city": "Cupertino",
      "state": "CA",
      "zip": "95014"
    },
    "employees": 132000
  }
}
```

With `JSONSerialization` you'd have to cast at every level:

```swift
guard let companies = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

if let company = companies["Apple"] as? [String: Any],
   let address = company["address"] as? [String: Any],
   let city = address["city"] as? String {
    print("Apple is in \(city)")
}
```

Mutations are even worse — you need mutable copies at each nesting level:

```swift
guard var companies = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

if var apple = companies["Apple"] as? [String: Any],
   var address = apple["address"] as? [String: Any] {
    address["state"] = "California"
    apple["address"] = address
    companies["Apple"] = apple
}
```

### With SwifterJSON

Reading nested values is a single chained expression:

```swift
let companies = try JSONDecoder().decode(JSON.self, from: data)

if let city = companies["Apple"]?["address"]?["city"]?.stringValue {
    print("Apple is in \(city)")
}
```

Mutations work in-place — no intermediate copies:

```swift
var companies = try JSONDecoder().decode(JSON.self, from: data)

companies["Apple"]?["address"]?["state"] = "California"
```

### Constructing JSON from literals

`JSON` conforms to all the `ExpressibleBy…Literal` protocols, so you can write JSON values naturally:

```swift
let config: JSON = [
    "feature_flags": [
        "dark_mode": true,
        "max_retries": 3,
        "api_url": "https://api.example.com"
    ],
    "version": 2.1
]
```

### Converting between JSON and Codable types

Encode any `Encodable` value into `JSON` without going through `Data`:

```swift
struct User: Codable {
    let name: String
    let age: Int
}

let user = User(name: "Alice", age: 30)
let json = try JSON(encodableValue: user)
// json == ["name": "Alice", "age": 30]
```

Decode `JSON` back into a typed model:

```swift
let decoded: User = try json.decode()
```

### Accessing values

Each JSON type has a corresponding accessor that returns an optional:

```swift
json.boolValue    // Bool?
json.intValue     // Int?
json.doubleValue  // Double?
json.stringValue  // String?
json.arrayValue   // [JSON]?
json.objectValue  // [String: JSON]?
json.isNull       // Bool
json.count        // Int? (for arrays and objects)
```

### Array subscripting

```swift
let fibonacci: JSON = [1, 1, 2, 3, 5, 8, 13]
fibonacci[4]?.intValue // 5
```

### Raw value interop

Bridge to/from `Any` for APIs that use untyped dictionaries:

```swift
let raw: Any? = json.rawValue
let roundTripped = JSON(rawValue: raw)
```

## License

SwifterJSON is available under the MIT license. See the [LICENSE](LICENSE) file for details.
