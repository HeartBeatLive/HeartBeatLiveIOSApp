//
//  Config.swift
//  HeartBeatLive
//
//  Created by Nikita Ivchenko on 04.09.2022.
//

import Foundation

enum Config {
    static let serverHost = stringValue(forKey: "SERVER_HOST")
    static let serverScheme = stringValue(forKey: "SERVER_SCHEME")

    private static func stringValue(forKey key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            fatalError("Value for key '\(key)' is not found!")
        }

        return value
    }
}
