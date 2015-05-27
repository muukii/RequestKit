//
//  AutoRetryConfiguration.swift
//  RequestKit
//
//  Created by Muukii on 5/27/15.
//  Copyright (c) 2015 muukii. All rights reserved.
//

import Foundation

public struct AutoRetryConfiguration {
    
    public var breakTime: NSTimeInterval
    public var maxRetryCount: Int
    public var enableBackgroundRetry: Bool
    public var failWhenNotReachable: Bool
    public var failOnErrorHandler: (NSError -> Bool)?
    
    public init(breakTime: NSTimeInterval = 5,
        maxRetryCount: Int = 5,
        enableBackgroundRetry: Bool = true,
        failWhenNotReachable: Bool = false,
        failOnErrorHandler: (NSError -> Bool)? = nil) {
            
            self.breakTime = breakTime
            self.maxRetryCount = maxRetryCount
            self.enableBackgroundRetry = enableBackgroundRetry
            self.failWhenNotReachable = failWhenNotReachable
            self.failOnErrorHandler = failOnErrorHandler
    }
}