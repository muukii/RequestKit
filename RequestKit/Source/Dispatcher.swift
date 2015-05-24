//
//  Request.swift
//  couples
//
//  Created by Muukii on 10/26/14.
//  Copyright (c) 2014 eureka. All rights reserved.
//

import Foundation
import AFNetworking

let sessionIdentifier = "me.muukii.requestKit.background_session"

public class Dispatcher: NSObject {
    private func RKLog<T>(value: T) {
        #if DEBUG
            println(value)
            #else
        #endif
    }
    
    public enum NetworkStatus: Int {
        case Unknown      = -1
        case NotReachable = 0
        case ViaWWAN      = 1
        case ViaWiFi      = 2
    }
    
    var defaultSessionManager: AFHTTPSessionManager?
    var backgroundSessionManager: AFHTTPSessionManager?
    var reachabilityManager: AFNetworkReachabilityManager?
    
    public private(set) var networkStatus: NetworkStatus = .Unknown
    public private(set) var runningRequests: NSMutableSet = NSMutableSet()

    var backgroundURLSessionCompletion: (() -> ())?

    public override init() {
        super.init()
        
        var backgroundTask = UIBackgroundTaskInvalid
        backgroundTask = UIApplication.sharedApplication().beginBackgroundTaskWithName("me.muukii.requestKit.background_task", expirationHandler: { () -> Void in
            
            UIApplication.sharedApplication().endBackgroundTask(backgroundTask)
            backgroundTask = UIBackgroundTaskInvalid
        })
        
        self.reachabilityManager = AFNetworkReachabilityManager.sharedManager()
        self.reachabilityManager?.startMonitoring()
        self.reachabilityManager?.setReachabilityStatusChangeBlock({ (status: AFNetworkReachabilityStatus) -> Void in
            self.networkStatus = NetworkStatus(rawValue: status.rawValue) ?? .Unknown
            self.changedReachabilityStatus(NetworkStatus(rawValue: status.rawValue) ?? .Unknown)
        })

        let defaultSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        self.defaultSessionManager = AFHTTPSessionManager(sessionConfiguration: defaultSessionConfiguration)
        self.defaultSessionManager?.requestSerializer = AFHTTPRequestSerializer()

        var backgroundSessionConfiguration: NSURLSessionConfiguration!
        if NSURLSessionConfiguration.respondsToSelector("backgroundSessionConfigurationWithIdentifier:") {
            backgroundSessionConfiguration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(sessionIdentifier)
        } else {
            backgroundSessionConfiguration = NSURLSessionConfiguration.backgroundSessionConfiguration(sessionIdentifier)
        }
        self.backgroundSessionManager = AFHTTPSessionManager(sessionConfiguration: backgroundSessionConfiguration)

        self.backgroundSessionManager?.setDownloadTaskDidFinishDownloadingBlock({ (session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, url: NSURL!) -> NSURL! in

            return url
        })
        self.backgroundSessionManager?.setDidFinishEventsForBackgroundURLSessionBlock({ [unowned self] (session: NSURLSession!) -> Void in

            session.configuration.identifier
            if let completion = self.backgroundURLSessionCompletion {

                completion()
                self.backgroundURLSessionCompletion = nil
            }

        })
        self.backgroundSessionManager?.setTaskDidReceiveAuthenticationChallengeBlock({ (session: NSURLSession!, task: NSURLSessionTask!, challenge: NSURLAuthenticationChallenge!, credential: AutoreleasingUnsafeMutablePointer<NSURLCredential?>) -> NSURLSessionAuthChallengeDisposition in

            return .PerformDefaultHandling
        })
    }

    deinit {
        
        self.reachabilityManager?.stopMonitoring()
    }

    func handleEventsForBackgroundURLSession(identifier: String!, completionHandler: () -> ()) {
        assert(identifier == sessionIdentifier, "Unknown session identifier.")
        self.backgroundURLSessionCompletion = completionHandler
    }

    public func changedReachabilityStatus(status: NetworkStatus) {
        switch status {
        case .Unknown:
            RKLog("Network status changed: Unknown")
        case .NotReachable:
            RKLog("Network status changed: Not Reachable")
        case .ViaWWAN:
            RKLog("Network status changed: WWAN")
            fallthrough
        case .ViaWiFi:
            RKLog("Network status changed: WiFi")
            self.retryRequests()
        }
    }

    /**
    Connection: Success

    :param: urlResponse
    :param: object
    :param: error
    :param: request
    */
    public func centralProcessSuccess<T: Request>(
        urlResponse: NSHTTPURLResponse?,
        object: NSObject?,
        error: NSError?,
        request: T) {

            self.runningRequests.removeObject(request)
            request.updateStatus(.Success)
    }

    /**
    Connection: Failure

    :param: urlResponse
    :param: object
    :param: error
    :param: request
    */
    public func centralProcessFailure<T: Request>(
        urlResponse: NSHTTPURLResponse?,
        object: NSObject?,
        error: NSError?,
        request: T) {

            self.runningRequests.removeObject(request)
            request.updateStatus(.Failure)

            #if DEBUG
                if let urlResponse = urlResponse {
                
                JELogAlert("Response code \(urlResponse.statusCode) from \"\(urlResponse.URL!.absoluteString!)\"")
                
                }
            #endif
            
            if let error = error where request.autoRetryConfiguration.failOnErrorHandler?(error) == true {
                
                request.failureHandler?(urlResponse: urlResponse, responseObject: object, error: error)
                return
            }
            
            if request.retryCount > request.autoRetryConfiguration.maxRetryCount
                || (error != nil && error!.domain == NSURLErrorDomain && error!.code == NSURLErrorCancelled) {
                    
                    request.failureHandler?(urlResponse: urlResponse, responseObject: object, error: error)
                    return
            }
                
            if UIApplication.sharedApplication().applicationState == UIApplicationState.Background &&
                request.autoRetryConfiguration.enableBackgroundRetry == false {
                    
                    request.failureHandler?(urlResponse: urlResponse, responseObject: object, error: error)
                    return
            }
            
            let delay = request.autoRetryConfiguration.breakTime
            let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
            dispatch_after(time, dispatch_get_main_queue()) { () -> Void in
                self.retryRequest(request)
            }
    }
    
    /**
    Connection: Completion
    
    :param: urlResponse
    :param: object
    :param: error
    :param: request
    */
    public func centralProcessCompletion<T: Request>(#request: T) {
            
            request.completionHandler?()
    }
    
    public func invalidateAllRunningRequests() {

        for request in self.runningRequests {
            let request: Request = request as! Request
            request.updateRetryCount(request.autoRetryConfiguration.maxRetryCount)
            request.updateStatus(.Failure)
            // TODO : NSError for invalidate.
            request.failureHandler?(urlResponse: nil, responseObject: nil, error: nil)
        }
        self.runningRequests.removeAllObjects()
    }

    /**
    Dispatch Request

    :param: request
    */
    public func dispatch<T: Request>(request: T) {

        if request.autoRetryConfiguration.failWhenNotReachable == true && self.networkStatus == .NotReachable {
            
            // NotReachableのNSErrorを作る
            request.failureHandler?(urlResponse: nil, responseObject: nil, error: nil)
            self.centralProcessCompletion(request: request)
            return
        }
        
        self.runningRequests.addObject((request))
        request.updateStatus(.Running)
        if let component = request.component {
            
            request.component?.parameters = request.appendDefaultParameters(component.parameters)
            let sessionManager: AFHTTPSessionManager?
            
            switch request.sessionType {
                
            case .Default:
                
                sessionManager = self.defaultSessionManager
                
            case .Background:
                
                let application = UIApplication.sharedApplication()
                var taskID = UIBackgroundTaskInvalid
                taskID = application.beginBackgroundTaskWithExpirationHandler {

                    application.endBackgroundTask(taskID)
                    taskID = UIBackgroundTaskInvalid
                }
                sessionManager = self.backgroundSessionManager
            }
            
            if let sessionManager = sessionManager {
                
                switch component.taskType {
                    
                case .Data:
                    
                    self.dispatchForDataTask(request: request, sessionManager: sessionManager)
                    
                case .Upload(let data):
                    
                    self.dispatchForUploadTask(request: request, uploadData: data, sessionManager: sessionManager)
                    
                }
            }
        } else {

            request.updateStatus(.Failure)
            assert(false, "Component is nil")
        }
    }

    private func absoluteUrlString(request: Request) -> String {
        
        let baseUrlString = request.baseURL?.absoluteString
        let urlString = baseUrlString?.stringByAppendingPathComponent(request.component?.path ?? "")
        return urlString ?? ""
    }

    public func dispathForDownloadTask(
        #fileName: String,
        downloadUrl: NSURL,
        downloadDestination: NSURL,
        progress: ((progress: Float) -> Void)?,
        success: ((fileUrl: NSURL, response: NSHTTPURLResponse?) -> Void)?,
        failure: ((error: NSError?) -> Void)?) {
            
            var error: NSError?
            let urlRequest = AFHTTPRequestSerializer().requestWithMethod (
                "GET",
                URLString: downloadUrl.absoluteString,
                parameters: nil,
                error: &error)
            var task: NSURLSessionTask?
            task = self.defaultSessionManager?.downloadTaskWithRequest(urlRequest, progress: nil, destination: { (url, response) -> NSURL! in
                return downloadDestination.URLByAppendingPathComponent(fileName)
                }, completionHandler: { (response, url, error) -> Void in
                    if let task = task {
                        self.downloadTaskProgressDictionary.removeValueForKey("\(task.taskIdentifier)")
                    }

                    if error == nil {
                        success?(fileUrl: url, response: response as! NSHTTPURLResponse?)
                    } else {
                        failure?(error:error)
                    }
            })

            if let progress = progress {
                if let task = task {
                    self.downloadTaskProgressDictionary["\(task.taskIdentifier)"] = progress
                }
            }

            self.defaultSessionManager?.setDownloadTaskDidWriteDataBlock({ (session: NSURLSession?, task: NSURLSessionTask!, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
                if let progress = self.dataTaskProgressDictionary["\(task.taskIdentifier)"] {
                    progress(progress: Float(totalBytesWritten) / Float(totalBytesExpectedToWrite))
                }
            })

            if let task = task {
                task.resume()
            }
    }

    public func retryRequest<T: Request>(request: T) {
                
        if self.networkStatus == .NotReachable {
            
            request.updateStatus(.PendingRetry)
            self.runningRequests.addObject(request)
            return
        }
        
        request.updateRetryCount(request.retryCount + 1)
        self.dispatch(request)

    }

    public func retryRequests() {
        for request in self.runningRequests {
            let request = request as! Request
            if request.status == .PendingRetry {
                self.retryRequest(request)
            }
        }
    }


    // MARK: Private
    private var downloadTaskProgressDictionary = [String : Progress]()

    /**
    Dispatch For DataTask

    :param: request
    :param: sessionManager
    */
    typealias Progress = Request.Progress

    private var dataTaskProgressDictionary = [String : Progress]()

    private func dispatchForDataTask(#request: Request, sessionManager: AFHTTPSessionManager) {
        if let component = request.component {
            var error: NSError? = nil
            let urlRequest = AFHTTPRequestSerializer().requestWithMethod (
                component.method.rawValue,
                URLString: self.absoluteUrlString(request) as String,
                parameters: component.parameters,
                error: &error)
            urlRequest.timeoutInterval = 20

            var task: NSURLSessionTask?
            task = sessionManager.dataTaskWithRequest(urlRequest, completionHandler: { (urlResponse: NSURLResponse?, object: AnyObject?, error: NSError?) -> Void in
                if error == nil {
                    var error: NSError? = nil
                    if let object = (object as? NSObject) {
                        self.centralProcessSuccess((urlResponse as! NSHTTPURLResponse?), object: object , error: error, request: request)
                    } else {
                        self.centralProcessFailure((urlResponse as! NSHTTPURLResponse?), object: nil , error: error, request: request)
                    }
                } else {
                    self.centralProcessFailure((urlResponse as! NSHTTPURLResponse?), object: nil, error: error, request: request)
                }
                if let task = task {
                    self.dataTaskProgressDictionary.removeValueForKey("\(task.taskIdentifier)")
                }
                
                self.centralProcessCompletion(request: request)
            })
            if let progress = request.progressHandler, task = task {
                
                self.dataTaskProgressDictionary["\(task.taskIdentifier)"] = progress
            }
            sessionManager.setTaskDidSendBodyDataBlock({ (session: NSURLSession?, task: NSURLSessionTask!, sendBytes, totalSendBytes, totalBytesExpectedToSend) -> Void in
                if let progress = self.dataTaskProgressDictionary["\(task.taskIdentifier)"] {
                    progress(progress: Float(totalSendBytes) / Float(totalBytesExpectedToSend))
                }
            })

            request.setSessionTask(task)
            task?.resume()
        } else {
            assert(false, "Request: Component is nil")
        }
    }

    /**
    Dispatch For Upload Task (Foreground Only)

    :param: request
    :param: sessionManager
    */

    private var uploadTaskProgressDictionary = [String : Progress]()

    private func dispatchForUploadTask(#request: Request, uploadData: [Request.UploadData], sessionManager: AFHTTPSessionManager) {
        
        if let component = request.component {

            var bodyConstructionBlock: ((formData: AFMultipartFormData!) -> Void)?
            
            bodyConstructionBlock = { (formData) -> Void in
                
                for data in uploadData {
                    switch data {
                    case .Data(let data, let name, let fileName):
                        
                        formData.appendPartWithFileData(
                            data,
                            name: name,
                            fileName: fileName,
                            mimeType: NSURL(fileURLWithPath: fileName)!.mimeType())
                        
                    case .Stream(let stream, let name, let fileName, let length):
                        
                        formData.appendPartWithInputStream(
                            stream,
                            name: name,
                            fileName: fileName,
                            length: length,
                            mimeType: NSURL(fileURLWithPath: fileName)!.mimeType())
                        
                    case .URL(let fileUrl, let name):
                        
                        formData.appendPartWithFileURL(
                            fileUrl,
                            name: name,
                            fileName: fileUrl.lastPathComponent,
                            mimeType: fileUrl.mimeType(),
                            error: nil)
                    }
                }
            }
                        
            let urlRequest = AFHTTPRequestSerializer().multipartFormRequestWithMethod(
                component.method.rawValue,
                URLString: self.absoluteUrlString(request) as String,
                parameters: component.parameters,
                constructingBodyWithBlock: bodyConstructionBlock,
                error: nil)

            var task: NSURLSessionTask?
            task = sessionManager.uploadTaskWithStreamedRequest(urlRequest, progress: nil, completionHandler: { (urlResponse, object, error) -> Void in
                if error == nil {
                    var error: NSError? = nil
                    if let object = (object as? NSObject) {
                        self.centralProcessSuccess((urlResponse as! NSHTTPURLResponse?), object: object as NSObject , error: error, request: request)
                    } else {
                        self.centralProcessFailure((urlResponse as! NSHTTPURLResponse?), object: nil , error: error, request: request)
                    }
                } else {
                    self.centralProcessFailure((urlResponse as! NSHTTPURLResponse?), object: nil, error: error, request: request)
                }
                if let task = task {
                    self.uploadTaskProgressDictionary.removeValueForKey("\(task.taskIdentifier)")
                }
                self.centralProcessCompletion(request: request)
            })
            
            request.setSessionTask(task)
            if let progress = request.progressHandler, task = task {

                self.uploadTaskProgressDictionary["\(task.taskIdentifier)"] = progress
            }
            sessionManager.setTaskDidSendBodyDataBlock({ (session: NSURLSession?, task: NSURLSessionTask!, sendBytes, totalSendBytes, totalBytesExpectedToSend) -> Void in
                if let progress = self.uploadTaskProgressDictionary["\(task.taskIdentifier)"] {
                    progress(progress: Float(totalSendBytes) / Float(totalBytesExpectedToSend))
                }
            })
            task?.resume()
        }
    }
}

private extension NSURL {
    func UTI() -> String {
    
        let stringRef: Unmanaged<CFString> = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, self.pathExtension, nil)
        let string = stringRef.takeUnretainedValue()
        return string as! String
    }
    
    func mimeType() -> String {
        
        let stringRef: Unmanaged<CFString> = UTTypeCopyPreferredTagWithClass(self.UTI(), kUTTagClassMIMEType)
        let string = stringRef.takeUnretainedValue()
        return string as! String
    }
}
