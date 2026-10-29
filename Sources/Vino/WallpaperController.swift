import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class WallpaperController {
    private var windows: [NSWindow] = []
    private weak var nowPlaying: NowPlayingService?
    private var screenObserver: NSObjectProtocol?

    func start(nowPlaying: NowPlayingService) {
        self.nowPlaying = nowPlaying
        rebuildWindows()

        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.rebuildWindows()
            }
        }
    }

    func stop() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }

    private func rebuildWindows() {
        guard let nowPlaying else { return }

        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()

        let desktopLevel = Int(CGWindowLevelForKey(.desktopWindow)) + 1

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            window.setFrame(screen.frame, display: true)
            window.level = NSWindow.Level(rawValue: desktopLevel)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: WallpaperView(nowPlaying: nowPlaying))
            window.orderFrontRegardless()

            windows.append(window)
        }
    }
}
