// focusmaxxing hub simulator harness: a stand-in for the helper, installed on the simulator only.
// it declares the localdevvpn:// scheme (project.yml), which is all the Hub's first run checks.
import SwiftUI

@main
struct HelperStandIn: App {
    @State private var lastURL = "no link yet"

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("sim harness: helper stand-in")
                Text(lastURL).font(.footnote)
            }
            .onOpenURL { url in
                lastURL = url.absoluteString
            }
        }
    }
}
