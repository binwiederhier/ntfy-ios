//
//  NotificationRow.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/15/22.
//

import SwiftUI

struct NotificationRow: View {
    var notification: NtfyNotification

    var body: some View {
        HStack {
            Text(notification.message)
            Spacer()
        }
    }
}
