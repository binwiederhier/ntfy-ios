//
//  SubscriptionRow.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/15/22.
//

import SwiftUI

struct SubscriptionRow: View {
    var subscription: NtfySubscription

    var body: some View {
        HStack {
            Text(subscription.displayName())
            Spacer()
        }
    }
}
