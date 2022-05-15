//
//  Subscription.swift
//  ntfy
//
//  Created by Philipp Heckel on 5/15/22.
//

import Foundation

extension Subscription {
    func displayName() -> String {
        return topic ?? "<unknown>"
    }
}
