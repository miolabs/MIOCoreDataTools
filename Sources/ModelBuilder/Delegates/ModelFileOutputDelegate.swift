//
//  AppleModelOutputDelegate.swift
//  MIOCoreDataTools
//
//  Created by Javier Segura Perez on 11/9/24.
//

import Foundation
import DYXML


class ModelFileOutputDelegate : ModelOutputDelegate
{
    var omit_user_info:Bool = false
    var entities_by_name:[String:Entity] = [:]
    
    init( omitUserInfo: Bool = false ) {
        self.omit_user_info = omitUserInfo
    }
    
    func setNamespace(parser: ModelParser, namespace: String?) {
        
    }
    
    func entityDidFound( parser:ModelParser, entity:Entity ) {
        entities_by_name[ entity.name ] = entity
    }
            
    func parserDidEnd( parser: ModelParser ) {
        
        // Let's build the graph
        for (_,e) in entities_by_name {
            if ( e.userInfo?[ "DBProtocol"] ?? "false" ) == "true" { e.isProtocol = true }
            if ( e.userInfo?[ "DBSyncType"] ?? "manager" ) == "server" { e.isServer = true }
            if e.parenName == nil { continue }
            e.parent = entities_by_name[ e.parenName! ]
        }
        
        // Remove parent protocol and add all attributes and relationsips
        var entities:[Entity] = []
        
        let sorted_entities = entities_by_name.sorted { $0.key < $1.key }
        for (_,e) in sorted_entities {
            if e.isProtocol || e.isServer { continue }
            _ = e.protocolProperties()
            
            var rels_to_delete:[Relationship] = []
            for r in e.relationships {
                let rel_e = entities_by_name[ r.destinationEntityName ]!
                if rel_e.isProtocol || rel_e.isServer {
                    rels_to_delete.append( r )
                }
                
                if r.inverseEntityName != nil {
                    if let inverse = entities_by_name[ r.inverseEntityName! ] {
                        if inverse.isProtocol || inverse.isServer {
                            rels_to_delete.append( r )
                        }
                    }
                }
            }
            e.relationships.removeAll( where: { rels_to_delete.contains($0) } )
            entities.append( e )
        }
        
        generateXML( parser: parser, entities: entities )
    }
    
    func generateXML( parser: ModelParser, entities: [Entity] ) {
        
        let xml = document {
            node( "model", attributes: [ ("type", "com.apple.IDECoreDataModeler.DataModel"),
                                         ("documentVersion", "1.0"),
                                         ("lastSavedToolsVersion", "23231"),
                                         ("systemVersion","24A335"),
                                         ("minimumToolsVersion","Automatic"),
                                         ("sourceLanguage","Swift"),
                                         ("userDefinedModelVersionIdentifier","") ] ) {
                for e in entities {
                    node( "entity", attributes: e.xmlAttributes() ){
                        for a in e.attributes {
                            node ("attribute", attributes: a.xmlAttributes() ) {
                                if omit_user_info == true, let ui = a.userInfo {
                                    node( "userInfo" ) {
                                        for (k,v) in ui {
                                            node( "entry", attributes: [ ("key", k), ("value", v) ]) {}
                                        }
                                    }
                                }
                            }
                        }
                        for r in e.relationships {
                            node( "relationship", attributes: r.xmlAttributes( entitiesByName: entities_by_name) ) {
                                if omit_user_info == true, let ui = r.userInfo {
                                    node( "userInfo" ) {
                                        for (k,v) in ui {
                                            node( "entry", attributes: [ ("key", k), ("value", v) ]) {}
                                        }
                                    }
                                }
                            }
                        }
                        if omit_user_info == true, let ui = e.userInfo {
                            node( "userInfo" ) {
                                for (k,v) in ui {
                                    node( "entry", attributes: [ ("key", k), ("value", v) ]) {}
                                }
                            }
                        }
                    }
                }
            }
        }
        
        let content = xml.toString(withIndentation: 4).data(using: .utf8)
        do {
            let folder = parser.modelPath + "/" + parser.modelVersionName
            let path = folder + "/contents"
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem( atPath: path )
            } else {
                try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            }
            
            let url:URL
            if #available(macOS 13.0, *) {
                url = URL( filePath: path, directoryHint: .notDirectory )
            } else {
                // Fallback on earlier versions
                url = URL(fileURLWithPath: path)
            }
            try content?.write( to: url )
        
        } catch {
            print("\(error)")
        }
    }
            
}

extension Entity
{
    func protocolProperties() -> ( Bool, [Attribute], [Relationship] ){
        
        if parent == nil { return (isProtocol, isProtocol ? attributes : [], isProtocol ? relationships :[]) }
        
        let ( parent_is_protocol, attrs, rels ) = parent!.protocolProperties()
                        
        if isProtocol == true {
            let all_attributes = Set(attributes).union( Set(attrs) )
            let all_relations = Set(relationships).union( Set(rels) )
            return ( isProtocol, Array(all_attributes), Array(all_relations) )
        }
        else if parent_is_protocol == true {
            parent = nil
            attributes.append( contentsOf: attrs )
            relationships.append( contentsOf: rels )
        }
        
        return (isProtocol, [], [])
    }

    func xmlAttributes() -> [(String, String)]
    {
        var attrs = [ ("name",name),
                      ("representedClassName", classname),
                      ("syncable","YES" ) ]
        if parent != nil { attrs.append( ("parentEntity", parent!.name ) ) }
        if isAbstract { attrs.append( ("abstract","YES" ) ) }
        return attrs
    }
}

extension Attribute
{
    func xmlAttributes() -> [(String, String)] {
        var attrs = [ ("name", name),
                      ("optional", optional ? "YES" : "NO"),
                      ("attributeType",type ),
                      ("usesScalarValueType", usesScalarValueType ? "YES" : "NO" ) ]
        
        if let defaultValue {
            let v = defaultValue.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            attrs.append( ( "defaultValue", v ) )
        }
        return attrs
    }
}

extension Relationship
{
    func xmlAttributes( entitiesByName: [String:Entity]) -> [(String, String)] {
        var attrs = [ ("name", name),
                      ("destinationEntity", destinationEntityName),
                      ("optional", optional ? "YES" : "NO"),
                      ("deletionRule", deletionRule) ]

        if toMany {
            attrs.append( ("isToMany", "YES" ) )
        }
        else {
            attrs.append( ("maxCount", "1" ) )
        }
        
        if let inv_ent_name = inverseEntityName {
            if let inv_ent = entitiesByName[inv_ent_name] {
                if inv_ent.isProtocol == false {
                    attrs.append( ("inverseEntity", inverseEntityName! ) )
                    attrs.append( ("inverseName", inverseName! ) )
                }
            }
        }
        
        return attrs
    }
}
