import SwiftUI
import FirebaseAuth
import GoogleSignIn

@MainActor
class AuthManager: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isLoading = true

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isLoading = false
            }
        }
    }

    var isLoggedIn: Bool { user != nil }
    var displayName: String { user?.displayName ?? "" }
    var email: String { user?.email ?? "" }
    var photoURL: URL? { user?.photoURL }

    func signInWithGoogle() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else { return }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await Auth.auth().signIn(with: credential)
    }

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    func getIdToken() async throws -> String? {
        return try await user?.getIDToken()
    }
}
