import Dispatch
import Foundation
import Darwin

/// Thin runtime bridge to macOS' private MediaRemote framework.
///
/// Vino deliberately does not link private headers or ship Yandex credentials.
/// It asks the same system Now Playing session that Control Center uses. Because
/// MediaRemote is private API, availability can vary between macOS releases.
final class MediaRemoteBridge {
    struct Snapshot {
        var title: String
        var artist: String
        var album: String
        var artworkData: Data?
        var duration: TimeInterval
        var elapsed: TimeInterval
        var playbackRate: Double
    }

    private typealias InfoCallback = @convention(block) (NSDictionary?) -> Void
    private typealias GetNowPlayingInfo = @convention(c) (DispatchQueue, InfoCallback) -> Void
    private typealias RegisterForNotifications = @convention(c) (DispatchQueue) -> Void
    private typealias SetWantsNotifications = @convention(c) (Bool) -> Void

    private let callbackQueue = DispatchQueue(label: "app.vino.mediaremote", qos: .userInitiated)
    private let onSnapshot: (Snapshot?) -> Void
    private var frameworkHandle: UnsafeMutableRawPointer?
    private var getNowPlayingInfo: GetNowPlayingInfo?
    private var observerTokens: [NSObjectProtocol] = []

    init(onSnapshot: @escaping (Snapshot?) -> Void) {
        self.onSnapshot = onSnapshot
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        guard frameworkHandle == nil else {
            refresh()
            return getNowPlayingInfo != nil
        }

        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_NOW) else {
            return false
        }

        frameworkHandle = handle
        getNowPlayingInfo = loadSymbol("MRMediaRemoteGetNowPlayingInfo", as: GetNowPlayingInfo.self)

        if let register: RegisterForNotifications = loadSymbol("MRMediaRemoteRegisterForNowPlayingNotifications", as: RegisterForNotifications.self) {
            register(callbackQueue)
        }

        if let wants: SetWantsNotifications = loadSymbol("MRMediaRemoteSetWantsNowPlayingNotifications", as: SetWantsNotifications.self) {
            wants(true)
        }

        let names = [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"
        ]

        for rawName in names {
            let token = NotificationCenter.default.addObserver(
                forName: Notification.Name(rawName),
                object: nil,
                queue: nil
            ) { [weak self] _ in
                self?.refresh()
            }
            observerTokens.append(token)
        }

        refresh()
        return getNowPlayingInfo != nil
    }

    func stop() {
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
        observerTokens.removeAll()
        getNowPlayingInfo = nil

        if let handle = frameworkHandle {
            dlclose(handle)
            frameworkHandle = nil
        }
    }

    func refresh() {
        guard let getNowPlayingInfo else {
            onSnapshot(nil)
            return
        }

        let callback: InfoCallback = { [weak self] dictionary in
            guard let self else { return }
            guard let dictionary else {
                self.onSnapshot(nil)
                return
            }

            let snapshot = Snapshot(
                title: dictionary["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "",
                artist: dictionary["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "",
                album: dictionary["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "",
                artworkData: dictionary["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data,
                duration: Self.doubleValue(dictionary["kMRMediaRemoteNowPlayingInfoDuration"]),
                elapsed: Self.doubleValue(dictionary["kMRMediaRemoteNowPlayingInfoElapsedTime"]),
                playbackRate: Self.doubleValue(dictionary["kMRMediaRemoteNowPlayingInfoPlaybackRate"])
            )

            self.onSnapshot(snapshot)
        }

        getNowPlayingInfo(callbackQueue, callback)
    }

    private func loadSymbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle = frameworkHandle, let symbol = dlsym(handle, name) else {
            return nil
        }
        return unsafeBitCast(symbol, to: T.self)
    }

    private static func doubleValue(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let double = value as? Double { return double }
        return 0
    }
}
