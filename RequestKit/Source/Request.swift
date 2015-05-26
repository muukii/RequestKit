//
//  Request.swift
//  Couples
//
//  Created by Muukii on 10/27/14.
//  Copyright (c) 2014 eureka. All rights reserved.
//

import Foundation

public class Request: NSObject {
    
    public enum RequestStatus {
        case Waiting
        case Running
        case Success
        case PendingRetry
        case Failure
    }
    
    public enum SessionType {
        case Default
        case Background
    }
    
    public enum Method: String {
        case GET = "GET"
        case POST = "POST"
    }
    
    public enum UploadData {
        case Data(data: NSData, name: String, fileName: String)
        case Stream(stream: NSInputStream, name: String, fileName: String, length: Int64)
        case URL(fileUrl: NSURL, name: String)
    }
    
    public enum TaskType {
        case Data
        case Upload(uploadData: [UploadData])
    }
    
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
    
    public typealias Parameters = [String : AnyObject?]
    public let EmptyParameter = ""
    
    public struct RequestComponent {
        public var method: Method
        public var path: String
        public var parameters: Parameters?
        public var taskType: TaskType
        
        public var validatedParameters: [String: AnyObject] {
            
            var validatedParameters = [String: AnyObject]()
            if let parameters = self.parameters {
                for key in parameters.keys {
                    
                    if let value: AnyObject? = parameters[key] {
                        if let value: AnyObject = value {
                            
                            validatedParameters[key] = value
                        }
                    }
                }
            }
            return validatedParameters
        }
        
        public init(method: Method, path: String = "", taskType: TaskType = .Data, parameters: Parameters? = nil) {
            self.method = method
            self.path = path
            self.taskType = .Data
            self.parameters = parameters
        }
    }
    
    public typealias Progress = ((progress: Float) -> Void)
    public typealias Success = ((urlResponse: NSHTTPURLResponse?, responseObject: AnyObject?) -> Void)
    public typealias Failure = ((urlResponse: NSHTTPURLResponse?, responseObject: AnyObject?, error: NSError?) -> Void)
    public typealias Completion = (() -> Void)
    
    public required init(component: RequestComponent, autoRetryConfiguration: AutoRetryConfiguration = AutoRetryConfiguration(breakTime: 5)) {
        
        self.component = component
        self.autoRetryConfiguration = autoRetryConfiguration
    }
    
    public convenience init(method: Method, path: String, parameters: Parameters? = nil) {
        
        let component = RequestComponent(method: method, path: path, parameters: parameters)
        self.init(component: component)
    }
    
    public var progressHandler: Progress?
    public var successHandler: Success?
    public var failureHandler: Failure?
    public var completionHandler: Completion?
    
    public var sessionType: SessionType = .Default
    public var component: RequestComponent?
    public var autoRetryConfiguration: AutoRetryConfiguration
    
    public var status: RequestStatus = .Waiting
    public var task: NSURLSessionTask?
    public var retryCount: Int = 0
 
    public var baseURL: NSURL? {

        return nil
    }
    
    public func progress(progress: Progress) -> Self {
        
        self.progressHandler = progress
        return self
    }
    
    public func success(success: Success) -> Self {
        
        self.successHandler = success
        return self
    }
    
    public func failure(failure: Failure) -> Self {
        
        self.failureHandler = failure
        return self
    }
    
    public func completion(completion: Completion) -> Self {
        
        self.completionHandler = completion
        return self
    }
    
    
    public func appendDefaultParameters(parameters : Parameters?) -> Parameters? {
        
        return parameters
    }
    
    /**
    
    
    :param: task
    */
    public func setSessionTask(task: NSURLSessionTask?) {
        
        self.task = task
    }
    
    /**
    
    
    :param: status
    */
    public func updateStatus(status: RequestStatus) {
        
        self.status = status
    }

    /**
    
    
    :param: retryCount
    */
    public func updateRetryCount(retryCount: Int) {
        
        self.retryCount = retryCount
    }
    
}
