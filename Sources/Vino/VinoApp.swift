import AppKit
import SwiftUI

@main
struct VinoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Vino", systemImage: "record.circle") {
            MenuBarView(appModel: appDelegate.appModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appModel: appDelegate.appModel)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appModel = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        appModel.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appModel.stop()
    }
}
