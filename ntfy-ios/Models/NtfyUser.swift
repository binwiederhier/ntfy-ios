//
//  NtfyUser.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 2/20/22.
//

import Foundation

class NtfyUser: Identifiable {
    var baseUrl: String
    var username: String
    var password: String

    init(baseUrl: String, username: String, password: String) {
        self.baseUrl = baseUrl
        self.username = username
        self.password = password
    }
}
