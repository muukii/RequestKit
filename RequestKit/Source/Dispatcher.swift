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
    
    var defaultSessionManager: Alamofire.Manager!
    var backgroundSessionManager: Alamofire.Manager!
    
    init() {
        let defaultSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        self.defaultSessionManager = Alamofire.Manager(configuration: defaultSessionConfiguration)
    }
    
    deinit {

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
            if self.validateError(urlResponse, object: object, error: error, request: request) {
                // Do Something
            } else {
                request.handlers?.success?(urlResponse: urlResponse, responseObject: object)
            }
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
        if request.retryCount > request.autoRetryConfiguration.maxRetryCount {
            request.handlers?.failure?(urlResponse: urlResponse, error: error)
            println("\(urlResponse?.statusCode) : Failed connection -> \(urlResponse?.URL?.absoluteString)")
        } else {
            self.retryRequest(request)
        }
    }
    
    func validateError(urlResponse: NSHTTPURLResponse?, object: NSObject?, error: NSError?, request: Request) -> Bool {
        // Customize
        return false
    }
    
    func invalidateRequests() {
        
    }
    
    func retryRequest(request: Request) {
        let delay = request.autoRetryConfiguration.timeInterval * Double(NSEC_PER_SEC)
        let time  = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue(), {
            request.retryCount++
            self.dispatch(request)
        })
    }
    
    /**
    Dispatch Request
    
    :param: request
    */
    func dispatch(request: Request) {
        var backgroundTask = UIBackgroundTaskInvalid
        backgroundTask = UIApplication.sharedApplication().beginBackgroundTaskWithName("me.muukii.requestkit.background_task", expirationHandler: { () -> Void in
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
                    self.dispatchForUploadTask(request, data: data, manager: sessionManager)
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
            
            let alamofireRequest = manager.request(
                component.method,
                self.absoluteUrlString(request),
                parameters: component.parameters,
                encoding: ParameterEncoding.JSON)
            
            task = alamofireRequest.task
            
            alamofireRequest.response({ (urlRequest, urlResponse, object, error) -> Void in
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
            
            alamofireRequest.progress(closure: { (sendBytes, totalSendBytes, totalBytesExpectedToSend) -> Void in
                if let progress = self.dataTaskProgressDictionary["\(task.taskIdentifier)"] {
                    progress(progress: Float(totalSendBytes) / Float(totalBytesExpectedToSend))
                }
            })
            
            if let progress = request.handlers?.progress {
                self.uploadTaskProgressDictionary["\(task.taskIdentifier)"] = progress
            }
            
            request.task = task
            alamofireRequest.resume()
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
    
    private func dispatchForUploadTask(request: Request, data: Request.UploadData, manager: Alamofire.Manager) {
        if let component = request.component {
            if let url = NSURL(string: self.absoluteUrlString(request)) {
                let urlRequest = NSURLRequest(URL: url)
                var alamofireRequest: Alamofire.Request!
                switch data {
                case .Data(let data, let name, let fileName):
                    alamofireRequest = manager.upload(urlRequest, data: data)
                case .Stream(let stream, let name, let fileName, let length):
                    alamofireRequest = manager.upload(urlRequest, stream: stream)
                case .URL(let fileUrl, let name):
                    alamofireRequest = manager.upload(urlRequest, file: fileUrl)
                }
                
                var task = alamofireRequest.task
                
                alamofireRequest.response({ (urlRequest, urlResponse, object, error) -> Void in
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
                
                alamofireRequest.progress(closure: { (sendBytes, totalSendBytes, totalBytesExpectedToSend) -> Void in
                    if let progress = self.uploadTaskProgressDictionary["\(task.taskIdentifier)"] {
                        progress(progress: Float(totalSendBytes) / Float(totalBytesExpectedToSend))
                    }
                })
                
                if let progress = request.handlers?.progress {
                    self.uploadTaskProgressDictionary["\(task.taskIdentifier)"] = progress
                }
                request.task = task
                alamofireRequest.resume()
            }
        }
    }
    
    
    private var downloadTaskProgressDictionary = [String : Progress]()
    func dispathForDownloadTask(
        #fileName: String,
        downloadUrl: NSURL,
        downloadDestination: NSURL,
        progress: ((progress: Float) -> Void)?,
        success: ((fileUrl: NSURL, response: NSHTTPURLResponse?) -> Void)?,
        failure: ((error: NSError?) -> Void)?) {
    
            let destinationPath = downloadDestination.URLByAppendingPathComponent(fileName)
            let alamofireRequest = self.defaultSessionManager.download(NSURLRequest(URL: downloadUrl), destination: { (url, response) -> (NSURL) in
                return destinationPath
            })
            let task = alamofireRequest.task
            
            alamofireRequest.progress(closure: { (sendBytes, totalSendBytes, totalBytesExpectedToSend) -> Void in
                if let progress = self.uploadTaskProgressDictionary["\(task.taskIdentifier)"] {
                    progress(progress: Float(totalSendBytes) / Float(totalBytesExpectedToSend))
                }
            })
            
            alamofireRequest.response({ (urlRequest, urlResponse, object, error) -> Void in
                self.downloadTaskProgressDictionary.removeValueForKey("\(task.taskIdentifier)")
                if error == nil {
                    success?(fileUrl: destinationPath, response: urlResponse as NSHTTPURLResponse?)
                } else {
                    failure?(error:error)
                }
            })
            
            if let progress = progress {
                self.downloadTaskProgressDictionary["\(task.taskIdentifier)"] = progress
            }
            
            alamofireRequest.resume()
    }
}
