import SwiftUI

@main
struct EasyTimeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(commute: .officeFixture)
        }
    }
}
