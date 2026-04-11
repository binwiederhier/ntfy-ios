//
//  AboutView.swift
//  ntfy
//
//  Created by Alek Michelson on 4/10/26.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        Group {
            Button(action: {
                open(url: "https://ntfy.sh/docs")
            }) {
                HStack {
                    Text("Read the docs")
                    Spacer()
                    Text("ntfy.sh/docs")
                        .foregroundColor(.gray)
                    Image(systemName: "link")
                }
            }
            Button(action: {
                open(url: "https://github.com/binwiederhier/ntfy/issues")
            }) {
                HStack {
                    Text("Report a bug")
                    Spacer()
                    Text("github.com")
                        .foregroundColor(.gray)
                    Image(systemName: "link")
                }
            }
            Button(action: {
                open(url: "itms-apps://itunes.apple.com/app/id1625396347")
            }) {
                HStack {
                    Text("Rate the app")
                    Spacer()
                    Text("App Store")
                        .foregroundColor(.gray)
                    Image(systemName: "star.fill")
                }
            }
            HStack {
                Text("Version")
                Spacer()
                Text("ntfy \(Config.version) (\(Config.build))")
                    .foregroundColor(.gray)
            }
        }
        .foregroundColor(.primary)
    }
    
    private func open(url: String) {
        guard let url = URL(string: url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
