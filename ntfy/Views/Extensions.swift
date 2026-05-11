import SwiftUI

// MARK: Extensions

extension Notification {
    func linkifiedMessageAttributedString() -> AttributedString {
        let source = formatMessage()
        let mutable = NSMutableAttributedString(string: source)
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(location: 0, length: mutable.string.utf16.count)
        detector?.enumerateMatches(in: mutable.string, options: [], range: range) { match, _, _ in
            guard let match, let url = match.url else { return }
            mutable.addAttribute(.link, value: url, range: match.range)
        }
        
        return AttributedString(mutable)
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
