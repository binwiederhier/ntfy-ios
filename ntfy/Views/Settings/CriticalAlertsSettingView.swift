//
//  CriticalAlertsSettingView.swift
//  ntfy
//
//  Created by Alek Michelson on 6/8/26.
//

import SwiftUI

struct CriticalAlertsSettingView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var delegate: AppDelegate
    @FetchRequest(sortDescriptors: []) private var prefs: FetchedResults<Preference>
    @State private var showingSettingsAlert = false

    private var criticalAlertsEnabled: Bool {
        prefs
            .first { $0.key == Store.prefKeyCriticalAlertsEnabled }?
            .value == "true"
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { criticalAlertsEnabled },
            set: handleToggleChanged
        )) {
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 22))

                Text("Critical Alerts")
                    .foregroundColor(.primary)
            }
        }
        .alert("Enable Critical Alerts", isPresented: $showingSettingsAlert) {
            Button("Open Notification Settings") {
                delegate.openNotificationSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Critical alerts were not allowed. You can enable them in the iOS notification settings for ntfy.")
        }
    }

    private func handleToggleChanged(_ enabled: Bool) {
        guard enabled else {
            store.saveCriticalAlertsEnabled(false)
            return
        }

        delegate.requestCriticalAlertsAuthorization { isAuthorized in
            if isAuthorized {
                store.saveCriticalAlertsEnabled(true)
            } else {
                store.saveCriticalAlertsEnabled(false)
                showingSettingsAlert = true
            }
        }
    }
}
