import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var arManager = ARManager()
    @StateObject private var authManager = AuthManager()
    @State private var showingGallery = true
    @State private var showingSettings = false
    @State private var cameraAuthorized = false
    @State private var isGuestMode = false

    var body: some View {
        Group {
            if authManager.isLoading {
                ProgressView()
            } else if authManager.isLoggedIn || isGuestMode {
                mainContentView
            } else {
                LoginView(authManager: authManager, isGuestMode: $isGuestMode)
            }
        }
    }

    private var mainContentView: some View {
        Group {
            if cameraAuthorized {
                arContentView
            } else {
                CameraPermissionView {
                    cameraAuthorized = true
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    checkCameraAuthorization()
                }
            }
        }
        .onAppear {
            checkCameraAuthorization()
        }
    }

    private func checkCameraAuthorization() {
        cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    private var arContentView: some View {
        ZStack {
            ARViewContainer(arManager: arManager)
                .ignoresSafeArea()

            VStack {
                // Top info bar
                if arManager.showImageInfo, let info = arManager.placedImageInfo {
                    Text(info)
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.top, 60)
                }

                Spacer()

                // Status messages
                if arManager.isLoading {
                    ProgressView("画像を取得中...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(.bottom, 8)
                }

                if !arManager.planeDetected {
                    Text("デバイスをゆっくり動かして床面を検出してください...")
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.bottom, 4)
                } else if arManager.currentImage != nil && !arManager.isPlaced {
                    Text("床面をタップして画像を配置")
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.bottom, 4)
                }

                // Quick opacity slider (shown after placement)
                if arManager.isPlaced {
                    HStack {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                        Slider(value: Binding(
                            get: { arManager.opacity },
                            set: { arManager.setOpacity($0) }
                        ), in: 0.1...1.0, step: 0.05)
                        Image(systemName: "eye")
                            .font(.caption2)
                        Text(String(format: "%.0f%%", arManager.opacity * 100))
                            .font(.caption2.monospacedDigit())
                            .frame(width: 36)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                    // Rotation preset buttons
                    HStack(spacing: 8) {
                        Image(systemName: "rotate.right")
                            .font(.caption2)
                        ForEach([0.0, 90.0, 180.0, 270.0], id: \.self) { deg in
                            Button {
                                arManager.setRotation(deg)
                            } label: {
                                Text("\(Int(deg))°")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(arManager.imageRotation == deg ? Color.accentColor : Color.clear)
                                    .foregroundColor(arManager.imageRotation == deg ? .white : .primary)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
                }

                // Bottom toolbar
                HStack(spacing: 12) {
                    Button {
                        showingGallery = true
                    } label: {
                        Label("一覧", systemImage: "photo.on.rectangle")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.subheadline.bold())
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }

                    if arManager.currentImage != nil {
                        Button {
                            arManager.removeAllImages()
                        } label: {
                            Image(systemName: "trash")
                                .font(.subheadline.bold())
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingGallery) {
            GalleryView(arManager: arManager, authManager: authManager, isPresented: $showingGallery)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(arManager: arManager, authManager: authManager, isGuestMode: $isGuestMode, isPresented: $showingSettings)
        }
    }
}
