//
//  NotificationRowView.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct NotificationRowView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.openURL) private var openURL
    @ObservedObject var notification: Notification
    let onCopyMessage: () -> Void
    @StateObject private var attachmentController = NotificationAttachmentController()
    @State private var attachmentPresentation: AttachmentPresentation?
    
    var body: some View {
        notificationRow
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    store.delete(notification: notification)
                } label: {
                    Label("Delete", systemImage: "trash.circle")
                }
            }
            .sheet(item: $attachmentPresentation) { attachmentPresentation in
                switch attachmentPresentation.mode {
                case .preview:
                    AttachmentPreviewView(url: attachmentPresentation.url)
                case .share:
                    ActivityView(activityItems: [attachmentPresentation.url])
                }
            }
    }
    
    private var notificationRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    HStack(alignment: .center, spacing: 2) {
                        Text(notification.shortDateTime())
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        if [1,2,4,5].contains(notification.priority) {
                            Image("priority-\(notification.priority)")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        }
                    }
                    Spacer()
                    if clickUrl != nil {
                        messageActionsMenu
                    }
                }
                .padding([.bottom], 2)
                if let title = notification.formatTitle(), title != "" {
                    Text(title)
                        .font(.headline)
                        .bold()
                        .padding([.bottom], 2)
                }
                messageText
                if !notification.nonEmojiTags().isEmpty {
                    Text("Tags: " + notification.nonEmojiTags().joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding([.top], 2)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                handleRowTap()
            }

            if let attachment = notification.messageAttachment() {
                NotificationAttachmentSectionView(
                    notification: notification,
                    attachment: attachment,
                    authorizationHeader: attachmentAuthorizationHeader,
                    controller: attachmentController,
                    onOpen: { attachmentPresentation = AttachmentPresentation(url: $0, mode: .preview) },
                    onShare: { attachmentPresentation = AttachmentPresentation(url: $0, mode: .share) },
                    onSave: { url in
                        Task { @MainActor in
                            AttachmentExportPresenter.shared.present(url: url)
                        }
                    },
                    onCopy: showCopyFeedback
                )
            }
            if !notification.actionsList().isEmpty {
                HStack {
                    ForEach(notification.actionsList()) { action in
                        Button(action.label) {
                            ActionExecutor.execute(action)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding([.top], 5)
            }
        }
        .padding(.all, 4)
        .contentShape(Rectangle())
    }
    
    private var messageText: some View {
        Group {
            Text(notification.displayMessageAttributedString())
                .font(.body)
        }
    }
    
    private var clickUrl: URL? {
        guard let click = notification.click, !click.isEmpty else {
            return nil
        }
        return URL(string: click)
    }

    private var attachmentAuthorizationHeader: String? {
        guard
            let baseUrl = notification.subscription?.baseUrl,
            let user = store.getUser(baseUrl: baseUrl)?.toBasicUser()
        else {
            return nil
        }
        return user.toHeader()
    }
    
    private var messageActionsMenu: some View {
        Menu {
            Button("Copy message") {
                copyMessage()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
        }
        .menuStyle(.borderlessButton)
    }
    
    private func copyMessage() {
        UIPasteboard.general.setValue(notification.formatMessage(), forPasteboardType: UTType.plainText.identifier)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showCopyFeedback()
    }

    private func showCopyFeedback() {
        onCopyMessage()
    }
    
    private func handleRowTap() {
        if let clickUrl {
            openURL(clickUrl)
        } else {
            copyMessage()
        }
    }
}

// MARK: Helper structs
extension NotificationRowView {
    private struct ActivityView: UIViewControllerRepresentable {
        let activityItems: [Any]

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        }
    }

    private struct AttachmentPresentation: Identifiable {
        enum Mode {
            case preview
            case share
        }

        let id = UUID()
        let url: URL
        let mode: Mode
    }

    private struct AttachmentPreviewView: UIViewControllerRepresentable {
        let url: URL

        func makeUIViewController(context: Context) -> UINavigationController {
            let controller = AttachmentPreviewController(onClose: {
                context.coordinator.dismiss?()
            })
            controller.configure(url: url)
            let navigationController = UINavigationController(rootViewController: controller)
            navigationController.modalPresentationStyle = .pageSheet
            context.coordinator.dismiss = { [weak navigationController] in
                navigationController?.dismiss(animated: true)
            }
            return navigationController
        }

        func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
            guard let controller = uiViewController.viewControllers.first as? AttachmentPreviewController else {
                return
            }
            controller.configure(url: url)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        final class Coordinator {
            var dismiss: (() -> Void)?
        }
    }

    private final class AttachmentPreviewController: QLPreviewController, QLPreviewControllerDataSource {
        private let loadingView = UIActivityIndicatorView(style: .large)
        private let onClose: () -> Void
        private var previewItem: PreviewItem?
        private var configuredURL: URL?
        private var hasLoadedCurrentItem = false

        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()

            view.backgroundColor = .systemBackground
            dataSource = self
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closePreview)
            )

            loadingView.translatesAutoresizingMaskIntoConstraints = false
            loadingView.hidesWhenStopped = true
            loadingView.startAnimating()
            view.addSubview(loadingView)

            NSLayoutConstraint.activate([
                loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !hasLoadedCurrentItem else {
                return
            }
            hasLoadedCurrentItem = true
            reloadPreview()
        }

        func configure(url: URL) {
            guard configuredURL != url else {
                return
            }
            configuredURL = url
            previewItem = PreviewItem(url: url)
            navigationItem.title = url.lastPathComponent
            hasLoadedCurrentItem = false
            if isViewLoaded {
                loadingView.startAnimating()
                if view.window != nil {
                    hasLoadedCurrentItem = true
                    reloadPreview()
                }
            }
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            previewItem == nil ? 0 : 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            previewItem ?? PreviewItem(url: URL(fileURLWithPath: ""))
        }

        private func reloadPreview() {
            reloadData()
            currentPreviewItemIndex = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.loadingView.stopAnimating()
            }
        }

        @objc
        private func closePreview() {
            onClose()
        }
    }

    private final class PreviewItem: NSObject, QLPreviewItem {
        let previewItemURL: URL?
        let previewItemTitle: String?

        init(url: URL) {
            self.previewItemURL = url
            self.previewItemTitle = url.lastPathComponent
        }
    }

    @MainActor
    private final class AttachmentExportPresenter: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
        static let shared = AttachmentExportPresenter()
        private var activePicker: UIDocumentPickerViewController?
        private var activeExportUrl: URL?

        func present(url: URL) {
            guard let presenter = topViewController(from: rootViewController()) else {
                return
            }

            let exportUrl: URL
            do {
                exportUrl = try makeTemporaryExportCopy(of: url)
            } catch {
                Log.w("AttachmentExportPresenter", "Failed to prepare attachment export copy", error)
                return
            }

            cleanupActiveExport()

            let picker = UIDocumentPickerViewController(forExporting: [exportUrl], asCopy: true)
            picker.delegate = self
            picker.presentationController?.delegate = self
            activePicker = picker
            activeExportUrl = exportUrl
            presenter.present(picker, animated: true)
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            cleanupIfActive(controller)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            cleanupIfActive(controller)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            guard let picker = presentationController.presentedViewController as? UIDocumentPickerViewController else {
                return
            }
            cleanupIfActive(picker)
        }

        private func rootViewController() -> UIViewController? {
            UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController
        }

        private func topViewController(from controller: UIViewController?) -> UIViewController? {
            if let navigationController = controller as? UINavigationController {
                return topViewController(from: navigationController.visibleViewController)
            }
            if let tabBarController = controller as? UITabBarController {
                return topViewController(from: tabBarController.selectedViewController)
            }
            if let presentedViewController = controller?.presentedViewController {
                return topViewController(from: presentedViewController)
            }
            return controller
        }

        private func cleanupIfActive(_ controller: UIDocumentPickerViewController) {
            guard activePicker === controller else {
                return
            }
            cleanupActiveExport()
        }

        private func cleanupActiveExport() {
            activePicker = nil
            if let activeExportUrl {
                try? FileManager.default.removeItem(at: activeExportUrl)
            }
            activeExportUrl = nil
        }

        private func makeTemporaryExportCopy(of url: URL) throws -> URL {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("ntfy-export", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let destinationUrl = tempDir.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
            try? FileManager.default.removeItem(at: destinationUrl)
            try FileManager.default.copyItem(at: url, to: destinationUrl)
            return destinationUrl
        }
    }

}
