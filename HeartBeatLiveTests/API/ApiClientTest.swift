//
//  ApiClientTest.swift
//  HeartBeatLiveTests
//
//  Created by Nikita Ivchenko on 04.09.2022.
//

import XCTest
@testable import HeartBeatLive
@testable import Apollo

class ApiClientTest: XCTestCase {

    func testSharedClient() throws {
        let actualUrl = (ApiClient.shared.networkTransport as? RequestChainNetworkTransport)?.endpointURL
        XCTAssertEqual(actualUrl, URL(string: "http://localhost:8080/graphql"))
    }

}
