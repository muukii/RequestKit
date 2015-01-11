// Dispatcher.swift
//
// Copyright (c) 2015 muukii
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
import Alamofire

class Dispatcher {
    enum NetworkStatus: Int {
        case Unknown      = -1
        case NotReachable = 0
        case ViaWWAN      = 1
        case ViaWiFi      = 2
    }
    
    class var sharedInstance: Dispatcher {
        struct Singleton {
            static let instance = Dispatcher()
        }
        return Singleton.instance
    }
    
    var defaultSessionManager: Alamofire.Manager!
    var backgroundSessionManager: Alamofire.Manager!
    //    var reachabilityManager: Alamofire.Manager?
    var networkStatus: NetworkStatus = .Unknown
    
    init() {
        //        self.reachabilityManager = AFNetworkReachabilityManager.sharedManager()
        //        self.reachabilityManager?.startMonitoring()
        //        self.reachabilityManager?.setReachabilityStatusChangeBlock({ (status: AFNetworkReachabilityStatus) -> Void in
        //            self.networkStatus = NetworkStatus(rawValue: status.rawValue) ?? .Unknown
        //            self.changedReachabilityStatus(NetworkStatus(rawValue: status.rawValue) ?? .Unknown)
        //        })
        
        let defaultSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        self.defaultSessionManager = Alamofire.Manager(configuration: defaultSessionConfiguration)
        
        //        self.defaultSessionManager?.requestSerializer = AFHTTPRequestSerializer?()
    }
    
    deinit {
        //        self.reachabilityManager?.startMonitoring()
    }
    
    func changedReachabilityStatus(status: NetworkStatus) {
        switch status {
        case .Unknown:
            println("Change Status Unknown")
        case .NotReachable:
            println("Change Status NotReachable")
        case .ViaWWAN:
            println("Change Status WWan")
        case .ViaWiFi:
            println("Change Status WiFi")
        }
    }
    
    /**
    Connection: Success
    
    :param: urlResponse
    :param: object
    :param: error
    :param: request
    */
    func centralProcessSuccess(urlResponse: NSHTTPURLResponse?, object: NSObject?, error: NSError?, request: Request) {
        request.status = .Success
        if let response = urlResponse {
            println("\(response.statusCode) : Successful connection -> \(response.URL?.absoluteString)")
        }
    }
    
    /**
    Connection: Failure
    
    :param: urlResponse
    :param: object
    :param: error
    :param: request
    */
    func centralProcessFailure(urlResponse: NSHTTPURLResponse?, object: NSObject?, error: NSError?, request: Request) {
        request.status = .Failure
        if let response = urlResponse {
            println("\(response.statusCode) : Failed connection -> \(response.URL!.absoluteString)")
        }
    }
    func invalidateRequests() {
        
    }
    
    /**
    Dispatch Request
    
    :param: request
    */
    func dispatch(request: Request) {
        var backgroundTask = UIBackgroundTaskInvalid
        backgroundTask = UIApplication.sharedApplication().beginBackgroundTaskWithName("jp.eure.couples.background_task", expirationHandler: { () -> Void in
            UIApplication.sharedApplication().endBackgroundTask(backgroundTask)
            backgroundTask = UIBackgroundTaskInvalid
        })
        
        request.status = .Running
        if let component = request.component {
            request.component?.parameters = request.appendDefaultParameters(component.parameters)
            var sessionManager: Alamofire.Manager?
            switch request.sessionType {
            case .Default:
                sessionManager = self.defaultSessionManager
            }
            if let sessionManager = sessionManager {
                switch component.taskType {
                case .Data:
                    self.dispatchForDataTask(request, manager: sessionManager)
                case .Upload(upload: let data):
                    break
//                    self.dispatchForUploadTask(request, data: data, manager: sessionManager)
                }
            }
        } else {
            request.status = .Failure
            assert(false, "Component is nil")
        }
    }
    
    private func absoluteUrlString(request: Request) -> String {
        let baseUrlString = request.baseURL?.absoluteString
        let urlString = baseUrlString?.stringByAppendingPathComponent(request.component?.path ?? "")
        return urlString ?? ""
    }
    
    /**
    Dispatch For DataTask
    
    :param: request
    :param: sessionManager
    */
    typealias Progress = Request.Progress
    
    private var dataTaskProgressDictionary = [String : Progress]()
    
    private func dispatchForDataTask(request: Request, manager: Alamofire.Manager) {
        if let component = request.component {
            var task: NSURLSessionTask
            
            let _request = manager.request(
                component.method,
                self.absoluteUrlString(request),
                parameters: component.parameters,
                encoding: ParameterEncoding.JSON)
            
            task = _request.task
            
            _request.responseJSON({ (urlRequest, urlResponse, object, error) -> Void in
                if error == nil {
                    var error: NSError? = nil
                    if let object = (object as? NSObject) {
                        self.centralProcessSuccess((urlResponse as NSHTTPURLResponse?), object: object , error: error, request: request)
                    } else {
                        self.centralProcessFailure((urlResponse as NSHTTPURLResponse?), object: nil , error: error, request: request)
                    }
                } else {
                    self.centralProcessFailure((urlResponse as NSHTTPURLResponse?), object: nil, error: error, request: request)
                }
                self.dataTaskProgressDictionary.removeValueForKey("\(task.taskIdentifier)")
            })
            
            _request.progress(closure: { (sendBytes, totalSendBytes, totalBytesExpectedToSend) -> Void in
                if let progress = self.dataTaskProgressDictionary["\(task.taskIdentifier)"] {
                    progress(progress: Float(totalSendBytes) / Float(totalBytesExpectedToSend))
                }
            })
            
            request.task = task
            _request.resume()
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
    
//    private func dispatchForUploadTask(request: Request, data: Request.UploadData, manager: Alamofire.Manager) {
//        if let component = request.component {
//            
//            var bodyConstructionBlock: ((formData: AFMultipartFormData!) -> Void)?
//            switch data {
//            case .Data(let data, let name, let fileName):
//                bodyConstructionBlock = { (formData) -> Void in
//                    formData.appendPartWithFileData(
//                        data,
//                        name: name,
//                        fileName: fileName,
//                        mimeType: NSURL(fileURLWithPath: fileName)!.mimeType())
//                }
//                
//            case .Stream(let stream, let name, let fileName, let length):
//                bodyConstructionBlock = { (formData) -> Void in
//                    formData.appendPartWithInputStream(
//                        stream,
//                        name: name,
//                        fileName: fileName,
//                        length: length,
//                        mimeType: NSURL(fileURLWithPath: fileName)!.mimeType())
//                }
//                
//            case .URL(let fileUrl, let name):
//                bodyConstructionBlock = { (formData) -> Void in
//                    formData.appendPartWithFileURL(
//                        fileUrl,
//                        name: name,
//                        fileName: fileUrl.lastPathComponent,
//                        mimeType: fileUrl.mimeType(),
//                        error: nil)
//                    return
//                }
//            }
//            
//            let urlRequest = AFHTTPRequestSerializer().multipartFormRequestWithMethod(
//                component.method.rawValue,
//                URLString: self.absoluteUrlString(request),
//                parameters: component.parameters,
//                constructingBodyWithBlock: bodyConstructionBlock,
//                error: nil)
//            
//    
//            let _request = manager.request(
//                component.method,
//                self.absoluteUrlString(request),
//                parameters: component.parameters,
//                encoding: ParameterEncoding.JSON)
//            
//            var task: NSURLSessionTask?
//            task = sessionManager.uploadTaskWithStreamedRequest(urlRequest, progress: nil, completionHandler: { (urlResponse, object, error) -> Void in
//                if error == nil {
//                    var error: NSError? = nil
//                    if let object = (object as? NSObject) {
//                        self.centralProcessSuccess((urlResponse as NSHTTPURLResponse?), object: object as NSObject , error: error, request: request)
//                    } else {
//                        self.centralProcessFailure((urlResponse as NSHTTPURLResponse?), object: nil , error: error, request: request)
//                    }
//                } else {
//                    self.centralProcessFailure((urlResponse as NSHTTPURLResponse?), object: nil, error: error, request: request)
//                }
//                if let task = task {
//                    self.uploadTaskProgressDictionary.removeValueForKey("\(task.taskIdentifier)")
//                }
//            })
//            request.task = task
//            if let progress = request.handlers?.progress {
//                if let task = task {
//                    self.uploadTaskProgressDictionary["\(task.taskIdentifier)"] = progress
//                }
//            }
//            manager.setTaskDidSendBodyDataBlock({ (session: NSURLSession?, task: NSURLSessionTask!, sendBytes, totalSendBytes, totalBytesExpectedToSend) -> Void in
//                if let progress = self.uploadTaskProgressDictionary["\(task.taskIdentifier)"] {
//                    progress(progress: Float(totalSendBytes) / Float(totalBytesExpectedToSend))
//                }
//            })
//            task?.resume()
//        }
//    }
    
    
    private var downloadTaskProgressDictionary = [String : Progress]()
    func dispathForDownloadTask(
        #fileName: String,
        downloadUrl: NSURL,
        downloadDestination: NSURL,
        progress: ((progress: Float) -> Void)?,
        success: ((fileUrl: NSURL, response: NSHTTPURLResponse?) -> Void)?,
        failure: ((error: NSError?) -> Void)?) {
    
            var task: NSURLSessionTask?
            let _request = self.defaultSessionManager.request(
                Alamofire.Method.GET,
                downloadUrl,
                parameters: nil,
                encoding: ParameterEncoding.JSON)
            
            task = self.defaultSessionManager?.downloadTaskWithRequest(urlRequest, progress: nil, destination: { (url, response) -> NSURL! in
                return downloadDestination.URLByAppendingPathComponent(fileName)
                }, completionHandler: { (response, url, error) -> Void in
                    if let task = task {
                        self.downloadTaskProgressDictionary.removeValueForKey("\(task.taskIdentifier)")
                    }
                    
                    if error == nil {
                        success?(fileUrl: url, response: response as NSHTTPURLResponse?)
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
}
