import SwiftUI

@main
struct DiskUsageVisualizerApp: App {
    var body: some Scene {
        WindowGroup("Disk Usage Visualizer") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
