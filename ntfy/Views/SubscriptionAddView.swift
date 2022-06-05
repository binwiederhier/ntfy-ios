import SwiftUI

struct SubscriptionAddView: View {
    private let tag = "SubscriptionAddView"
    
    @Binding var isShowing: Bool
    
    @EnvironmentObject private var store: Store
    @State private var topic: String = ""
    @State private var useAnother: Bool = false
    @State private var baseUrl: String = ""
    
    @State private var showLogin: Bool = false
    @State private var username: String = ""
    @State private var password: String = ""
    
    @State private var loading = false
    @State private var addError: String?
    @State private var loginError: String?


    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }
    
    var body: some View {
        NavigationView {
            // This is a little weird, but it works. The nagivation link for the login view
            // is rendered in the backgroun (it's hidden), abd we toggle it manually.
            // If anyone has a better way to do a two-page layout let me know.
            
            addView
                .background(Group {
                    NavigationLink(
                        destination: loginView,
                        isActive: $showLogin
                    ) {
                        EmptyView()
                    }
                })
        }
    }
    
    private var addView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section(
                    footer: Text("Topics are not password protected, so choose a name that's not easy to guess. Once subscribed, you can PUT/POST notifications")
                ) {
                    TextField("Topic name, e.g. phil_alerts", text: $topic)
                        .disableAutocapitalization()
                        .disableAutocorrection(true)
                }
                Section(
                    footer:
                        (useAnother) ? Text("Support for self-hosted servers is currently limited. To ensure instant delivery, be sure to set upstream-base-url in your server's config, otherwise messages may arrive with significant delay. Auth is not yet supported.") : Text("")
                ) {
                    Toggle("Use another server", isOn: $useAnother)
                    if useAnother {
                        TextField("Service URL, e.g. https://ntfy.home.io", text: $baseUrl)
                            .disableAutocapitalization()
                            .disableAutocorrection(true)
                    }
                }
            }
            if let error = addError {
                ErrorView(error: error)
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
                Button(action: subscribeOrShowLoginAction) {
                    VStack {
                        if loading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Subscribe")
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)

                }
                .disabled(!isAddViewValid())
            }
        }
    }
    
    private var loginView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section(
                    footer: Text("This topic requires that you log in with username and password. The user will be stored on your device, and will be re-used for other topics.")
                ) {
                    TextField("Username", text: $username)
                        .disableAutocapitalization()
                        .disableAutocorrection(true)
                    SecureField("Password", text: $password)
                }
            }
            if let error = loginError {
                ErrorView(error: error)
            }
        }
        .navigationTitle("Login required")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: subscribeWithUserAction) {
                    if loading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Subscribe")
                    }
                }
                .disabled(!isLoginViewValid())
            }
        }
    }
    
    private var sanitizedTopic: String {
        return topic.trimmingCharacters(in: .whitespaces)
    }
    
    private func isAddViewValid() -> Bool {
        if sanitizedTopic.isEmpty {
            return false
        } else if sanitizedTopic.range(of: "^[-_A-Za-z0-9]{1,64}$", options: .regularExpression, range: nil, locale: nil) == nil {
            return false
        } else if selectedBaseUrl.range(of: "^https?://.+", options: .regularExpression, range: nil, locale: nil) == nil {
            return false
        } else if store.getSubscription(baseUrl: selectedBaseUrl, topic: topic) != nil {
            return false
        }
        return true
    }
    
    private func isLoginViewValid() -> Bool {
        if username.isEmpty || password.isEmpty {
            return false
        }
        return true
    }
    
    private func subscribeOrShowLoginAction() {
        loading = true
        addError = nil
        let user = store.getUser(baseUrl: selectedBaseUrl)?.toBasicUser()
        ApiService.shared.checkAuth(baseUrl: selectedBaseUrl, topic: topic, user: user) { result in
            switch result {
            case .Success:
                DispatchQueue.global(qos: .background).async {
                    subscriptionManager.subscribe(baseUrl: selectedBaseUrl, topic: sanitizedTopic)
                    resetAndHide()
                }
                // Do not reset "loading", because resetAndHide() will do that after everything is done
            case .Unauthorized:
                if let user = user {
                    addError = "User \(user.username) is not authorized to read this topic"
                } else {
                    addError = nil // Reset
                    showLogin = true
                }
                loading = false
            case .Error(let err):
                addError = err
                loading = false
            }
        }
    }
    
    private func subscribeWithUserAction() {
        loading = true
        loginError = nil
        let user = BasicUser(username: username, password: password)
        ApiService.shared.checkAuth(baseUrl: selectedBaseUrl, topic: topic, user: user) { result in
            switch result {
            case .Success:
                DispatchQueue.global(qos: .background).async {
                    store.saveUser(baseUrl: selectedBaseUrl, username: username, password: password)
                    subscriptionManager.subscribe(baseUrl: selectedBaseUrl, topic: sanitizedTopic)
                    resetAndHide()
                }
                // Do not reset "loading", because resetAndHide() will do that after everything is done
            case .Unauthorized:
                loginError = "Invalid credentials, or user \(username) is not authorized to read this topic"
                loading = false
            case .Error(let err):
                loginError = err
                loading = false
            }
        }
    }
    
    private func cancelAction() {
        resetAndHide()
    }
    
    private var selectedBaseUrl: String {
        return (useAnother) ? baseUrl : store.getDefaultBaseUrl()
    }
    
    private func resetAndHide() {
        isShowing = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // Hide first and then reset, otherwise we'll see the text fields change
            addError = nil
            loginError = nil
            loading = false
            baseUrl = ""
            topic = ""
            useAnother = false
        }
    }
}

struct ErrorView: View {
    var error: String
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.title2)
            Text(error)
                .font(.subheadline)
        }
        .padding([.leading, .trailing], 20)
        .padding([.top, .bottom], 10)
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
