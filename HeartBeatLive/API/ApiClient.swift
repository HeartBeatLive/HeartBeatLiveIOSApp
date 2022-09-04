//
//  ApiClient.swift
//  HeartBeatLive
//
//  Created by Nikita Ivchenko on 04.09.2022.
//

import Apollo

class ApiClient {
    static let shared: ApolloClient = {
        guard let url = URL(string: "\(Config.serverScheme)://\(Config.serverHost)/graphql") else {
            fatalError("Failed to build GraphQL URL.")
        }

        return ApolloClient(url: url)
    }()
}
