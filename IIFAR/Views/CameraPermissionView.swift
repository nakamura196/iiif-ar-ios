import SwiftUI
import AVFoundation

struct CameraPermissionView: View {
    var onAuthorized: () -> Void

    var body: some View {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        VStack(spacing: 20) {
            Spacer()

            if status == .notDetermined {
                Image(systemName: "camera")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("カメラへのアクセスが必要です")
                    .font(.title3.bold())

                Text("AR機能を使用するために、カメラへのアクセスを許可してください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button("カメラを許可") {
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        DispatchQueue.main.async {
                            if granted {
                                onAuthorized()
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

            } else {
                // denied or restricted
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)

                Text("カメラへのアクセスが拒否されています")
                    .font(.title3.bold())

                Text("AR機能を使用するには、設定からカメラへのアクセスを許可してください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
    }
}
