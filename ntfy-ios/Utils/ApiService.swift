//
//  ApiService.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 2/16/22.
//

import Foundation

class ApiService: NSObject {
    static let shared = ApiService()

    func poll(subscription: NtfySubscription, user: NtfyUser?, completionHandler: @escaping ([NtfyNotification]?, Error?) -> Void) {
        let lastNotificationTime = subscription.lastNotification()?.timestamp ?? 0
        let sinceString = lastNotificationTime > 0 ? String(lastNotificationTime) : "all";
        let urlString = "\(subscription.urlString())/json?poll=1&since=\(sinceString)"
        fetchJsonData(urlString: urlString, user: user, completionHandler: completionHandler)
    }

    func publish(subscription: NtfySubscription, message: String, title: String, priority: Int = 3, tags: [String] = [], user: NtfyUser?, completionHandler: @escaping (NtfyNotification?, Error?) -> Void) {
        guard let url = URL(string: subscription.urlString()) else { return }
        var request = URLRequest(url: url)

        if let user = user {
            let credentials = Credentials.Basic(username: user.username, password: user.password)
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }

        request.httpMethod = "POST"
        request.setValue(title, forHTTPHeaderField: "Title")
        request.setValue(String(priority), forHTTPHeaderField: "Priority")
        request.setValue(tags.joined(separator: ","), forHTTPHeaderField: "Tags")
        request.httpBody = message.data(using: String.Encoding.utf8)
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            print(data)
            print(response)
            print(error)
        }.resume()
    }

    func checkAuth(baseUrl: String, topic: String, user: NtfyUser?, completionHandler: @escaping(AuthCheckResponse?, Error?) -> Void) {
        guard let url = URL(string: "\(baseUrl)/\(topic)/auth") else { return }
        var request = URLRequest(url: url)
        if let user = user {
            let credentials = Credentials.Basic(username: user.username, password: user.password)
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error checking auth: \(error)")
                completionHandler(nil, error)
            }

            if let data = data {
                do {
                    let result = try JSONDecoder().decode(AuthCheckResponse.self, from: data)
                    completionHandler(result, nil)
                } catch {
                    print("Error handling auth response: \(error)")
                }
            }
        }.resume()
    }

    private func fetchJsonData<T: Decodable>(urlString: String, user: NtfyUser?, completionHandler: @escaping ([T]?, Error?) -> ()) {
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        if let user = user {
            let credentials = Credentials.Basic(username: user.username, password: user.password)
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print(error)
                completionHandler(nil, error)
                return
            }

            do {
                let lines = String(decoding: data!, as: UTF8.self).split(whereSeparator: \.isNewline)
                var notifications: [T] = []
                for jsonLine in lines {
                    notifications.append(try JSONDecoder().decode(T.self, from: jsonLine.data(using: .utf8)!))
                }
                completionHandler(notifications, nil)
            } catch {
                print(error)
                completionHandler(nil, error)
            }
        }.resume()
    }
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
