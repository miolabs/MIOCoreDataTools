import PackagePlugin
import Foundation

@main
struct ModelBuilderPlugin: BuildToolPlugin
{
    /// Entry point for creating build commands for targets in Swift packages.
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command]
    {
        // This plugin only runs for package targets that can have source files.
        guard let sourceFiles = target.sourceModule?.sourceFiles else { return [] }

        // ModelBuilder is built from source for the host, so the plugin works the same on macOS and Linux.
        let generatorTool = try context.tool( named: "ModelBuilder" )

        return try sourceFiles.map(\.path).compactMap {
            try createBuildCommand(for: $0, in: context.pluginWorkDirectory, with: generatorTool.path)
        }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ModelBuilderPlugin: XcodeBuildToolPlugin
{
    // Entry point for creating build commands for targets in Xcode projects.
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command]
    {
        let generatorTool = try context.tool(named: "ModelBuilder")

        return try target.inputFiles.map(\.path).compactMap {
            try createBuildCommand(for: $0, in: context.pluginWorkDirectory, with: generatorTool.path, objc:true )
        }
    }
}

#endif

extension ModelBuilderPlugin
{
    /// Shared function that returns a configured build command if the input files is one that should be processed.
    func createBuildCommand(for inputPath: Path, in outputDirectoryPath: Path, with toolPath: Path, objc:Bool = false ) throws -> Command? {
        guard inputPath.extension == "xcdatamodeld" else { return .none }

        // A build command (unlike a prebuild command) can run a tool built from source, but it has to
        // declare its outputs up front: they are read here from the current model version, mirroring
        // the files ModelClassesOutputDelegate writes.
        let model = try CurrentModelVersion( modelPath: inputPath )
        let customClassesPath = inputPath.removingLastComponent().appending( "Classes" )

        var outputFiles:[Path] = []
        for classname in model.entityClassnames {
            outputFiles.append( outputDirectoryPath.appending( "\(classname)+CoreDataProperties.swift" ) )
            // The generator only writes the class file when the target does not provide its own
            if !FileManager.default.fileExists( atPath: customClassesPath.appending( "\(classname)+CoreDataClass.swift" ).string ) {
                outputFiles.append( outputDirectoryPath.appending( "\(classname)+CoreDataClass.swift" ) )
            }
        }
        if !objc { outputFiles.append( outputDirectoryPath.appending( "_CoreDataClasses.swift" ) ) }

        var arguments:[String] = []
        arguments.append( "generate-classes" )
        arguments.append( "-i" )
        arguments.append( "\(inputPath)" )
        if objc { arguments.append( "--objc" ) }
        arguments.append( "\(outputDirectoryPath)" )

        return .buildCommand(displayName: "Generating model classes from \(inputPath) to \(outputDirectoryPath)",
                             executable: toolPath,
                             arguments: arguments,
                             inputFiles: [ model.versionInfoPath, model.contentsPath ],
                             outputFiles: outputFiles
        )
    }
}

enum ModelBuilderPluginError: Error, CustomStringConvertible
{
    case currentVersionNotFound( String )
    case contentsNotFound( String )

    var description: String {
        switch self {
        case .currentVersionNotFound( let path ): return "Current model version not found in \(path)/.xccurrentversion"
        case .contentsNotFound( let path ): return "Model contents not found at \(path)"
        }
    }
}

/// The current version of an .xcdatamodeld, resolved the same way ModelParser does.
struct CurrentModelVersion
{
    let versionInfoPath:Path
    let contentsPath:Path
    let entityClassnames:[String]

    init( modelPath: Path ) throws {
        versionInfoPath = modelPath.appending( ".xccurrentversion" )
        guard let data = FileManager.default.contents( atPath: versionInfoPath.string ),
              let info = try PropertyListSerialization.propertyList( from: data, format: nil ) as? [String:Any],
              let versionName = info[ "_XCCurrentVersionName" ] as? String else {
            throw ModelBuilderPluginError.currentVersionNotFound( modelPath.string )
        }

        contentsPath = modelPath.appending( versionName, "contents" )
        guard let contents = FileManager.default.contents( atPath: contentsPath.string ).flatMap({ String( data: $0, encoding: .utf8 ) }) else {
            throw ModelBuilderPluginError.contentsNotFound( contentsPath.string )
        }

        entityClassnames = CurrentModelVersion.entityClassnames( in: contents )
    }

    /// The representedClassName of every <entity> element. A plain scan keeps the plugin
    /// independent of XMLParser, which lives in FoundationXML on Linux.
    static func entityClassnames( in contents: String ) -> [String] {
        var classnames:[String] = []
        var rest = contents[...]
        while let start = rest.range( of: "<entity " ) {
            guard let end = rest[ start.upperBound... ].range( of: ">" ) else { break }
            let tag = rest[ start.upperBound..<end.lowerBound ]
            if let classname = attribute( "representedClassName", in: tag ) { classnames.append( classname ) }
            rest = rest[ end.upperBound... ]
        }
        return classnames
    }

    static func attribute( _ name: String, in tag: Substring ) -> String? {
        guard let start = tag.range( of: "\(name)=\"" ),
              let end = tag[ start.upperBound... ].firstIndex( of: "\"" ) else { return nil }
        return String( tag[ start.upperBound..<end ] )
    }
}
