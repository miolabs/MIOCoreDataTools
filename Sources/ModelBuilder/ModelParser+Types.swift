//
//  ModelParser+Structs.swift
//  MIOCoreDataTools
//
//  Created by Javier Segura Perez on 11/9/24.
//

protocol UserInfoProtocol {
    var userInfo:[String:String]? { get set }
}

class Entity : UserInfoProtocol
{
    let name: String
    let classname:String
    let parentName:String?
    let isAbstract:Bool
    var attributes:[Attribute] = []
    var relationships:[Relationship] = []
    var userInfo:[String:String]?
    
    var isProtocol:Bool = false
    var isServer:Bool = false
    weak var parent:Entity? = nil
        
    init(name: String, classname: String, parentName: String?, parent: Entity? = nil, isAbstract: Bool) {
        self.name = name
        self.classname = classname
        self.parentName = parentName
        self.parent = parent
        self.isAbstract = isAbstract
    }
}

class Attribute : UserInfoProtocol, Equatable, Hashable
{
    static func == (lhs: Attribute, rhs: Attribute) -> Bool {
        lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        return hasher.combine(name)
    }
    
    let name:String
    let type:String
    let optional:Bool
    let defaultValue:String?
    let usesScalarValueType:Bool
    var userInfo:[String:String]?
    
    init(name: String, type: String, optional: Bool, defaultValue: String?, usesScalarValueType: Bool) {
        self.name = name
        self.type = type
        self.optional = optional
        self.defaultValue = defaultValue
        self.usesScalarValueType = usesScalarValueType
    }
}

class Relationship : UserInfoProtocol, Equatable, Hashable
{
    static func == (lhs: Relationship, rhs: Relationship) -> Bool {
        lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        return hasher.combine(name)
    }

    let name:String
    let destinationEntityName:String
    let toMany:Bool
    let optional:Bool
    let inverseName:String?
    let inverseEntityName:String?
    let deletionRule:String
    var userInfo:[String:String]?

    init(name: String, destinationEntityName: String, toMany: Bool, optional: Bool, inverseName: String?, inverseEntityName: String?, deletionRule: String) {
        self.name = name
        self.destinationEntityName = destinationEntityName
        self.toMany = toMany
        self.optional = optional
        self.inverseName = inverseName
        self.inverseEntityName = inverseEntityName
        self.deletionRule = deletionRule
    }
}
