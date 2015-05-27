//
//  Request.swift
//  Couples
//
//  Created by Muukii on 10/27/14.
//  Copyright (c) 2014 eureka. All rights reserved.
//

import Foundation

public class Request {
    
    public typealias Progress = ((progress: Float) -> Void)
    public typealias Success = ((urlResponse: NSHTTPURLResponse?, responseObject: AnyObject?) -> Void)
    public typealias Failure = ((urlResponse: NSHTTPURLResponse?, responseObject: AnyObject?, error: NSError?) -> Void)
    public typealias Completion = (() -> Void)
    
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
    
    public enum TaskType {
        case Data
        case Upload(uploadData: [UploadData])
    }
    
    public required init(path: String, requestData: RequestData, method: Method = .POST, autoRetryConfiguration: AutoRetryConfiguration = AutoRetryConfiguration(breakTime: 5)) {
        
        self.autoRetryConfiguration = autoRetryConfiguration
        self.method = method
        self.path = path
        self.taskType = .Data
        self.requestData = requestData
    }
    
    public var method: Method
    public var path: String
    public var requestData: RequestData
    public var taskType: TaskType
    
    public var progressHandler: Progress?
    public var successHandler: Success?
    public var failureHandler: Failure?
    public var completionHandler: Completion?
    
    public var sessionType: SessionType = .Default
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
