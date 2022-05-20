import SwiftUI

struct NotificationRowView: View {
    let notification: Notification

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(notification.title ?? "")
                    .font(.headline)
                    .bold()
                    .lineLimit(1)
                Spacer()
                Text(notification.shortDateTime())
                    .font(.subheadline)
                    .foregroundColor(.gray)

            }
            Spacer()
            Text(notification.message ?? "")
                .font(.body)
        }
        .padding(.all, 4)
    }
}
