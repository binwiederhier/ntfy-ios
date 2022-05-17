//
//  ApiService.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 2/16/22.
//

import Foundation

class ApiService: NSObject {
    static let shared = ApiService()

    func poll(subscription: Subscription, completionHandler: @escaping ([Message]?, Error?) -> Void) {
        let lastNotificationTime = 0 //subscription.lastNotification()?.timestamp ?? 0 // FIXME
        let sinceString = lastNotificationTime > 0 ? String(lastNotificationTime) : "all";
        let urlString = "\(subscription.urlString())/json?poll=1&since=\(sinceString)"
        fetchJsonData(urlString: urlString, completionHandler: completionHandler)
    }

    func publish(subscription: Subscription, message: String, title: String, priority: Int = 3, tags: [String] = [], completionHandler: @escaping (Notification?, Error?) -> Void) {
        guard let url = URL(string: subscription.urlString()) else { return }
        var request = URLRequest(url: url)

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

    private func fetchJsonData<T: Decodable>(urlString: String, completionHandler: @escaping ([T]?, Error?) -> ()) {
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
     
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

struct Message: Decodable {
    var id: String
    var time: Int64
    var message: String?
    var title: String?
}
