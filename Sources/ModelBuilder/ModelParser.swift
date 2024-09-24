//
//  ModelParser.swift
//  MIOCoreData
//
//  Created by Javier Segura Perez on 31/8/24.
//

import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif


protocol ModelOutputDelegate
{
    func setNamespace      ( parser:ModelParser, namespace:String? )
    func entityDidFound    ( parser:ModelParser, entity:Entity )
    func parserDidEnd      ( parser:ModelParser )
}

enum ModelParserError:Error
{
    case currentVersionNotFound
    case currenctVersionKeyNotFound
    case currentVersionKeyIsNotString
}

class ModelParser :NSObject, XMLParserDelegate
{
    public var modelPath:String
    var modelFilePath:String
    var modelFileContentPath:String
    var modelVersionName:String
    var modelCustomClassesPath:String
    var namespace:String?
    
    var delegate:ModelOutputDelegate? = nil
    
    var current_entity:Entity? = nil
    var current_attribute:Attribute? = nil
    var current_relationship:Relationship? = nil
    var current_user_info:[String:String]? = nil
    
    var last_item:UserInfoProtocol? = nil
    
    init(withFilename filename:String, outputPath:String, namespace:String? = nil) throws
    {
        guard let default_model_data = FileManager.default.contents(atPath: filename + "/.xccurrentversion") else {
            throw ModelParserError.currentVersionNotFound
        }
        
        guard let info = try PropertyListSerialization.propertyList(from: default_model_data, options: .mutableContainersAndLeaves, format: nil) as? [String:Any] else {
            throw ModelParserError.currenctVersionKeyNotFound
        }
        
        guard let contents_file_path = info[ "_XCCurrentVersionName" ] as? String else {
            throw ModelParserError.currentVersionKeyIsNotString
        }
                        
        self.modelFilePath = filename
        self.modelVersionName = contents_file_path
        self.modelFileContentPath = filename + "/" + contents_file_path + "/contents"
        self.modelCustomClassesPath = ( modelFilePath as NSString ).deletingLastPathComponent + "/Classes"
        
        self.modelPath = outputPath
        self.namespace = namespace
    }
    
    func parserDidStartDocument(_ parser: XMLParser) {
        delegate?.setNamespace(parser: self, namespace: namespace)
    }
            
    func execute() {
                
        print("Parsing file: \(modelFileContentPath)")
        print("Custom Class folder: " + self.modelCustomClassesPath )
        
        let parser = XMLParser(contentsOf:URL(fileURLWithPath: modelFileContentPath))
        if (parser != nil) {
            parser!.delegate = self;
            parser!.parse();
        }
        else {
            print("Error creating parser\n")
        }
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        
        if (elementName == "entity") {
            
            let name = attributeDict["name"]!
            let classname = attributeDict["representedClassName"]!
            let parentName = attributeDict["parentEntity"]
            let isAbstract = attributeDict["isAbstract"] ?? "NO"
//            code_generation = attributeDict["codeGenerationType"] == "category"
            
            current_entity = Entity( name: name, classname: classname, parenName: parentName, isAbstract: (isAbstract == "YES") )
            last_item = current_entity
        }
        else if (elementName == "attribute") {
            
            let name = attributeDict["name"]!
            let type = attributeDict["attributeType"]!
            let optional = attributeDict["optional"] ?? "NO"
            let defaultValue = attributeDict["defaultValueString"]
            let usesScalarValueType = attributeDict["usesScalarValueType"] ?? "YES"
            
            current_attribute = Attribute( name: name, type: type, optional: (optional == "YES"), defaultValue: defaultValue, usesScalarValueType: (usesScalarValueType == "YES") )
            last_item = current_attribute
        }
        else if (elementName == "relationship") {
            
            let name = attributeDict["name"]!
            let optional = attributeDict["optional"] ?? "NO"
            let destinationEntityName = attributeDict["destinationEntity"]!
            let toMany = attributeDict["toMany"] ?? "NO"
            let inverseName = attributeDict["inverseName"]
            let inverseEntityName = attributeDict["inverseEntity"]
            let deletionRule = attributeDict["deletionRule"]!
            
            current_relationship = Relationship(name: name, destinationEntityName: destinationEntityName, toMany: toMany, optional: (optional == "YES"), inverseName: inverseName, inverseEntityName: inverseEntityName, deletionRule: deletionRule)
            last_item = current_relationship
        }
        else if elementName == "userInfo" {
            current_user_info = [:]
        }
        else if elementName == "entry" {
            if current_user_info != nil {
                if let key = attributeDict["key"] {
                    current_user_info![key] = attributeDict["value"]
                }
            }
        }
        else if elementName == "fetchIndex" {
//            currentIndex = NSFetchIndexDescription(name: attributeDict[ "name" ]!, elements: [] )
        }
        else if elementName == "fetchIndexElement" {
////            let property = currentEntity!.propertiesByName[ attributeDict["property"]! ]!
////            currentIndex!.elements.append( NSFetchIndexElementDescription(property: property, collationType: attributeDict[ "type" ]?.lowercased() == "rtree" ? .rTree : .binary ) )
//            let prop = attributeDict["property"]
//            if prop != nil {
//                currentIndex!.addIndexElement( propertyName: prop!, collationType: attributeDict[ "type" ]?.lowercased() == "rtree" ? .rTree : .binary )
//            }
//            // TODO: expresionType == "String" ... (para el prduct cost index)
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
    
        if (elementName == "entity") {
//            if code_generation == false { return }
            delegate?.entityDidFound(parser: self, entity: current_entity!)
            current_entity = nil
        }
        else if (elementName == "attribute") {
            current_entity?.attributes.append( current_attribute! )
            current_attribute = nil
            last_item = current_entity
        }
        else if (elementName == "relationship") {
            current_entity?.relationships.append( current_relationship! )
            current_relationship = nil
            last_item = current_entity
        }
        else if elementName == "userInfo" {
            last_item?.userInfo = current_user_info!
            current_user_info = nil
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
    
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
    
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        delegate?.parserDidEnd(parser:self)
    }
}
