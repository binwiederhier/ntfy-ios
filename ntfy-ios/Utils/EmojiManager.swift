//
//  EmojiManager.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 2/10/22.
//

import Foundation

struct Emoji: Decodable {
    let emoji: String
    let aliases: [String]
    let tags: [String]

    func getUnicode() -> String {
        return emoji
    }
}

class EmojiManager {
    private static var emojis: Dictionary<String, Emoji> = [:]

    static let current = EmojiManager()

    init() {
        // emojis.json pulled from https://github.com/github/gemoji/blob/master/db/emoji.json
        if let url = Bundle.main.url(forResource: "emojis", withExtension: "json") {
            do {
                let jsonData = try Data(contentsOf: url)
                if let jsonEmojis = try? JSONDecoder().decode([Emoji].self, from: jsonData) {
                    for emoji in jsonEmojis {
                        if !emoji.aliases.isEmpty {
                            EmojiManager.emojis[emoji.aliases.first!] = emoji
                        }
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func getEmojiByAlias(alias: String) -> Emoji? {
        if alias.isEmpty {
            return nil
        }

        return EmojiManager.emojis[alias]
    }
}
