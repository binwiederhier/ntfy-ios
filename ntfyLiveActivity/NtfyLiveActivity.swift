import ActivityKit
import SwiftUI
import WidgetKit

@main
struct NtfyLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        NtfyLiveActivity()
    }
}

/// Lock screen and Dynamic Island UI of the Live Activity started from ntfy messages, see LiveActivityManager.
struct NtfyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NtfyActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding(16)
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivityIcon(fileName: context.state.iconFile, size: 36)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let progress = context.state.progress {
                        Text("\(Int(progress))%")
                            .font(.title3.monospacedDigit().weight(.semibold))
                    } else if context.state.ended {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if !context.state.status.isEmpty {
                            Text(context.state.status)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        if let progress = context.state.progress {
                            ProgressView(value: progress, total: 100)
                        }
                    }
                }
            } compactLeading: {
                ActivityIcon(fileName: context.state.iconFile, size: 22)
            } compactTrailing: {
                if let progress = context.state.progress {
                    Text("\(Int(progress))%")
                        .font(.caption.monospacedDigit())
                } else {
                    Text(context.state.title)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(maxWidth: 60)
                }
            } minimal: {
                if let progress = context.state.progress {
                    ProgressView(value: progress, total: 100)
                        .progressViewStyle(.circular)
                } else {
                    ActivityIcon(fileName: context.state.iconFile, size: 22)
                }
            }
        }
    }
}

private struct LockScreenView: View {
    let state: NtfyActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ActivityIcon(fileName: state.iconFile, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.headline)
                        .lineLimit(1)
                    if !state.status.isEmpty {
                        Text(state.status)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if let progress = state.progress {
                    Text("\(Int(progress))%")
                        .font(.title3.monospacedDigit().weight(.semibold))
                } else if state.ended {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
            if let progress = state.progress {
                ProgressView(value: progress, total: 100)
            }
        }
    }
}

/// The icon downloaded into the app group by the app or the notification service extension.
/// Widgets cannot load remote images, so a missing file falls back to a bell.
private struct ActivityIcon: View {
    let fileName: String?
    let size: CGFloat

    var body: some View {
        if let fileName, let url = SharedIconFiles.fileUrl(name: fileName), let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            Image(systemName: "bell.fill")
                .resizable()
                .scaledToFit()
                .padding(size * 0.2)
                .frame(width: size, height: size)
                .foregroundColor(.white)
                .background(Color(red: 0.2, green: 0.6, blue: 0.53))
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        }
    }
}
