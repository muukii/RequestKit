//
//  Parameters.swift
//  RequestKit
//
//  Created by Muukii on 5/27/15.
//  Copyright (c) 2015 muukii. All rights reserved.
//

import Foundation

public enum UploadData {
    case Data(data: NSData, fileName: String)
    case Stream(stream: NSInputStream, fileName: String, length: Int64)
    case URL(fileUrl: NSURL)
}

public enum Parameter: StringLiteralConvertible {
    
    public init(stringLiteral value: String) {
        
        self = .Text(value)
    }
    
    public init(unicodeScalarLiteral value: String) {
        
        self = .Text(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        
        self = .Text(value)
    }
    
    case Text(String?)
    case File(UploadData)
}

public struct RequestData {
    
    var rawData = [String : Parameter]()
    
    public subscript(key: String) -> Parameter? {
        get {
            
            return rawData[key]
        }
        set {
            
            rawData[key] = newValue
        }
    }
}