//
//  Helpers.swift
//  ntfy
//
//  Created by Philipp Heckel on 5/16/22.
//

import Foundation

let appBaseUrl = "http://192.168.1.4" // FIXME

func topicUrl(baseUrl: String, topic: String) -> String {
    return "\(baseUrl)/\(topic)"
}

func topicShortUrl(baseUrl: String, topic: String) -> String {
    return topicUrl(baseUrl: baseUrl, topic: topic)
        .replacingOccurrences(of: "http://", with: "")
        .replacingOccurrences(of: "https://", with: "")
}
