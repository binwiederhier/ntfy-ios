//
//  View.swift
//  ntfy
//
//  Created by Callum Yarnold on 24/05/2022.
//

import SwiftUI

struct disableAutoCapitalisationModifier: ViewModifier {
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
	func disableAutoCapitalisation() -> some View {
		modifier(disableAutoCapitalisationModifier())
	}
}
