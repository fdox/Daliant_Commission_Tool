import SwiftUI

struct SignInView: View {
    var onSignedIn: (_ userId: String, _ displayName: String?) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 56))
            Text("Daliant Commission Tool")
                .font(.title.bold())
            Text("Sign in placeholder — tap Continue to proceed.")
                .foregroundStyle(.secondary)
            Button("Continue") {
                onSignedIn(UUID().uuidString, "Tester")
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
        .padding()
    }
}

#if DEBUG
import SwiftData

#Preview("Sign In – Basic") {
    // If SignInView needs a model container, uncomment below:
    /*
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Org.self, Item.self, configurations: config)
    return SignInView().modelContainer(container)
    */
    return SignInView()
}
#endif
