//
//  GraphQLExtension.swift
//  HeartBeatLive
//
//  Created by Nikita Ivchenko on 05.09.2022.
//

import Foundation
import Apollo

extension GraphQLResult {
    func findErrorWith(path: String) -> GraphQLError? {
        return self.errors?.first(where: { $0.path?.contains(path) ?? false })
    }
}

extension GraphQLError {
    var path: [String]? {
        return self["path"] as? [String]
    }

    var code: String? {
        return (self.extensions?["code"] as? String?) ?? nil
    }
}
