import SwiftUI

struct SettingsView: View {
    @ObservedObject var arManager: ARManager
    @ObservedObject var authManager: AuthManager
    @Binding var isGuestMode: Bool
    @Binding var isPresented: Bool
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            Form {
                // Account section
                if authManager.isLoggedIn {
                    Section("アカウント") {
                        HStack(spacing: 12) {
                            if let photoURL = authManager.photoURL {
                                AsyncImage(url: photoURL) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                if !authManager.displayName.isEmpty {
                                    Text(authManager.displayName)
                                        .font(.subheadline.bold())
                                }
                                if !authManager.email.isEmpty {
                                    Text(authManager.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Button(role: .destructive) {
                            try? authManager.signOut()
                        } label: {
                            Label(NSLocalizedString("sign_out", comment: ""), systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label(NSLocalizedString("delete_account", comment: ""), systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                } else if isGuestMode {
                    Section("アカウント") {
                        Text("ゲストモード")
                            .foregroundColor(.secondary)
                        Button {
                            isGuestMode = false
                        } label: {
                            Label("サインイン", systemImage: "person.crop.circle")
                        }
                    }
                }

                Section("表示") {
                    HStack {
                        Text("透明度")
                        Spacer()
                        Text(String(format: "%.0f%%", arManager.opacity * 100))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { arManager.opacity },
                        set: { arManager.setOpacity($0) }
                    ), in: 0.1...1.0, step: 0.05)

                    Picker("回転", selection: Binding(
                        get: { arManager.imageRotation },
                        set: { arManager.setRotation($0) }
                    )) {
                        Text("0°").tag(0.0)
                        Text("90°").tag(90.0)
                        Text("180°").tag(180.0)
                        Text("270°").tag(270.0)
                    }
                }

                #if DEBUG
                Section("デバッグ") {
                    Toggle("コーナーポール", isOn: $arManager.showCornerPoles)
                    if arManager.showCornerPoles {
                        HStack {
                            Text("ポール高さ")
                            Spacer()
                            Text(String(format: "%.1f m", arManager.poleHeight))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: Binding(
                            get: { arManager.poleHeight },
                            set: { arManager.setPoleHeight($0) }
                        ), in: 0.3...3.0, step: 0.1)
                    }

                    Toggle("床面検出の可視化", isOn: $arManager.showPlaneDetection)
                    Toggle("画像情報の表示", isOn: $arManager.showImageInfo)
                }
                #endif

                Section("床") {
                    Picker("床の種類", selection: $arManager.floorType) {
                        ForEach(ARManager.FloorType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let sample = arManager.currentSample {
                    Section("現在の画像") {
                        LabeledContent("名前", value: sample.name)
                        LabeledContent("ピクセル", value: "\(sample.pixelWidth)×\(sample.pixelHeight)")
                        LabeledContent("実寸", value: sample.sizeDescription)
                        LabeledContent("cm/px (横)", value: String(format: "%.4f", sample.cmPerPixelX))
                        LabeledContent("cm/px (縦)", value: String(format: "%.4f", sample.cmPerPixelY))
                    }
                }

                if arManager.isPlaced {
                    Section("タイル情報") {
                        LabeledContent("ズームレベル (scale factor)", value: "\(arManager.currentZoomLevel)")
                        LabeledContent("表示タイル数", value: "\(arManager.visibleTileCount)")
                        LabeledContent("読込タイル数", value: "\(arManager.loadedTileCount)")
                        LabeledContent("カメラ距離", value: String(format: "%.2fm", arManager.cameraDistance))
                    }
                }

                Section("情報") {
                    NavigationLink {
                        TipJarView()
                    } label: {
                        Label("応援する", systemImage: "heart.fill")
                    }
                    LabeledContent("バージョン", value: "1.2.0")
                    LabeledContent("IIIF API", value: "Image API 2.0")
                }

            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        isPresented = false
                    }
                }
            }
            .alert(NSLocalizedString("delete_account_title", comment: ""), isPresented: $showDeleteConfirmation) {
                Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("delete_account_confirm", comment: ""), role: .destructive) {
                    Task {
                        do {
                            try await authManager.deleteAccount()
                        } catch {
                            deleteError = error.localizedDescription
                        }
                    }
                }
            } message: {
                Text(NSLocalizedString("delete_account_message", comment: ""))
            }
            .alert(NSLocalizedString("error", comment: ""), isPresented: .init(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK") { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
        }
    }
}
