//
//  Bundle.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 2/15/22.
//

import Foundation

enum Configuration {

    static var appBaseUrl: String {
        string(for: "AppBaseURL")
    }

    static private func string(for key: String) -> String {
        Bundle.main.infoDictionary?[key] as! String
    }
}
