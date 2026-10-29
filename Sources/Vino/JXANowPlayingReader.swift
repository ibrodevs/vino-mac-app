import Foundation

/// Reads the system-wide Now Playing session by executing JXA inside Apple's
/// `/usr/bin/osascript` process.
///
/// On macOS 15.4+ direct MediaRemote reads from ordinary third-party processes
/// are commonly denied. Running the query inside a platform process keeps the
/// app credential-free while still reading the system session used by Control
/// Center. This is intentionally isolated behind this type so we can replace
/// the transport if Apple changes it again.
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

    init(onSnapshot: @escaping (Snapshot?) -> Void) {
        self.onSnapshot = onSnapshot
    }

    var isSupported: Bool {
        FileManager.default.isExecutableFile(atPath: "/usr/bin/osascript")
    }

    func start() {
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
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    func refresh() {
        queue.async { [weak self] in
            self?.poll()
        }
    }

    private func poll() {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", Self.script]
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                onSnapshot(nil)
                return
            }

            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            guard !data.isEmpty else {
                onSnapshot(nil)
                return
            }

            let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
            onSnapshot(snapshot)
        } catch {
            onSnapshot(nil)
        }
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
