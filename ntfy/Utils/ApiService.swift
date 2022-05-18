import Foundation

class ApiService: NSObject {
    static let shared = ApiService()
    let tag = "ApiService"
    
    func poll(subscription: Subscription, completionHandler: @escaping ([Message]?, Error?) -> Void) {
        guard let url = URL(string: subscription.urlString()) else { return }
        let lastNotificationTime = subscription.lastNotification()?.time ?? 0
        let sinceString = lastNotificationTime > 0 ? String(lastNotificationTime) : "all";
        let urlString = "\(url)/json?poll=1&since=\(sinceString)"
        
        Log.d(tag, "Polling from \(urlString)")
        fetchJsonData(urlString: urlString, completionHandler: completionHandler)
    }

    func publish(
        subscription: Subscription,
        message: String,
        title: String,
        priority: Int = 3,
        tags: [String] = [],
        completionHandler: @escaping (Notification?, Error?) -> Void
    ) {
        guard let url = URL(string: subscription.urlString()) else { return }
        var request = URLRequest(url: url)

        Log.d(tag, "Publishing to \(url)")
        
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
        let request = URLRequest(url: url)
     
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

