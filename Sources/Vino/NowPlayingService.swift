import Combine
import Foundation

@MainActor
final class NowPlayingService: ObservableObject {
    enum ConnectionState: Equatable {
        case starting
        case connected(source: String)
        case unavailable

        var label: String {
            switch self {
            case .starting:
                return "Connecting to macOS Now Playing…"
            case .connected(let source):
                return source.isEmpty ? "Connected to macOS Now Playing" : "Connected · \(source)"
            case .unavailable:
                return "Now Playing is unavailable on this macOS build"
            }
        }

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
    }

    @Published private(set) var track: NowPlayingTrack = .idle
    @Published private(set) var connectionState: ConnectionState = .starting

    private var reader: JXANowPlayingReader?

    func start() {
        guard reader == nil else {
            refresh()
            return
        }

        connectionState = .starting
        let newReader = JXANowPlayingReader { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.apply(snapshot)
            }
        }

        reader = newReader
        guard newReader.isSupported else {
            connectionState = .unavailable
            return
        }
        newReader.start()
    }

    func stop() {
        reader?.stop()
        reader = nil
    }

    func refresh() {
        reader?.refresh()
    }

    private func apply(_ snapshot: JXANowPlayingReader.Snapshot?) {
        guard let snapshot else {
            connectionState = .unavailable
            return
        }

        connectionState = .connected(source: snapshot.sourceApp)
        let artworkData = snapshot.artworkBase64.flatMap { Data(base64Encoded: $0) }

        track = NowPlayingTrack(
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            artworkData: artworkData,
            duration: snapshot.duration,
            elapsed: snapshot.elapsed,
            playbackRate: snapshot.playbackRate,
            updatedAt: .now
        )
    }
}
