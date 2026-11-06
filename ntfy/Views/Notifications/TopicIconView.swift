import SwiftUI

/// Lets the user set an icon URL for a topic. It is shown as the notification avatar for messages
/// that don't have their own icon (X-Icon).
struct TopicIconView: View {
    let baseUrl: String
    let topic: String

    @Environment(\.presentationMode) private var presentationMode
    @State private var iconUrl: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(
                    footer: Text("Shown next to notifications from this topic, unless a message sets its own icon with the X-Icon header. Use an http(s) URL to a PNG or JPEG image.")
                ) {
                    TextField("https://example.com/icon.png", text: $iconUrl)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                if let url = URL(string: iconUrl), url.scheme == "http" || url.scheme == "https" {
                    Section(header: Text("Preview")) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    }
                }
            }
            .navigationTitle("Notification icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        TopicIconStore.setIconUrl(iconUrl, baseUrl: baseUrl, topic: topic)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                iconUrl = TopicIconStore.iconUrl(baseUrl: baseUrl, topic: topic) ?? ""
            }
        }
    }
}
