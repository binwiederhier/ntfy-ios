import Foundation

struct Actions {
    static let shared = Actions()
    private let tag = "Actions"
    private let supportedActions = ["view", "http"]
    
    func parse(_ actions: String?) -> [Action]? {
        guard let actions = actions,
              let data = actions.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode([Action].self, from: data)
                .filter { supportedActions.contains($0.action) }
        } catch {
            Log.e(tag, "Unable to parse actions: \(error.localizedDescription)", error)
            return nil
        }
    }
    
    func http(_ action: Action) {
        guard let actionUrl = action.url, let url = URL(string: actionUrl) else {
            Log.w(tag, "Unable to execute HTTP action, no or invalid URL", action)
            return
        }
        let method = action.method ?? "POST" // POST is the default!!
        let body = action.body ?? ""

        Log.d(tag, "Performing HTTP \(method) \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        action.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if !["GET", "HEAD"].contains(method) {
            request.httpBody = body.data(using: .utf8)
        }
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                Log.e(self.tag, "Error performing HTTP \(method)", error!)
                return
            }
            Log.d(self.tag, "HTTP \(method) succeeded", response)
        }.resume()
    }
}


