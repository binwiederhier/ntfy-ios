import SwiftUI

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
