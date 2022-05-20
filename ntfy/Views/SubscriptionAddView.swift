import SwiftUI
import FirebaseMessaging

struct SubscriptionAddView: View {
    private let tag = "SubscriptionAddView"
    
    @Environment(\.managedObjectContext) var context
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject private var store: Store
    @State private var topic: String = ""

    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }
    
    var body: some View {
        VStack {
            Form {
                Section(
                    header: Text("Topic name"),
                    footer: Text("Topics may not be password protected, so choose a name that's not easy to guess. Once subscribed, you can PUT/POST notifications")
                ) {
                    TextField("Topic name, e.g. phil_alerts", text: $topic)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: subscribeAction) {
                        Text("Subscribe")
                    }
                    .disabled(!isTopicValid(topic: sanitizeTopic(topic: topic)))
                }
            }
        }
    }
    
    private func sanitizeTopic(topic: String) -> String {
        return topic.trimmingCharacters(in: [" "])
    }
    
    private func isTopicValid(topic: String) -> Bool {
        return !topic.isEmpty && (topic.range(of: "^[-_A-Za-z0-9]{1,64}$", options: .regularExpression, range: nil, locale: nil) != nil)
    }
    
    private func subscribeAction() {
        subscriptionManager.subscribe(baseUrl: appBaseUrl, topic: topic)
        presentationMode.wrappedValue.dismiss()
    }
}
