import Foundation

@MainActor
final class NowPlayingService: ObservableObject {
    enum ConnectionState: Equatable {
        case starting
        case connected
        case unavailable

        var label: String {
            switch self {
            case .starting: return "Connecting to macOS Now Playing…"
            case .connected: return "Connected to macOS Now Playing"
            case .unavailable: return "Now Playing is unavailable on this macOS build"
            }
        }
    }

    @Published private(set) var track: NowPlayingTrack = .idle
    @Published private(set) var connectionState: ConnectionState = .starting

    private var bridge: MediaRemoteBridge?

    func start() {
        guard bridge == nil else {
            refresh()
            return
        }

        connectionState = .starting
        let newBridge = MediaRemoteBridge { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.apply(snapshot)
            }
        }
        bridge = newBridge
        connectionState = newBridge.start() ? .connected : .unavailable
    }

    func stop() {
        bridge?.stop()
        bridge = nil
    }

    func refresh() {
        bridge?.refresh()
    }

    private func apply(_ snapshot: MediaRemoteBridge.Snapshot?) {
        guard let snapshot else {
            track = .idle
            return
        }

        track = NowPlayingTrack(
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            artworkData: snapshot.artworkData,
            duration: snapshot.duration,
            elapsed: snapshot.elapsed,
            playbackRate: snapshot.playbackRate,
            updatedAt: .now
        )
    }
}
