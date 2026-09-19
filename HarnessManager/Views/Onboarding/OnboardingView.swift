import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.primary)
                    .symbolRenderingMode(.hierarchical)

                Text("Harness Manager")
                    .font(.largeTitle.weight(.semibold))

                Text("One place to see and manage the AI coding tools installed on your Mac.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    appState.completeOnboardingAndScan()
                } label: {
                    Text("Scan My Mac")
                        .frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 8)

                Text("Scanning is local and read-only. Harness Manager does not upload your projects, configs, processes, or credentials.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: 480, alignment: .leading)
            .padding(40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
