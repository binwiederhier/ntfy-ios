//
//  Subscription.swift
//  ntfy
//
//  Created by Philipp Heckel on 5/15/22.
//

import Foundation

extension Subscription {
    func urlString() -> String {
        return topicUrl(baseUrl: baseUrl!, topic: topic!)
    }
    
    func displayName() -> String {
        return topic ?? "<unknown>"
    }
}
