import SwiftUI

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore

    var body: some View {
        Text("Settings")
    }
}
