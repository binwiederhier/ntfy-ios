//
//  String+Ex.swift
//  ntfy
//
//  Created by Nguyen Loc on 16/08/2023.
//

import Foundation

extension String {
    public func prepareUrlFormat() -> String {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count))
        var result = self
        if let matches = matches {
            for match in matches {
                if let url = match.url {
                    let urlStr = url.absoluteString
                    result = result.replacingOccurrences(of: urlStr, with: "[\(urlStr)](\(urlStr))")
                }
            }
            return result
        }
        return self
    }
}
