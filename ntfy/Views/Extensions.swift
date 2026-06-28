import SwiftUI

// MARK: Extensions

extension Notification {
    /// The message rendered for display: parsed as Markdown when the publisher marked the
    /// message `text/markdown` (via the `Markdown: true` header), otherwise shown as plain text.
    /// Bare URLs are turned into tappable links in both cases. Rendering Markdown only when the
    /// server opted in is deliberate — parsing arbitrary plain-text messages as Markdown would
    /// mangle bodies that happen to contain `*`, `_`, `#`, etc.
    func displayMessageAttributedString() -> AttributedString {
        if isMarkdown, let markdown = markdownMessageAttributedString() {
            return markdown
        }
        return linkifiedMessageAttributedString()
    }

    func linkifiedMessageAttributedString() -> AttributedString {
        var attributed = AttributedString(formatMessage())
        linkifyBareUrls(in: &attributed)
        return attributed
    }

    /// Parses the message body as inline Markdown. Block elements (headings, lists, quotes) are
    /// kept inline by SwiftUI's `Text`, which is the right fidelity for a compact notification row.
    /// Returns nil if parsing fails, so the caller can fall back to plain text.
    private func markdownMessageAttributedString() -> AttributedString? {
        let source = formatMessage()
        let options: AttributedString.MarkdownParsingOptions
        if #available(iOS 16.0, *) {
            // Preserve intentional line breaks (notifications are often multi-line).
            options = .init(interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
        } else {
            options = .init(interpretedSyntax: .inlineOnly, failurePolicy: .returnPartiallyParsedIfPossible)
        }
        guard var attributed = try? AttributedString(markdown: source, options: options) else {
            return nil
        }
        linkifyBareUrls(in: &attributed)
        return attributed
    }
}

/// Detects URLs (e.g. `https://ntfy.sh`) in the text and turns them into tappable links, without
/// overriding links already present — e.g. those produced by Markdown `[text](url)` syntax. Used
/// for both the plain-text and Markdown rendering paths.
private func linkifyBareUrls(in attributed: inout AttributedString) {
    let plain = String(attributed.characters)
    guard
        !plain.isEmpty,
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else { return }

    let nsRange = NSRange(plain.startIndex..<plain.endIndex, in: plain)
    detector.enumerateMatches(in: plain, options: [], range: nsRange) { match, _, _ in
        guard
            let match,
            let url = match.url,
            let stringRange = Range(match.range, in: plain),
            let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
            let upper = AttributedString.Index(stringRange.upperBound, within: attributed)
        else { return }
        let attributedRange = lower..<upper
        if attributed[attributedRange].link == nil {
            attributed[attributedRange].link = url
        }
    }
}

// MARK: Modifiers

struct DisableAutocapitalizationModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .textInputAutocapitalization(.never)
        } else {
            content
                .autocapitalization(.none)
        }
    }
}

extension View {
    func disableAutocapitalization() -> some View {
        modifier(DisableAutocapitalizationModifier())
    }
}
