import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var nowPlaying: NowPlayingService

    init(appModel: AppModel) {
        self.appModel = appModel
        self.nowPlaying = appModel.nowPlaying
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vino")
                        .font(.headline)
                    Text(nowPlaying.track.hasTrack ? nowPlaying.track.title : "Waiting for music")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Divider()

            Toggle(
                "Live wallpaper",
                isOn: Binding(
                    get: { appModel.wallpaperEnabled },
                    set: { appModel.setWallpaperEnabled($0) }
                )
            )

            Button("Refresh Now Playing") {
                appModel.refreshNowPlaying()
            }

            Text(nowPlaying.connectionState.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button("Quit Vino") {
                appModel.quit()
            }
            .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 270)
    }
}

struct SettingsView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var nowPlaying: NowPlayingService

    init(appModel: AppModel) {
        self.appModel = appModel
        self.nowPlaying = appModel.nowPlaying
    }

    var body: some View {
        Form {
            Toggle(
                "Show Vino as the desktop wallpaper",
                isOn: Binding(
                    get: { appModel.wallpaperEnabled },
                    set: { appModel.setWallpaperEnabled($0) }
                )
            )

            LabeledContent("Now Playing") {
                Text(nowPlaying.connectionState.label)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
