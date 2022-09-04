//
//  ConfigTest.swift
//  HeartBeatLiveTests
//
//  Created by Nikita Ivchenko on 04.09.2022.
//

import XCTest
@testable import HeartBeatLive

class ConfigTest: XCTestCase {

    func testServerHost() {
        XCTAssertEqual(Config.serverHost, "localhost:8080")
    }

    func testServerScheme() {
        XCTAssertEqual(Config.serverScheme, "http")
    }

}
