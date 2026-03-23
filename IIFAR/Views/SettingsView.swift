import SwiftUI

struct SettingsView: View {
    @ObservedObject var arManager: ARManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
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
                    LabeledContent("バージョン", value: "1.0.0")
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
        }
    }
}
