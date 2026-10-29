import Foundation
import Darwin

/// Reads the active session, including artwork, through a small Objective-C
/// bridge loaded by Apple's system Perl. JXA remains a metadata-only fallback.
///
/// The transport is isolated so changes to the private MediaRemote API do not
/// affect scene rendering. Child processes have a bounded lifetime and write
/// artwork through a file rather than a capacity-limited pipe.
final class JXANowPlayingReader {
    struct Snapshot: Decodable {
        let title: String
        let artist: String
        let album: String
        let duration: Double
        let elapsed: Double
        let playbackRate: Double
        let artworkBase64: String?
        let sourceApp: String
    }

    private let queue = DispatchQueue(label: "app.vino.now-playing-jxa", qos: .utility)
    private let onSnapshot: (Snapshot?) -> Void
    private var timer: DispatchSourceTimer?

    private let queryScript: String
    private let timeout: TimeInterval
    private let artworkTransport: (script: URL, library: URL)?

    init(script: String? = nil, timeout: TimeInterval = 4,
         onSnapshot: @escaping (Snapshot?) -> Void) {
        self.artworkTransport = script == nil ? Self.findArtworkTransport() : nil
        self.queryScript = script ?? Self.script
        self.timeout = timeout
        self.onSnapshot = onSnapshot
    }

    var isSupported: Bool {
        FileManager.default.isExecutableFile(atPath: artworkTransport == nil ? "/usr/bin/osascript" : "/usr/bin/perl")
    }

    func start() {
        queue.async { [weak self] in self?.startPolling() }
    }

    private func startPolling() {
        guard timer == nil, isSupported else {
            if !isSupported { onSnapshot(nil) }
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(150))
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        queue.async { [weak self] in
            self?.timer?.setEventHandler {}
            self?.timer?.cancel()
            self?.timer = nil
        }
    }

    func refresh() {
        queue.async { [weak self] in
            self?.poll()
        }
    }

    private func poll() {
        let process = Process()
        // A file cannot fill up like a pipe while osascript writes large artwork.
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vino-now-playing-\(UUID().uuidString).json")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil),
              let output = try? FileHandle(forWritingTo: outputURL) else {
            onSnapshot(nil)
            return
        }
        defer {
            try? output.close()
            try? FileManager.default.removeItem(at: outputURL)
        }
        let finished = DispatchSemaphore(value: 0)
        if let transport = artworkTransport {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            process.arguments = [transport.script.path, transport.library.path]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", "JavaScript", "-e", queryScript]
        }
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in finished.signal() }

        do {
            try process.run()
            if finished.wait(timeout: .now() + timeout) == .timedOut {
                process.terminate()
                if finished.wait(timeout: .now() + 0.5) == .timedOut {
                    kill(process.processIdentifier, SIGKILL)
                    _ = finished.wait(timeout: .now() + 0.5)
                }
                onSnapshot(nil)
                return
            }
            guard process.terminationStatus == 0 else {
                onSnapshot(nil)
                return
            }
            let data = try Data(contentsOf: outputURL)
            onSnapshot(try JSONDecoder().decode(Snapshot.self, from: data))
        } catch {
            onSnapshot(nil)
        }
    }

    private static func findArtworkTransport() -> (script: URL, library: URL)? {
        if let script = Bundle.main.url(forResource: "read", withExtension: "pl"),
           let library = Bundle.main.privateFrameworksURL?.appendingPathComponent("VinoMediaReader.dylib"),
           FileManager.default.fileExists(atPath: library.path) {
            return (script, library)
        }
        let developmentDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/media-reader")
        let script = developmentDirectory.appendingPathComponent("read.pl")
        let library = developmentDirectory.appendingPathComponent("VinoMediaReader.dylib")
        guard FileManager.default.fileExists(atPath: script.path),
              FileManager.default.fileExists(atPath: library.path) else { return nil }
        return (script, library)
    }

    private static let script = #"""
    ObjC.import('Foundation');

    function text(value) {
        if (!value) return '';
        try {
            const unwrapped = ObjC.unwrap(value);
            return unwrapped == null ? '' : String(unwrapped);
        } catch (_) {
            return '';
        }
    }

    function number(value) {
        if (!value) return 0;
        try {
            const unwrapped = ObjC.unwrap(value);
            const n = Number(unwrapped);
            return Number.isFinite(n) ? n : 0;
        } catch (_) {
            return 0;
        }
    }

    function run() {
        const frameworkPath = '/System/Library/PrivateFrameworks/MediaRemote.framework/';
        const framework = $.NSBundle.bundleWithPath(frameworkPath);
        if (!framework || !framework.load) {
            return JSON.stringify({
                title: '', artist: '', album: '', duration: 0, elapsed: 0,
                playbackRate: 0, artworkBase64: null, sourceApp: ''
            });
        }

        const request = $.NSClassFromString('MRNowPlayingRequest');
        if (!request) {
            throw new Error('MRNowPlayingRequest is unavailable');
        }

        const item = request.localNowPlayingItem;
        const info = item ? item.nowPlayingInfo : null;
        const playerPath = request.localNowPlayingPlayerPath;
        const client = playerPath ? playerPath.client : null;
        const sourceApp = client ? text(client.displayName) : '';

        if (!info) {
            return JSON.stringify({
                title: '', artist: '', album: '', duration: 0, elapsed: 0,
                playbackRate: 0, artworkBase64: null, sourceApp: sourceApp
            });
        }

        function value(key) {
            try { return info.valueForKey(key); }
            catch (_) { return null; }
        }

        let artworkBase64 = null;
        const artwork = value('kMRMediaRemoteNowPlayingInfoArtworkData');
        if (artwork) {
            try {
                artworkBase64 = text(artwork.base64EncodedStringWithOptions(0));
                if (!artworkBase64) artworkBase64 = null;
            } catch (_) {
                artworkBase64 = null;
            }
        }

        return JSON.stringify({
            title: text(value('kMRMediaRemoteNowPlayingInfoTitle')),
            artist: text(value('kMRMediaRemoteNowPlayingInfoArtist')),
            album: text(value('kMRMediaRemoteNowPlayingInfoAlbum')),
            duration: number(value('kMRMediaRemoteNowPlayingInfoDuration')),
            elapsed: number(value('kMRMediaRemoteNowPlayingInfoElapsedTime')),
            playbackRate: number(value('kMRMediaRemoteNowPlayingInfoPlaybackRate')),
            artworkBase64: artworkBase64,
            sourceApp: sourceApp
        });
    }
    """#
}
