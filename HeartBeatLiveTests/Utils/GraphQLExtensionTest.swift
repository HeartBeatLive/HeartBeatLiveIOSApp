//
//  GraphQLExtensionTest.swift
//  HeartBeatLiveTests
//
//  Created by Nikita Ivchenko on 06.09.2022.
//

import XCTest
import Apollo
@testable import HeartBeatLive

class GraphQLExtensionTest: XCTestCase {

    func testFindGraphQLErrorWithPath() throws {
        let error1Code = "error1Code"
        let error2Code = "error2Code"

        let result = GraphQLResult<Any>(
            data: nil,
            extensions: [:],
            errors: [
                GraphQLError(try JSONObject(jsonValue: [
                    "path": ["path1", "path2"],
                    "extensions": [
                        "code": error1Code
                    ]
                ])),

                GraphQLError(try JSONObject(jsonValue: [
                    "path": ["path3"],
                    "extensions": [
                        "code": error2Code
                    ]
                ]))
            ],
            source: .server,
            dependentKeys: nil
        )

        XCTAssertEqual(result.findErrorWith(path: "path1")?.code, error1Code)
        XCTAssertEqual(result.findErrorWith(path: "path3")?.code, error2Code)
        XCTAssertNil(result.findErrorWith(path: "path9"))
    }

    func testGraphQLErrorPathProperty() throws {
        let error = GraphQLError(try JSONObject(jsonValue: [
            "path": ["path1", "path2"]
        ]))

        XCTAssertEqual(error.path, ["path1", "path2"])
    }

    func testGraphQLErrorCodeProperty() throws {
        let error = GraphQLError(try JSONObject(jsonValue: [
            "extensions": [
                "code": "sampleErrorCode"
            ]
        ]))

        XCTAssertEqual(error.code, "sampleErrorCode")
    }

}
