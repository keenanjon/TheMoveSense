//
//  SenseiParser.swift
//  MoveSenseiData
//
//  Created by Jon Menna on 11.4.2022.
//

import Foundation

// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//



func load<T: Decodable>(_ filename: String) -> T {
    
    let data: Data
    guard let file = Bundle.main.url(forResource: filename, withExtension: nil)
    else {
        fatalError("Couldn't find \(filename) in main bundle.")
    }

    do {
        data = try Data(contentsOf: file)
    } catch {

        fatalError("Couldn't load \(filename) from main bundle:\n\(error)")
    }

    do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    } catch {
        fatalError("Couldn't parse \(filename) as \(T.self):\n\(error)")
    }
}


// MARK: - MovesenseAcceleration
struct MovesenseAcceleration: Codable {
    let data: [DataElement]

    enum CodingKeys: String, CodingKey {
        case data = "data:"
    }
}

// MARK: - DataElement
struct DataElement: Codable {
    let acc: Acc
}

// MARK: - Acc
struct Acc: Codable {
    let timestamp: Int
    let arrayAcc: [ArrayAcc]

    enum CodingKeys: String, CodingKey {
        case timestamp = "Timestamp"
        case arrayAcc = "ArrayAcc"
    }
}

// MARK: - ArrayAcc
struct ArrayAcc: Codable {
    let x, y, z: Double
}
