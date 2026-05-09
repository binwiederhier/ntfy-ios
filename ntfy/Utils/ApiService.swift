import Foundation

class ApiService {
    static let shared = ApiService()
    static let userAgent = "ntfy/\(Config.version) (build \(Config.build); iOS \(Config.osVersion))"
    
    private let tag = "ApiService"
    
    func poll(subscription: Subscription, user: BasicUser?, headers: [String: String]? = nil, completionHandler: @escaping ([Message]?, Error?) -> Void) {
        guard let url = URL(string: subscription.urlString()) else {
            completionHandler(nil, URLError(.badURL))
            return
        }
        let since = subscription.lastNotificationId ?? "all"
        let urlString = "\(url)/json?poll=1&since=\(since)"
        
        Log.d(tag, "Polling from \(urlString) with user \(user?.username ?? "anonymous")")
        fetchJsonData(urlString: urlString, user: user, headers: headers, completionHandler: completionHandler)
    }
    
    func poll(subscription: Subscription, messageId: String, user: BasicUser?, headers: [String: String]? = nil, completionHandler: @escaping (Message?, Error?) -> Void) {
        guard let url = URL(string: "\(subscription.urlString())/json?poll=1&id=\(messageId)") else {
            completionHandler(nil, URLError(.badURL))
            return
        }
        Log.d(tag, "Polling single message from \(url) with user \(user?.username ?? "anonymous")")
        
        let request = newRequest(url: url, user: user, headers: headers)
        newSession(timeout: 30).dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(nil, error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                completionHandler(nil, URLError(.badServerResponse))
                return
            }
            guard let data = data else {
                completionHandler(nil, URLError(.badServerResponse))
                return
            }
            do {
                let message = try JSONDecoder().decode(Message.self, from: data)
                completionHandler(message, nil)
            } catch {
                completionHandler(nil, error)
            }
        }.resume()
    }

    func publish(
        subscription: Subscription,
        user: BasicUser?,
        headers: [String: String]? = nil,
        message: String,
        title: String,
        priority: Int = 3,
        tags: [String] = [],
        completionHandler: (() -> Void)? = nil
    ) {
        guard let url = URL(string: subscription.urlString()) else { return }
        var request = newRequest(url: url, user: user, headers: headers)

        Log.d(tag, "Publishing to \(url)")
        
        request.httpMethod = "POST"
        request.setValue(title, forHTTPHeaderField: "Title")
        request.setValue(String(priority), forHTTPHeaderField: "Priority")
        request.setValue(tags.joined(separator: ","), forHTTPHeaderField: "Tags")
        request.httpBody = message.data(using: String.Encoding.utf8)
        newSession(timeout: 10).dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                Log.e(self.tag, "Error publishing message", error!)
                return
            }
            Log.d(self.tag, "Publishing message succeeded", response)
            completionHandler?()
        }.resume()
    }
    
    func checkAuth(baseUrl: String, topic: String, user: BasicUser?, headers: [String: String]? = nil, completionHandler: @escaping(AuthResult) -> Void) {
        guard let url = URL(string: topicAuthUrl(baseUrl: baseUrl, topic: topic)) else { return }
        let request = newRequest(url: url, user: user, headers: headers)
        Log.d(tag, "Checking auth for \(url) with user \(user?.username ?? "anonymous")")
        newSession(timeout: 10).dataTask(with: request) { (data, response, error) in
            if let error = error {
                Log.e(self.tag, "Error checking auth: \(error)")
                completionHandler(.Error(error.localizedDescription))
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    completionHandler(.Unauthorized)
                } else {
                    completionHandler(.Error("Unexpected response from server: \(httpResponse.statusCode)"))
                }
            } else if let data = data {
                do {
                    let result = try JSONDecoder().decode(AuthCheckResponse.self, from: data)
                    Log.d(self.tag, "Auth result: \(result)")
                    if result.success == true {
                        completionHandler(.Success)
                    } else {
                        completionHandler(.Error("Unexpected response from server"))
                    }
                } catch {
                    Log.e(self.tag, "Error handling auth response: \(error)")
                    completionHandler(.Error("Unexpected response from server. Is this a ntfy server?"))
                }
            }
        }.resume()
    }

    private func fetchJsonData<T: Decodable>(urlString: String, user: BasicUser?, headers: [String: String]?, completionHandler: @escaping ([T]?, Error?) -> ()) {
        guard let url = URL(string: urlString) else {
            completionHandler(nil, URLError(.badURL))
            return
        }
        let request = newRequest(url: url, user: user, headers: headers)
        newSession(timeout: 30).dataTask(with: request) { (data, response, error) in
            if let error {
                Log.e(self.tag, "Error fetching data", error)
                completionHandler(nil, error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                completionHandler(nil, URLError(.badServerResponse))
                return
            }
            guard let data = data else {
                completionHandler(nil, URLError(.badServerResponse))
                return
            }
            do {
                let lines = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
                var notifications: [T] = []
                for jsonLine in lines {
                    guard let jsonData = jsonLine.data(using: .utf8) else {
                        throw URLError(.cannotDecodeContentData)
                    }
                    notifications.append(try JSONDecoder().decode(T.self, from: jsonData))
                }
                completionHandler(notifications, nil)
            } catch {
                Log.e(self.tag, "Error fetching data", error)
                completionHandler(nil, error)
            }
        }.resume()
    }
    
    private func newRequest(url: URL, user: BasicUser?, headers: [String: String]? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(ApiService.userAgent, forHTTPHeaderField: "User-Agent")
        if let user = user {
            request.setValue(user.toHeader(), forHTTPHeaderField: "Authorization")
        }
        applyCustomHeaders(headers, to: &request)
        return request
    }

    private func applyCustomHeaders(_ headers: [String: String]?, to request: inout URLRequest) {
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
    
    private func newSession(timeout: TimeInterval) -> URLSession {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = timeout
        sessionConfig.timeoutIntervalForResource = timeout
        return URLSession(configuration: sessionConfig)
    }
}

struct BasicUser {
    let username: String
    let password: String
    
    func toHeader() -> String {
        return "Basic " + String(format: "%@:%@", username, password).data(using: String.Encoding.utf8)!.base64EncodedString()
    }
}

enum AuthResult {
    case Success
    case Unauthorized
    case Error(String)
}

struct AuthCheckResponse: Codable {
    let success: Bool?
    let code: Int?
    let http: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success, code, http, error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success)
        self.code = try container.decodeIfPresent(Int.self, forKey: .code)
        self.http = try container.decodeIfPresent(Int.self, forKey: .http)
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}
