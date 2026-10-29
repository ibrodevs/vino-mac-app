import AppKit
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

    @Published private(set) var artwork: NSImage?
    @Published private(set) var previousArtwork: NSImage?
    private var artworkBytes: Data?
    private var trackIdentity = ""
    private var generation = 0

    private var reader: JXANowPlayingReader?

    func start() {
        guard reader == nil else {
            refresh()
            return
        }

        connectionState = .starting
        generation += 1
        let currentGeneration = generation
        let newReader = JXANowPlayingReader { [weak self] snapshot in
            DispatchQueue.main.async {
                guard let self, self.generation == currentGeneration else { return }
                self.apply(snapshot)
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
        generation += 1
        reader?.stop()
        reader = nil
    }

    func refresh() {
        reader?.refresh()
    }

    func apply(_ snapshot: JXANowPlayingReader.Snapshot?) {
        guard let snapshot else {
            connectionState = .unavailable
            return
        }

        connectionState = .connected(source: snapshot.sourceApp)
        let identity = "\(snapshot.sourceApp)|\(snapshot.title)|\(snapshot.artist)|\(snapshot.album)"
        let changedTrack = identity != trackIdentity
        let incoming = snapshot.artworkBase64.flatMap { Data(base64Encoded: $0) }
        if changedTrack {
            if let artwork { previousArtwork = artwork }
            artwork = nil
            artworkBytes = nil
            trackIdentity = identity
        }
        // Some players omit artwork on intermediate polls of the same song.
        if let incoming, incoming != artworkBytes, let decoded = NSImage(data: incoming) {
            artwork = decoded
            artworkBytes = incoming
        }
        let artworkData = artworkBytes

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
