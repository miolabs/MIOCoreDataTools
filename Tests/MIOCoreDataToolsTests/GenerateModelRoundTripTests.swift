//
//  GenerateModelRoundTripTests.swift
//
//  Created by MIO Research Labs on 2026.
//
//  Regression cover for `generate-model`. The rule under test is simple and
//  was silently broken for years: whatever Xcode wrote into the master model,
//  the generated model has to write back with the same attribute names, or
//  Core Data parses the result without complaint and then ignores it.
//

import Foundation
import XCTest
@testable import ModelBuilder

final class GenerateModelRoundTripTests : XCTestCase
{
    private var tmp: URL!

    override func setUpWithError ( ) throws {
        tmp = URL( fileURLWithPath: NSTemporaryDirectory() )
            .appendingPathComponent( "mcdt-roundtrip-\(UUID().uuidString)" )
        try FileManager.default.createDirectory( at: tmp, withIntermediateDirectories: true )
    }

    override func tearDownWithError ( ) throws {
        if let tmp { try? FileManager.default.removeItem( at: tmp ) }
    }

    // MARK: - Fixture

    /// Writes a minimal `.xcdatamodeld` and returns its path. Attribute
    /// spellings here match what Xcode actually produces.
    private func makeModel ( ) throws -> String {
        let bundle  = tmp.appendingPathComponent( "Fixture.xcdatamodeld" )
        let version = bundle.appendingPathComponent( "Fixture.xcdatamodel" )
        try FileManager.default.createDirectory( at: version, withIntermediateDirectories: true )

        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>_XCCurrentVersionName</key>
            <string>Fixture.xcdatamodel</string>
        </dict>
        </plist>
        """.write( to: bundle.appendingPathComponent( ".xccurrentversion" ), atomically: true, encoding: .utf8 )

        try """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="24902" systemVersion="25F84" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
            <entity name="Widget" representedClassName="Widget" syncable="YES">
                <attribute name="identifier" attributeType="UUID" usesScalarValueType="NO"/>
                <attribute name="enabled" attributeType="Boolean" defaultValueString="NO" usesScalarValueType="YES"/>
                <attribute name="quantity" attributeType="Integer 64" defaultValueString="7" usesScalarValueType="YES"/>
                <attribute name="label" optional="YES" attributeType="String" defaultValueString="unnamed"/>
            </entity>
        </model>
        """.write( to: version.appendingPathComponent( "contents" ), atomically: true, encoding: .utf8 )

        return bundle.path
    }

    private func generate ( ) throws -> String {
        let out    = tmp.appendingPathComponent( "Out.xcdatamodeld" )
        let parser = try ModelParser( withFilename: try makeModel(), outputPath: out.path )
        parser.delegate = ModelFileOutputDelegate()
        parser.execute()

        return try String( contentsOf: out.appendingPathComponent( "Fixture.xcdatamodel/contents" ),
                           encoding: .utf8 )
    }

    // MARK: - Tests

    /// The bug: defaults were emitted as `defaultValue`, which is not a key
    /// Core Data knows, so every default was dropped from the generated model.
    /// Dual Link's committed Manager model carries 784 of these.
    func testDefaultsRoundTripUnderApplesAttributeName ( ) throws {
        let xml = try generate()

        XCTAssertTrue( xml.contains( "defaultValueString=\"NO\"" ),      "Boolean default lost" )
        XCTAssertTrue( xml.contains( "defaultValueString=\"7\"" ),       "Integer default lost" )
        XCTAssertTrue( xml.contains( "defaultValueString=\"unnamed\"" ), "String default lost" )
    }

    /// The stricter half: no attribute may be spelled `defaultValue`, since
    /// that is what silently parses and gets ignored.
    func testNoBareDefaultValueAttributeIsEmitted ( ) throws {
        let xml = try generate()

        XCTAssertFalse( xml.contains( " defaultValue=" ),
                        "emitted defaultValue=, which Core Data ignores" )
    }

    /// An attribute with no default must not gain one.
    func testAttributeWithoutDefaultGetsNone ( ) throws {
        let xml = try generate()
        let identifierLine = xml
            .split( separator: "\n" )
            .first { $0.contains( "name=\"identifier\"" ) }

        let line = try XCTUnwrap( identifierLine )
        XCTAssertFalse( line.contains( "defaultValueString" ) )
    }
}
