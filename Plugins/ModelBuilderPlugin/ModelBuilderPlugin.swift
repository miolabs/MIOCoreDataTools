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
                
        // Find the code generator tool to run (replace this with the actual one).
        let generatorTool = try context.tool( named: "model-builder" )
        
        // Construct a build command for each source file with a particular suffix.
        return sourceFiles.map(\.path).compactMap {
            createBuildCommand(for: $0, in: context.pluginWorkDirectory, with: generatorTool.path)
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
        // Find the code generator tool to run (replace this with the actual one).
        let generatorTool = try context.tool(named: "model-builder")
                
        // Construct a build command for each source file with a particular suffix.
        return target.inputFiles.map(\.path).compactMap {
            createBuildCommand(for: $0, in: context.pluginWorkDirectory, with: generatorTool.path, configPath: context.xcodeProject.directory, objc:true )
        }
    }
}

#endif

extension ModelBuilderPlugin
{
    /// Shared function that returns a configured build command if the input files is one that should be processed.
    func createBuildCommand(for inputPath: Path, in outputDirectoryPath: Path, with toolPath: Path, configPath: Path? = nil, objc:Bool = false ) -> Command? {
        // Skip any file that doesn't have the extension we're looking for (replace this with the actual one).
                
        guard inputPath.extension == "xcdatamodeld" else { return .none }

        // The generator writes one file per entity of the current model but never removes the
        // files of entities that are gone: with the output directory restored from a build cache
        // (CI) or kept between builds (local), a class deleted from the model kept compiling and
        // clashed with the entity its properties moved to. The prebuild command regenerates every
        // class on every build anyway, so stale outputs are cleared here first.
        removeGeneratedClasses( in: outputDirectoryPath )

        var arguments:[String] = []

        #if os(Linux)
        arguments.append( "-o" )
        arguments.append( "\(outputDirectoryPath)" )
        arguments.append( "\(inputPath)" )
        #else
        arguments.append( "generate-classes" )
        arguments.append( "-i" )
        arguments.append( "\(inputPath)" )
        if objc { arguments.append( "--objc" ) }
        arguments.append( "\(outputDirectoryPath)" )
        #endif
        
        // Return a command that will run during the build to generate the output file.
        return .prebuildCommand(displayName: "Generating model classes from \(inputPath) to \(outputDirectoryPath) with \(toolPath)",
                                executable: toolPath,
                                arguments: arguments,
                                outputFilesDirectory: outputDirectoryPath
        )
    }
}

extension ModelBuilderPlugin
{
    /// Deletes the Swift files a previous run left in the plugin output directory.
    func removeGeneratedClasses ( in outputDirectoryPath: Path ) {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory( atPath: outputDirectoryPath.string ) else { return }
        for name in names where name.hasSuffix( ".swift" ) {
            try? fm.removeItem( atPath: outputDirectoryPath.appending( name ).string )
        }
    }
}
