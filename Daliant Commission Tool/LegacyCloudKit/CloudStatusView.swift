//
//  CloudStatusView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/31/25.
//

// Cloud/CloudStatusView.swift
// Step 10b — preview-friendly status view for CloudKit availability.

#if canImport(CloudKit)
import SwiftUI
import CloudKit

private final class CloudStatusModel: ObservableObject {
    @Published var status: CKAccountStatus?
    @Published var errorText: String?

    func refresh(simulated: CKAccountStatus? = nil) {
        if let sim = simulated {
            // Preview-friendly: instantly set a simulated status
            Task { @MainActor in
                self.status = sim
                self.errorText = nil
            }
            return
        }

        // Real check
        CloudConfig.container.accountStatus { status, error in
            DispatchQueue.main.async {
                self.status = status
                self.errorText = error?.localizedDescription
            }
        }
    }
}

struct CloudStatusView: View {
    @StateObject private var model = CloudStatusModel()

    /// Pass a value in previews to avoid relying on real iCloud state.
    let simulatedStatus: CKAccountStatus?

    init(simulatedStatus: CKAccountStatus? = nil) {
        self.simulatedStatus = simulatedStatus
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cloud Status").font(.headline)

            LabeledContent("Container") {
                Text(CloudConfig.containerLabel).bold()
            }
            LabeledContent("Account") {
                Text(model.status.map(statusText) ?? "…")
                    .bold()
            }

            if let e = model.errorText {
                Text("Note: \(e)").font(.footnote).foregroundStyle(.secondary)
            }

            Button("Refresh") {
                model.refresh(simulated: simulatedStatus)
            }
            .buttonStyle(.bordered)

            Text("Tip: In Canvas previews this may show “Could Not Determine” if the preview lacks iCloud access. Use the simulated preview below for a clean demo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .task { model.refresh(simulated: simulatedStatus) }
    }
}

private func statusText(_ s: CKAccountStatus) -> String {
    switch s {
    case .available:          return "Available"
    case .noAccount:          return "No iCloud account"
    case .restricted:         return "Restricted"
    case .couldNotDetermine:  return "Could Not Determine"
    @unknown default:         return "Unknown"
    }
}

// MARK: - Previews

#Preview("Cloud Status (simulated: Available)") {
    CloudStatusView(simulatedStatus: .available)
}

#Preview("Cloud Status (simulated: No Account)") {
    CloudStatusView(simulatedStatus: .noAccount)
}

#Preview("Cloud Status (live)") {
    // This attempts a real accountStatus() call; okay if it shows “Could Not Determine” in Canvas.
    CloudStatusView()
}
#endif
