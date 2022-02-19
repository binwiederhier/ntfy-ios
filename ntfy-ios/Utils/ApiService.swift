//
//  ApiService.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 2/16/22.
//

import Foundation

class ApiService {
    static let shared = ApiService()

    func poll(subscription: NtfySubscription, completionHandler: @escaping ([NtfyNotification]?, Error?) -> Void) {
        let lastNotificationTime = subscription.lastNotification()?.timestamp ?? 0
        let sinceString = lastNotificationTime > 0 ? String(lastNotificationTime) : "all";
        let urlString = "\(subscription.urlString())/json?poll=1&since=\(sinceString)"
        fetchJsonData(urlString: urlString, completionHandler: completionHandler)
    }

    private func fetchJsonData<T: Decodable>(urlString: String, completionHandler: @escaping ([T]?, Error?) -> ()) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { (data, response, error) in
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
