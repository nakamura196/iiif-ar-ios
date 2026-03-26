import SwiftUI
import GoogleSignInSwift

struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    @Binding var isGuestMode: Bool
    @State private var errorMessage: String?
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App logo and title
            VStack(spacing: 12) {
                Image(systemName: "arkit")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                Text("IIIF AR")
                    .font(.largeTitle.bold())
                Text("歴史的な地図や図版をARで実寸表示")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Sign-in buttons
            VStack(spacing: 16) {
                // Google Sign-In button
                Button {
                    signInWithGoogle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title3)
                        Text("Googleでサインイン")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isSigningIn)

                // Guest mode button
                Button {
                    isGuestMode = true
                } label: {
                    Text("ゲストとして続ける")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .disabled(isSigningIn)

                if isSigningIn {
                    ProgressView()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
                .frame(height: 60)
        }
        .padding()
    }

    private func signInWithGoogle() {
        isSigningIn = true
        errorMessage = nil
        Task {
            do {
                try await authManager.signInWithGoogle()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}
