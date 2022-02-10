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
        let totalNotificationCount = subscription.notificationCount()
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(subscription.displayName())
                    .font(.headline)
                    .bold()
                    .lineLimit(1)
                Spacer()
                Text(subscription.lastNotification()?.displayShortDateTime() ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12.0))
                    .foregroundColor(.gray)
            }
            Spacer()
            Text("\(totalNotificationCount) notification\(totalNotificationCount != 1 ? "s" : "")")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.all, 4)
    }
}
