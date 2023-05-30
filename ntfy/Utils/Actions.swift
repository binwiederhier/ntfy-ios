import Foundation

struct Actions {
    static let shared = Actions()
    private let tag = "Actions"
    private let supportedActions = ["view", "http"]
    
    func parse(_ actions: String?) -> [MessageAction]? {
        guard let actions = actions, actions != "",
              let data = actions.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode([MessageAction].self, from: data)
                .filter { supportedActions.contains($0.action) }
        } catch {
            Log.e(tag, "Unable to parse actions: \(error.localizedDescription)", error)
            return nil
        }
    }
    
    func encode(_ actions: [MessageAction]?) -> String {
        guard let actions = actions else { return "" }
        if let actionsData = try? JSONEncoder().encode(actions) {
            return String(data: actionsData, encoding: .utf8) ?? ""
        }
        return ""
    }
}


