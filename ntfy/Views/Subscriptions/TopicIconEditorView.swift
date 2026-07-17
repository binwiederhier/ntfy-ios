import SwiftUI

struct TopicIconEditorView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subscription: Subscription
    @State private var iconText: String

    init(subscription: Subscription) {
        self.subscription = subscription
        _iconText = State(initialValue: subscription.icon ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TopicAvatarView(name: subscription.topicName(), emoji: iconText.isEmpty ? nil : iconText)
                    .scaleEffect(2)
                    .padding(.top, 24)

                VStack(spacing: 8) {
                    TextField("Emoji", text: $iconText)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 32))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onChange(of: iconText) { newValue in
                            if let last = newValue.last {
                                iconText = String(last)
                            }
                            store.saveIcon(for: subscription, icon: iconText)
                        }

                    Text("Tap the field, then tap the globe/emoji key on the keyboard to pick one.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                if !iconText.isEmpty {
                    Button(role: .destructive) {
                        iconText = ""
                        store.saveIcon(for: subscription, icon: nil)
                    } label: {
                        Text("Remove")
                    }
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle(subscription.topicName())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TopicIconEditorView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview
        let subscription = store.makeSubscription(store.context, "stats", Store.sampleMessages["stats"]!)
        TopicIconEditorView(subscription: subscription)
            .environment(\.managedObjectContext, store.context)
            .environmentObject(store)
    }
}
