//
//  MIOCoreDataToolsTests.swift
//  MIOCoreDataToolsTests
//
//  The class generator maps each model attributeType token to the Swift
//  property type Apple's own generator would emit.
//

import Foundation
import XCTest
@testable import ModelBuilder

final class ModelClassesOutputDelegateTests: XCTestCase {

    private func property(type: String, optional: Bool = true, objc: Bool = false) -> String {
        let delegate = ModelClassesOutputDelegate(objcSupport: objc)
        delegate.appendAttribute(Attribute(name: "value", type: type, optional: optional, defaultValue: nil, usesScalarValueType: false))
        return delegate.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testBinaryBecomesData() {
        XCTAssertTrue(property(type: "Binary").hasPrefix("public var value:Data? { get { value(forKey: \"value\") as? Data }"), property(type: "Binary"))
        XCTAssertTrue(property(type: "Binary", optional: false).hasPrefix("public var value:Data { get { value(forKey: \"value\") as! Data }"))
        XCTAssertEqual(property(type: "Binary", objc: true), "@NSManaged public var value:Data?")
    }

    func testURIBecomesURL() {
        XCTAssertTrue(property(type: "URI").hasPrefix("public var value:URL? { get { value(forKey: \"value\") as? URL }"), property(type: "URI"))
        XCTAssertTrue(property(type: "URI", optional: false).hasPrefix("public var value:URL { get { value(forKey: \"value\") as! URL }"))
        XCTAssertEqual(property(type: "URI", objc: true), "@NSManaged public var value:URL?")
    }

    func testStringStillGoesThroughTheDefaultBranch() {
        XCTAssertTrue(property(type: "String").hasPrefix("public var value:String? { get { value(forKey: \"value\") as? String }"))
    }
}
