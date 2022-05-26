import SwiftUI

struct SubscriptionAddView: View {
    private let tag = "SubscriptionAddView"
    
    @Binding var isShowing: Bool
    
    @EnvironmentObject private var store: Store
    @State private var topic: String = ""
    
    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(
                        footer:
                            Text("Topics may not be password protected, so choose a name that's not easy to guess. Once subscribed, you can PUT/POST notifications")
                    ) {
                        TextField("Topic name, e.g. phil_alerts", text: $topic)
                            .disableAutocapitalization()
                            .disableAutocorrection(true)
                    }
                }
            }
            .navigationTitle("Add subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: cancelAction) {
                        Text("Cancel")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: subscribeAction) {
                        Text("Subscribe")
                    }
                    .disabled(!isValid(topic: topic))
                }
            }
        }
    }
    
    private func sanitize(topic: String) -> String {
        return topic.trimmingCharacters(in: [" "])
    }
    
    private func isValid(topic: String) -> Bool {
        let sanitizedTopic = sanitize(topic: topic)
        if sanitizedTopic.isEmpty {
            return false
        } else if sanitizedTopic.range(of: "^[-_A-Za-z0-9]{1,64}$", options: .regularExpression, range: nil, locale: nil) == nil {
            return false
        } else if store.getSubscription(baseUrl: Config.appBaseUrl, topic: topic) != nil {
            return false
        }
        return true
    }
    
    private func subscribeAction() {
        DispatchQueue.global(qos: .background).async {
            subscriptionManager.subscribe(baseUrl: Config.appBaseUrl, topic: sanitize(topic: topic))
        }
        isShowing = false
    }
    
    private func cancelAction() {
        isShowing = false
    }
}
