import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var wallpaperEnabled = true

    let nowPlaying = NowPlayingService()
    private let wallpaperController = WallpaperController()

    func start() {
        nowPlaying.start()
        if wallpaperEnabled {
            wallpaperController.start(nowPlaying: nowPlaying)
        }
    }

    func stop() {
        wallpaperController.stop()
        nowPlaying.stop()
    }

    func setWallpaperEnabled(_ enabled: Bool) {
        wallpaperEnabled = enabled
        if enabled {
            wallpaperController.start(nowPlaying: nowPlaying)
        } else {
            wallpaperController.stop()
        }
    }

    func refreshNowPlaying() {
        nowPlaying.refresh()
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
