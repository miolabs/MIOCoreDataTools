//
//  main.swift
//  MIOCoreData
//
//  Created by Javier Segura Perez on 31/8/24.
//

import Foundation
import ArgumentParser

@main
struct ModelBuilder: ParsableCommand
{
    static var configuration = CommandConfiguration(subcommands: [GenerateClasses.self, GenerateModel.self] )
}

struct Options: ParsableArguments
{
    @Option(name: [.customShort("i"), .customLong("input")], help: "The model file path")
    var modelFile: String
}

extension ModelBuilder
{
    struct GenerateClasses: ParsableCommand
    {
        @Flag(name: .long, help: "Obj-C support")
        var objc: Bool = false

//        @Option( name: [.short, .long], help: "the config file" )
//        var configPath: String?
        
        @OptionGroup var options: Options
        
        @Argument(help: "the output folder")
        var outputFolder: String
        
        mutating func run() throws
        {
//            var enable = true
//                        
//            if let cfg_path = configPath {
//                if let cfg_data = FileManager.default.contents( atPath: cfg_path ) {
//                    if let json = try JSONSerialization.jsonObject(with: cfg_data ) as? [String:Any] {
//                        enable = json[ "Enable" ] as? Bool ?? true
//                    }
//                }
//            }
//
//            print("Option Enable: \(enable)")
//            if enable == false { return }

            let parser = try ModelParser( withFilename: options.modelFile, outputPath: outputFolder )
            parser.delegate = ModelClassesOutputDelegate( objcSupport: objc )
            print( "ModelParser OBJC Support: \(objc)" )
            
            parser.execute()
        }
    }
}


extension ModelBuilder
{
    struct GenerateModel: ParsableCommand
    {
        @OptionGroup var options: Options
        
        @Flag(name: .long, help: "Omit user info")
        var omitUserInfo: Bool = false
        
        @Argument(help: "the output filename")
        var outputFileName: String
        
        mutating func run() throws
        {
            let parser = try ModelParser( withFilename: options.modelFile, outputPath: outputFileName )
            parser.delegate = ModelFileOutputDelegate( omitUserInfo: omitUserInfo )
            parser.execute()
        }
    }
}
