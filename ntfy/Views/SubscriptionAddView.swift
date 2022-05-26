import SwiftUI

struct SubscriptionAddView: View {
    private let tag = "SubscriptionAddView"
    
    @Binding var isShowing: Bool
    
    @EnvironmentObject private var store: Store
    @State private var topic: String = ""
    @State private var useAnother: Bool = false
    @State private var baseUrl: String = ""
    
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
                    Section(
                        footer:
                            (useAnother) ? Text("Support for self-hosted servers is currently very limited. Delivery of messages is significantly delayed and not guaranteed. This is actively being developed.") : Text("")
                    ) {
                        Toggle("Use another server", isOn: $useAnother)
                        if useAnother {
                            TextField("Server URL, e.g. https://ntfy.example.com", text: $baseUrl)
                                .disableAutocapitalization()
                                .disableAutocorrection(true)
                        }
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
                    .disabled(!isValid())
                }
            }
        }
    }
    
    private var sanitizedTopic: String {
        return topic.trimmingCharacters(in: .whitespaces)
    }
    
    private func isValid() -> Bool {
        if sanitizedTopic.isEmpty {
            return false
        } else if sanitizedTopic.range(of: "^[-_A-Za-z0-9]{1,64}$", options: .regularExpression, range: nil, locale: nil) == nil {
            return false
        } else if store.getSubscription(baseUrl: selectedBaseUrl, topic: topic) != nil {
            return false
        }
        return true
    }
    
    private func subscribeAction() {
        DispatchQueue.global(qos: .background).async {
            subscriptionManager.subscribe(baseUrl: selectedBaseUrl, topic: sanitizedTopic)
        }
        isShowing = false
    }
    
    private func cancelAction() {
        isShowing = false
    }
    
    private var selectedBaseUrl: String {
        return (useAnother) ? baseUrl : Config.appBaseUrl
    }
}


struct SubscriptionAddView_Previews: PreviewProvider {
    @State static var isShowing = true
    
    static var previews: some View {
        let store = Store.preview
        SubscriptionAddView(isShowing: $isShowing)
            .environmentObject(store)
    }
}
