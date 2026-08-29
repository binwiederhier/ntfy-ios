import SwiftUI

struct SubscriptionAddView: View {
    private let tag = "SubscriptionAddView"
    private let initialSubscription: NtfyDeepLink?
    private let subscribeOnAppear: Bool
    private let onSubscribed: (() -> Void)?
    
    @Binding var isShowing: Bool
    
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var delegate: AppDelegate
    @State private var topic: String = ""
    @State private var useAnother: Bool = false
    @State private var baseUrl: String = ""
    @State private var scannedSubscription: NtfyDeepLink?
    @State private var showingQRScanner = false
    
    @State private var showLogin: Bool = false
    @State private var username: String = ""
    @State private var password: String = ""
    
    @State private var loading = false
    @State private var addError: String?
    @State private var loginError: String?
    @State private var didAttemptInitialSubscription = false

    init(
        isShowing: Binding<Bool>,
        initialSubscription: NtfyDeepLink? = nil,
        subscribeOnAppear: Bool = false,
        onSubscribed: (() -> Void)? = nil
    ) {
        self._isShowing = isShowing
        self.initialSubscription = initialSubscription
        self.subscribeOnAppear = subscribeOnAppear
        self.onSubscribed = onSubscribed
        self._topic = State(initialValue: initialSubscription?.topic ?? "")
        self._useAnother = State(initialValue: initialSubscription != nil)
        self._baseUrl = State(initialValue: initialSubscription?.baseUrl ?? "")
        self._scannedSubscription = State(initialValue: nil)
    }

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
        .onAppear {
            guard subscribeOnAppear, !didAttemptInitialSubscription else {
                return
            }
            didAttemptInitialSubscription = true
            if store.getSubscription(baseUrl: selectedBaseUrl, topic: sanitizedTopic) != nil {
                finishSubscription()
            } else {
                subscribeOrShowLoginAction()
            }
        }
        .sheet(isPresented: $showingQRScanner) {
            SubscriptionQRScannerView(onScan: handleScannedSubscription)
        }
    }
    
    private var addView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section(
                    footer: Text("Topics may not be password-protected, so choose a name that's not easy to guess. Once subscribed, you can PUT/POST notifications")
                ) {
                    TextField("Topic name, e.g. phil_alerts", text: $topic)
                        .disableAutocapitalization()
                        .disableAutocorrection(true)
                }
                Section(
                    footer:
                        (useAnother) ? Text("To ensure instant delivery from your self-hosted server, be sure to set upstream-base-url in your server's config, otherwise messages may arrive with significant delay.") : Text("")
                ) {
                    Toggle("Use another server", isOn: $useAnother)
                    if useAnother {
                        TextField("Service URL, e.g. https://ntfy.home.io", text: $baseUrl)
                            .disableAutocapitalization()
                            .disableAutocorrection(true)
                    }
                }
                if initialSubscription == nil {
                    Section {
                        Button {
                            showingQRScanner = true
                        } label: {
                            Label("Scan QR code", systemImage: "qrcode.viewfinder")
                        }
                    }
                }
            }
            .disabled(loading || activeSubscription != nil)
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
                .disabled(!isAddViewValid() || loading)
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
            .disabled(loading)
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
                .disabled(!isLoginViewValid() || loading)
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
        } else if store.getSubscription(baseUrl: selectedBaseUrl, topic: sanitizedTopic) != nil {
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
        ApiService.shared.checkAuth(baseUrl: selectedBaseUrl, topic: sanitizedTopic, user: user) { result in
            DispatchQueue.main.async {
                switch result {
                case .Success:
                    subscribeAndFinish()
                case .Unauthorized:
                    username = user?.username ?? ""
                    password = ""
                    addError = nil
                    showLogin = true
                    loading = false
                case .Error(let err):
                    addError = err
                    loading = false
                }
            }
        }
    }
    
    private func subscribeWithUserAction() {
        loading = true
        loginError = nil
        let user = BasicUser(username: username, password: password)
        ApiService.shared.checkAuth(baseUrl: selectedBaseUrl, topic: sanitizedTopic, user: user) { result in
            DispatchQueue.main.async {
                switch result {
                case .Success:
                    store.saveUser(baseUrl: selectedBaseUrl, username: username, password: password)
                    subscribeAndFinish()
                case .Unauthorized:
                    loginError = "Invalid credentials, or user \(username) is not authorized to read this topic"
                    loading = false
                case .Error(let err):
                    loginError = err
                    loading = false
                }
            }
        }
    }
    
    private func cancelAction() {
        resetAndHide()
    }
    
    private var selectedBaseUrl: String {
        if let activeSubscription {
            return activeSubscription.baseUrl
        }
        return normalizeBaseUrl(useAnother ? baseUrl : store.getDefaultBaseUrl())
    }

    private var activeSubscription: NtfyDeepLink? {
        scannedSubscription ?? initialSubscription
    }

    private func subscribeAndFinish() {
        subscriptionManager.subscribe(
            baseUrl: selectedBaseUrl,
            topic: sanitizedTopic,
            displayName: activeSubscription?.displayName
        )
        finishSubscription()
    }

    private func finishSubscription() {
        isShowing = false
        if let scannedSubscription {
            delegate.showSubscription(scannedSubscription)
        } else {
            onSubscribed?()
        }
        resetFormAfterDismissal()
    }

    private func handleScannedSubscription(_ subscription: NtfyDeepLink) {
        scannedSubscription = subscription
        topic = subscription.topic
        baseUrl = subscription.baseUrl
        useAnother = true
        showingQRScanner = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if store.getSubscription(baseUrl: selectedBaseUrl, topic: sanitizedTopic) != nil {
                finishSubscription()
            } else {
                subscribeOrShowLoginAction()
            }
        }
    }
    
    private func resetAndHide() {
        isShowing = false
        resetFormAfterDismissal()
    }

    private func resetFormAfterDismissal() {
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
            .environmentObject(AppDelegate())
    }
}
