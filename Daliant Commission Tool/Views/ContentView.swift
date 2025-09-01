import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Org.createdAt, order: .forward)]) private var orgs: [Org]
    @AppStorage("signedInUserID") private var signedInUserID: String = ""

    var body: some View {
        NavigationStack {
            if signedInUserID.isEmpty {
                SignInView { userId, _ in
                    signedInUserID = userId
                }
            } else if orgs.isEmpty {
                OrgOnboardingView()
            } else {
                ProjectsHomeView()
            }
        }
    }
}