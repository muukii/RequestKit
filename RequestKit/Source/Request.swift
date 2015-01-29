// Request.swift
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

class Request {
    enum RequestStatus {
        case Waiting
        case Running
        case Success
        case Failure
    }
    
    enum SessionType {
        case Default
        // feature
//        case Background
    }
    
    typealias Method = Alamofire.Method
    
    enum UploadData {
        case Data(data: NSData, name: String, fileName: String)
        case Stream(stream: NSInputStream, name: String, fileName: String, length: Int64)
        case URL(fileUrl: NSURL, name: String)
    }
    
    enum TaskType {
        case Data
        case Upload(uploadData: UploadData)
    }
    
    typealias Parameters = [String : AnyObject]
    struct RequestComponent {
        var method: Method
        var path: String
        var parameters: Parameters?
        var taskType: TaskType
        init(method: Method, path: String = "") {
            self.method = method
            self.path = path
            self.taskType = .Data
        }
        func description() -> String {
            var log: String = "\n"
            log += "Method: " + method.rawValue + "\n"
            log += "Path: " + path + "\n"
            log += "Parameters: \n" + (parameters?.description ?? "")  + "\n"
            return log
        }
    }
    
    struct AutoRetryConfiguration {
        var timeInterval: NSTimeInterval = 0
        var maxRetryCount: Int = 5
        var enableBackgroundRetry: Bool = true
        init(timeInterval: NSTimeInterval, maxRetryCount: Int = 5, enableBackgroundRetry: Bool = true) {
            self.timeInterval = timeInterval
            self.maxRetryCount = maxRetryCount
            self.enableBackgroundRetry = enableBackgroundRetry
        }
    }
    
    typealias Progress = ((progress: Float) -> Void)
    typealias Success = ((urlResponse: NSHTTPURLResponse?, responseObject: AnyObject?) -> Void)
    typealias Failure = ((urlResponse: NSHTTPURLResponse?, error: NSError?) -> Void)
    
    struct Handlers {
        var progress: Progress?
        var success: Success?
        var failure: Failure?
        init(progress: Progress? = nil, success: Success? = nil, failure: Failure? = nil) {
            self.progress = progress
            self.success = success
            self.failure = failure
        }
    }
    
    var sessionType: SessionType = .Default
    var component: RequestComponent?
    var handlers: Handlers?
    var autoRetryConfiguration: AutoRetryConfiguration = AutoRetryConfiguration(timeInterval: 5)
    var retryCount: Int = 0
    var status: RequestStatus = .Waiting
    var task: NSURLSessionTask?
    
    var baseURL: NSURL? {
        return nil
    }
    
    func appendDefaultParameters(parameters : [String: AnyObject]?) -> [String: AnyObject]? {
        return parameters
    }
}


