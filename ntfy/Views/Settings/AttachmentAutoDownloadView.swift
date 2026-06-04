//
//  UserEditorView.swift
//  ntfy
//
//  Created by Alek Michelson on 5/18/26.
//

import SwiftUI

private struct AttachmentAutoDownloadOption: Identifiable {
    let value: Int64
    let title: String

    var id: Int64 { value }
}

struct AttachmentAutoDownloadView: View {
    @EnvironmentObject private var store: Store
    @FetchRequest(sortDescriptors: []) private var prefs: FetchedResults<Preference>
    @State private var showingOptions = false

    private var currentValue: Int64 {
        prefs
            .first { $0.key == Store.prefKeyAttachmentAutoDownloadMaxSize }?
            .value
            .flatMap(Int64.init) ?? Store.autoDownloadDefault
    }

    var body: some View {
        Button {
            showingOptions = true
        } label: {
            HStack {
                Text("Download attachments")
                    .foregroundColor(.primary)
                Spacer()
                Text(title(for: currentValue))
                    .foregroundColor(.gray)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .confirmationDialog("Download attachments", isPresented: $showingOptions, titleVisibility: .visible) {
            ForEach(options) { option in
                Button {
                    store.saveAttachmentAutoDownloadMaxSize(option.value)
                } label: {
                    Text(option.title)
                }
            }

            Button("Cancel", role: .cancel) {}
        }
    }

    private var options: [AttachmentAutoDownloadOption] {
        [
            .init(value: Store.autoDownloadNever, title: "Never"),
            .init(value: Store.autoDownloadAlways, title: "Always"),
            .init(value: Store.autoDownload100KB, title: "Under 100 KB"),
            .init(value: Store.autoDownload500KB, title: "Under 500 KB"),
            .init(value: Store.autoDownloadDefault, title: "Under 1 MB"),
            .init(value: Store.autoDownload5MB, title: "Under 5 MB"),
            .init(value: Store.autoDownload10MB, title: "Under 10 MB"),
            .init(value: Store.autoDownload50MB, title: "Under 50 MB")
        ]
    }

    private func title(for value: Int64) -> String {
        options.first(where: { $0.value == value })?.title ?? "Under 1 MB"
    }
}
