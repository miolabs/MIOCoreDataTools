//
//  MIOCoreDataToolsTests.swift
//  
//
//  Created by Javier Segura Perez on 28/1/24.
//
import Foundation
import XCTest

final class MIOCoreDataToolTests: XCTestCase {
    
    func testHelp() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["log", "--pretty=format:- %an <%ae>%n"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        
        XCTAssertEqual("", "Hello, World!")
    }
}
