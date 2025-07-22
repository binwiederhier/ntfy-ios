//
//  BadgeUpdater.swift
//  ntfy
//
//  Created by David Crowther on 21/7/2025.
//

import UserNotifications
import SwiftUI

class BadgeUpdater {
    static let store = Store.shared

    static func updateBadge() {
        
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(store.totalUnreadNotificationCount)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = store.totalUnreadNotificationCount
        }
    }
}
