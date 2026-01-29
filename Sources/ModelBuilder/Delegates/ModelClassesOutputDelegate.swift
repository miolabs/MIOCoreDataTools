//
//  SwiftModelOutputDelegate.swift
//  MIOCoreData
//
//  Created by Javier Segura Perez on 31/8/24.
//

import Foundation

class ModelClassesOutputDelegate : ModelOutputDelegate
{
    var namespace:String? = nil
    
    var fileContent:String = ""
    var filename:String = ""
    
    var primitiveProperties:[String] = []
    var relationships:[String] = []
    var relationships2:[String] = []
    
    var _model_register_content:String = ""
    
    var entities:[Entity] = []
    var entityByName:[String:Entity] = [:]
    
    let _objc_support:Bool
    init( objcSupport:Bool ) {
        _objc_support = objcSupport
        if !_objc_support {
            _model_register_content += "import Foundation\n"
            _model_register_content += "import MIOCore\n"
            _model_register_content += "func _CORE_DATA_SWIFT_RegisterRuntimeObjects(){\n"
        }
    }
    
    func setNamespace(parser: ModelParser, namespace: String?) {
        self.namespace = namespace
    }
    
    func entityDidFound( parser:ModelParser, entity:Entity ) {
        entities.append( entity )
        entityByName[entity.name] = entity
    }
    
    func appendEntity( parser:ModelParser, entity:Entity )
    {
        self.filename = "/\(entity.classname)+CoreDataProperties.swift"
        
        relationships = []
        primitiveProperties = []
        
        fileContent = "\n"
        fileContent += "// Generated class \(entity.classname) by MIO CORE DATA Model Builder\n"
        fileContent += "import Foundation\n"
        fileContent += "import MIOCoreData\n"
        fileContent += "\n\n"
        fileContent += "extension \(entity.classname)\n{\n\n"
//        if _objc_support { fileContent += "@nonobjc\n"}
//        fileContent += "public class func fetchRequest() -> NSFetchRequest<\(entity.classname)> {\n"
//        fileContent += "  return NSFetchRequest<\(entity.classname)>(entityName: \"\(entity.classname)\") }\n\n"
        
        for attr in entity.attributes { appendAttribute( attr ) }        
        for rel in entity.relationships { appendRelationship( entity: entity, rel ) }
        
        closeModelEntity( entity: entity, parser: parser )
    }
    
    func appendAttribute( _ attribute:Attribute )
    {
        let t:String
        let cast_t:String
        
        let name = attribute.name
        let usesScalarValueType = attribute.usesScalarValueType
        let optional = attribute.optional
        let type = attribute.type
        
        switch type {
        case "Boolean":
            t = usesScalarValueType == false ? "NSNumber?" : "Bool"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Bool"
        
        case "Integer":
            t = usesScalarValueType == false ? "NSNumber?" : "Int"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Int"
                                
        case "Integer 16":
            t = usesScalarValueType == false ? "NSNumber?" : "Int16"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Int16"
            
        case "Integer 8":
            t = usesScalarValueType == false ? "NSNumber?" : "Int8"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Int8"
        
        case "Integer 32":
            t = usesScalarValueType == false ? "NSNumber?" : "Int32"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Int32"
            
        case "Integer 64":
            t = usesScalarValueType == false ? "NSNumber?" : "Int64"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Int64"

        case "Float":
            t = usesScalarValueType == false ? "NSNumber?" : "Float"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Float"

        case "Double":
            t = usesScalarValueType == false ? "NSNumber?" : "Double"
            cast_t = usesScalarValueType == false ? "as? NSNumber" : "as! Double"
            
        case "Decimal":
            t = "NSDecimalNumber?"
            cast_t = "as? NSDecimalNumber"
            
            
        case "Transformable":
            t = optional ? "Any?" : "Any"
            cast_t = optional ? "" : "as! Any"
            
        default:
            t = optional ? "\(type)?" : type
            cast_t = optional ? "as? \(type)" : "as! \(type)"
        }
        
        // check reserved named
        let reserved_names = [ "protocol"]
        let safe_name = reserved_names.contains( name ) ? "`\(name)`" : name
        
        // Setter and Getter of property value
        if _objc_support {
            fileContent += "    @NSManaged public var \(safe_name):\(t)\n"
        } else {
            fileContent += "    public var \(safe_name):\(t) { get { value(forKey: \"\(safe_name)\") \(cast_t) } set { setValue(newValue, forKey: \"\(safe_name)\") } }\n"
            // Setter and Getter of property primitive value (raw)
            let first = String(safe_name.prefix(1))
            let cname = first.uppercased() + String(safe_name.dropFirst())
            primitiveProperties.append("    public var primitive\(cname):\(t) { get { primitiveValue(forKey: \"primitive\(cname)\") \(cast_t) } set { setPrimitiveValue(newValue, forKey: \"primitive\(cname)\") } }\n")
        }
    }
    
    func appendRelationship( entity:Entity, _ relationship: Relationship )
    {
        let name = relationship.name
        let toMany = relationship.toMany
        let optional = relationship.optional
        let destinationEntity = entityByName[relationship.destinationEntityName]?.classname ?? relationship.destinationEntityName
        
        fileContent += "    // Relationship: \(name)\n"
        
        if toMany == false {
            if _objc_support {
                fileContent += "    @NSManaged public var \(name):\(destinationEntity)\(optional ? "?" : "")\n"
            } else {
                fileContent += "    public var \(name):\(destinationEntity)\(optional ? "?" : "") { get { value(forKey: \"\(name)\") as\(optional ? "?" : "!")  \(destinationEntity) } set { setValue(newValue, forKey: \"\(name)\") }}\n"
            }
        }
        else {
            let first = String(name.prefix(1))
            let cname = first.uppercased() + String(name.dropFirst())
            
            if _objc_support {
                fileContent += "    @NSManaged public var \(name):Set<\(destinationEntity)>?\n"
                
                var content = "// MARK: Generated accessors for \(name)\n"
                content += "extension \(entity.classname)\n"
                content += "{\n"
                content += "    @objc(add\(cname)Object:)\n"
                //content += "    @NSManaged public func addTo\(cname)(_ value: \(destinationEntity))\n"
                content += "    @NSManaged public func add\(cname)Object(_ value: \(destinationEntity))\n"
                content += "\n"
                content += "    @objc(remove\(cname)Object:)\n"
                //content += "    @NSManaged public func removeFrom\(cname)(_ value: \(destinationEntity))\n"
                content += "    @NSManaged public func remove\(cname)Object(_ value: \(destinationEntity))\n"
                content += "\n"
                content += "    @objc(add\(cname):)\n"
                //content += "    @NSManaged public func addTo\(cname)(_ values: NSSet)\n"
                content += "    @NSManaged public func add\(cname)(_ values: Set<\(destinationEntity)>)\n"
                content += "\n"
                content += "    @objc(remove\(cname):)\n"
                //content += "    @NSManaged public func removeFrom\(cname)(_ values: NSSet)\n"
                content += "    @NSManaged public func remove\(cname)(_ values: Set<\(destinationEntity)>)\n"
                content += "}\n"
                
                relationships.append(content)

            } else {
                fileContent += "    public var \(name):Set<\(destinationEntity)>? { get { value(forKey: \"\(name)\") as? Set<\(destinationEntity)> } set { setValue(newValue, forKey: \"\(name)\") }}\n"
                
                var content = "// MARK: Generated accessors for \(name)\n"
                content += "extension \(entity.classname)\n"
                content += "{\n"
                content += "    public func add\(cname)Object(_ value: \(destinationEntity)) { _addObject(value, forKey: \"\(name)\") }\n"
                content += "\n"
                content += "    public func remove\(cname)Object(_ value: \(destinationEntity)) { _removeObject(value, forKey: \"\(name)\") }\n"
                content += "\n"
                content += "    public func add\(cname)(_ values: Set<\(destinationEntity)>) { for obj in values { _addObject(obj, forKey: \"\(name)\") } }\n"
                content += "\n"
                content += "    public func remove\(cname)(_ values: Set<\(destinationEntity)>) { for obj in values { _removeObject(obj, forKey: \"\(name)\") } }\n"
                content += "}\n"
                
                relationships.append(content)
            }
            
        }
    }
    
    func closeModelEntity(entity:Entity, parser:ModelParser)
    {
        fileContent += "}\n"
        
        for rel in relationships {
            fileContent += "\n" + rel
        }
                
        if !_objc_support
        {
            fileContent += "\n"
            fileContent += "// MARK: Generated accessors for primitive values\n"
            fileContent += "extension \(entity.classname)\n"
            fileContent += "{\n"
            for primitiveProperty in primitiveProperties {
                fileContent += primitiveProperty
            }
            fileContent += "}\n"
        }
            
        let modelPath = parser.modelPath
        let path = modelPath + filename
        //Write to disc
        WriteTextFile(content:fileContent, path:path)
                
        let check_path = parser.modelCustomClassesPath + "/" + entity.classname + "+CoreDataClass.swift"
        // Create Subclass in case that is not already create
        if ( FileManager.default.fileExists( atPath:check_path ) == false ) {
            var content = ""
            content += "//\n"
            content += "// Generated class \(entity.classname)\n"
            content += "//\n"
            content += "import Foundation\n"
            content += "import MIOCoreData\n"
            content += "\n"
            if _objc_support { content += "@objc(\(entity.classname))\n" }
            let parent = entity.parentName != nil ? entityByName[entity.parentName!]?.classname : nil
            content += "public class \(entity.classname) : \(parent ?? "NSManagedObject")\n"
            content += "{\n"
            content += "\n}\n"
            
            let fp = modelPath + "/" + entity.classname + "+CoreDataClass.swift"
            WriteTextFile(content: content, path: fp)
        }
        
        if !_objc_support {
            _model_register_content += "\n\t_MIOCoreRegisterClass(type: " + entity.classname + ".self, forKey: \"" + entity.classname + "\")"
        }
    }
    
    func parserDidEnd( parser:ModelParser )
    {
        for e in entities {
            appendEntity( parser: parser, entity: e)
        }
        
        if !_objc_support {
            let modelPath = parser.modelPath
            
            _model_register_content += "\n}\n"
            
            let path = modelPath + "/_CoreDataClasses.swift"
            WriteTextFile(content:_model_register_content, path:path)
        }
    }
}
