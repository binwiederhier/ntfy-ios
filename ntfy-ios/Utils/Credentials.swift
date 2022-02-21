//
//  Credentials.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 2/20/22.
//

import Foundation

enum Credentials {
    static func Basic(username: String, password: String) -> String {
        return String(format: "%@:%@", username, password).data(using: String.Encoding.utf8)!.base64EncodedString()
    }
}
