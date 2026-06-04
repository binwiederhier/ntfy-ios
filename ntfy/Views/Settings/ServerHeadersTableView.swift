import Foundation
import SwiftUI

struct HeaderItem: Identifiable {
    let id = UUID()
    var key: String = ""
    var value: String = ""
}

struct ServerHeadersTableView: View {
    @State private var configuredBaseUrls: [String] = []

    @State private var editingBaseUrl: String?
    @State private var showDialog = false

    @State private var baseUrl: String = ""
    @State private var headerItems: [HeaderItem] = []

    var body: some View {
        List {
            ForEach(configuredBaseUrls, id: \.self) { url in
                Button(action: {
                    editingBaseUrl = url
                    baseUrl = url
                    headerItems = headerItemsFor(baseUrl: url)
                    showDialog = true
                }) {
                    ServerHeaderRowView(baseUrl: url, headerCount: ServerConfigStore.shared.getHeaders(baseUrl: url).count)
                        .foregroundColor(.primary)
                }
            }
            Button(action: {
                editingBaseUrl = nil
                baseUrl = ""
                headerItems = [HeaderItem()]
                showDialog = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add headers")
                }
                .foregroundColor(.primary)
            }
            .padding(.all, 4)
        }
        .onAppear { reloadConfiguredBaseUrls() }
        .sheet(isPresented: $showDialog, onDismiss: { resetState() }) {
            NavigationView {
                Form {
                    Section(
                        footer: Text("Custom headers are sent with all requests to this server.")
                    ) {
                        if editingBaseUrl == nil {
                            TextField("Service URL, e.g. https://ntfy.home.io", text: $baseUrl)
                                .disableAutocapitalization()
                                .disableAutocorrection(true)
                        } else {
                            HStack {
                                Text("Server")
                                Spacer()
                                Text(shortUrl(url: baseUrl))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    Section(
                        header: Text("Headers"),
                        footer: Text("Example: CF-Access-Client-Id, CF-Access-Client-Secret")
                    ) {
                        ForEach(headerItems.indices, id: \.self) { index in
                            HStack {
                                TextField("Header", text: $headerItems[index].key)
                                    .disableAutocapitalization()
                                    .disableAutocorrection(true)
                                TextField("Value", text: $headerItems[index].value)
                                    .disableAutocapitalization()
                                    .disableAutocorrection(true)
                                Button(action: {
                                    headerItems.remove(at: index)
                                    if headerItems.isEmpty {
                                        headerItems = [HeaderItem()]
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        Button(action: {
                            headerItems.append(HeaderItem())
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add header")
                            }
                        }
                    }
                }
                .navigationTitle(editingBaseUrl == nil ? "Add headers" : "Edit headers")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if editingBaseUrl == nil {
                            Button("Cancel") {
                                cancelAction()
                            }
                        } else {
                            Menu {
                                Button("Cancel") {
                                    cancelAction()
                                }
                                if #available(iOS 15.0, *) {
                                    Button(role: .destructive) {
                                        deleteAction()
                                    } label: {
                                        Text("Delete")
                                    }
                                } else {
                                    Button("Delete") {
                                        deleteAction()
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .padding([.leading], 40)
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: saveAction) {
                            Text("Save")
                        }
                        .disabled(!isValid())
                    }
                }
            }
        }
    }

    private func headerItemsFor(baseUrl: String) -> [HeaderItem] {
        let headers = ServerConfigStore.shared.getHeaders(baseUrl: baseUrl)
        let items = headers.keys.sorted().map { key in
            HeaderItem(key: key, value: headers[key] ?? "")
        }
        return items.isEmpty ? [HeaderItem()] : items
    }

    private func saveAction() {
        let headers = normalizedHeaders()
        let targetUrl = editingBaseUrl ?? normalizedBaseUrl
        ServerConfigStore.shared.saveHeaders(baseUrl: targetUrl, headers: headers)
        reloadConfiguredBaseUrls()
        resetAndHide()
    }

    private func cancelAction() {
        resetAndHide()
    }

    private func deleteAction() {
        if let url = editingBaseUrl {
            ServerConfigStore.shared.deleteHeaders(baseUrl: url)
            reloadConfiguredBaseUrls()
        }
        resetAndHide()
    }

    private var normalizedBaseUrl: String {
        normalizeBaseUrl(baseUrl.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func hasInvalidHeaderItem() -> Bool {
        for item in headerItems {
            let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = item.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty && value.isEmpty {
                continue
            }
            if key.isEmpty || value.isEmpty {
                return true
            }
            if !CustomHeaders.isValidKey(key) {
                return true
            }
            // Reject CR/LF in values to prevent header injection (URLRequest.setValue would crash anyway).
            if value.contains(where: { $0.isNewline }) {
                return true
            }
        }
        return false
    }

    private func normalizedHeaders() -> [String: String] {
        var headers: [String: String] = [:]
        for item in headerItems {
            let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = item.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty || value.isEmpty {
                continue
            }
            headers[key] = value
        }
        return headers
    }

    private func isValid() -> Bool {
        if editingBaseUrl == nil {
            if normalizedBaseUrl.range(of: "^https?://.+", options: .regularExpression, range: nil, locale: nil) == nil {
                return false
            }
            if configuredBaseUrls.contains(normalizedBaseUrl) {
                return false
            }
            if normalizedHeaders().isEmpty {
                return false
            }
        }
        if hasInvalidHeaderItem() {
            return false
        }
        return true
    }

    private func reloadConfiguredBaseUrls() {
        configuredBaseUrls = ServerConfigStore.shared.allConfiguredBaseUrls()
    }

    private func resetAndHide() {
        showDialog = false
    }

    fileprivate func resetState() {
        editingBaseUrl = nil
        baseUrl = ""
        headerItems = []
    }
}

struct ServerHeaderRowView: View {
    let baseUrl: String
    let headerCount: Int

    var body: some View {
        HStack {
            Image(systemName: "slider.horizontal.3")
            VStack(alignment: .leading, spacing: 0) {
                Text(shortUrl(url: baseUrl))
                Text("\(headerCount) header(s)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.system(size: 12.0))
                .foregroundColor(.gray)
        }
        .padding(.all, 4)
    }
}
