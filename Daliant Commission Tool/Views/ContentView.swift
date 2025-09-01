import SwiftUI
import SwiftData

struct ContentView: View {
    // Single source of truth for the gate
    @Query(sort: [SortDescriptor(\Org.name)]) private var orgs: [Org]
    @State private var hasOrg: Bool = false

    var body: some View {
        Group {
            if hasOrg {
                ProjectsHomeView()   // unchanged; your existing Projects list
            } else {
                OrgOnboardingView()  // shows the “Create Organization…” sheet
            }
        }
        // Make the gate react on first display *and* whenever the list changes
        .onAppear { hasOrg = !orgs.isEmpty }
        .onChange(of: orgs.count) { _, newCount in hasOrg = newCount > 0 }
        // Optional: gentle animation when switching
        .animation(.default, value: hasOrg)
    }
}
