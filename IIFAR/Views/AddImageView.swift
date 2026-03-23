import SwiftUI

struct AddImageView: View {
    @ObservedObject var arManager: ARManager
    @Binding var isGalleryPresented: Bool
    @Environment(\.dismiss) private var dismiss

    // Input fields
    @State private var urlInput: String = ""
    @State private var nameInput: String = ""
    @State private var descriptionInput: String = ""
    @State private var realWidthCmInput: String = ""
    @State private var realHeightCmInput: String = ""

    // Fetched state
    @State private var imageInfo: IIIFImageInfo?
    @State private var resolvedBaseURL: String = ""
    @State private var thumbnail: UIImage?
    @State private var physicalDimensionsDetected: Bool = false
    @State private var detectedSource: String = ""

    // UI state
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                urlSection
                if let info = imageInfo {
                    infoSection(info)
                    dimensionsSection
                    previewSection
                    addButton
                }
            }
            .navigationTitle("画像を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var urlSection: some View {
        Section {
            TextField("IIIF URL（Image API または Manifest）", text: $urlInput)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await fetchInfo() }
            } label: {
                HStack {
                    Text("取得")
                    if isLoading {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        } header: {
            Text("IIIF URL")
        } footer: {
            Text("IIIF Image API のベースURL、info.json URL、または Presentation API 3.0 マニフェストURLを入力してください")
        }
    }

    private func infoSection(_ info: IIIFImageInfo) -> some View {
        Section {
            if !detectedSource.isEmpty {
                HStack {
                    Text("検出タイプ")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(detectedSource)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            LabeledContent("Base URL", value: resolvedBaseURL)
                .lineLimit(2)
                .font(.caption)
            LabeledContent("ピクセルサイズ", value: "\(info.width) x \(info.height)")
            if let tileSize = info.tileSize {
                LabeledContent("タイルサイズ", value: "\(tileSize)")
            }
            if let factors = info.scaleFactors {
                LabeledContent("スケールファクター", value: factors.map(String.init).joined(separator: ", "))
            }
            if let pw = info.physicalWidthCm, let ph = info.physicalHeightCm {
                LabeledContent("物理サイズ（検出）", value: String(format: "%.1f x %.1f cm", pw, ph))
            }
        } header: {
            Text("取得した情報")
        }
    }

    private var dimensionsSection: some View {
        Section {
            TextField("幅 (cm)", text: $realWidthCmInput)
                .keyboardType(.decimalPad)
            TextField("高さ (cm)", text: $realHeightCmInput)
                .keyboardType(.decimalPad)
            TextField("名前（任意）", text: $nameInput)
            TextField("説明（任意）", text: $descriptionInput)
        } header: {
            Text("実寸サイズ（必須）")
        } footer: {
            if physicalDimensionsDetected {
                Text("PhysicalDimension サービスから自動入力されました。手動で変更することもできます。")
            } else {
                Text("AR空間で実物大表示するための実寸サイズを cm で入力してください")
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if let thumbnail {
            Section("プレビュー") {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
            }
        }
    }

    private var addButton: some View {
        Section {
            Button {
                addToAR()
            } label: {
                HStack {
                    Spacer()
                    Label("ARで配置", systemImage: "arkit")
                        .font(.headline)
                    Spacer()
                }
            }
            .disabled(!canAdd)
        }
    }

    // MARK: - Logic

    private var canAdd: Bool {
        guard imageInfo != nil else { return false }
        guard let w = Double(realWidthCmInput), w > 0 else { return false }
        guard let h = Double(realHeightCmInput), h > 0 else { return false }
        return true
    }

    private func fetchInfo() async {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Basic URL validation
        guard let testURL = URL(string: trimmed), testURL.scheme != nil, testURL.host != nil else {
            errorMessage = "URLの形式が正しくありません"
            return
        }

        isLoading = true
        errorMessage = nil
        imageInfo = nil
        thumbnail = nil
        physicalDimensionsDetected = false
        detectedSource = ""

        do {
            let info = try await IIIFService.shared.fetchInfo(from: trimmed)
            imageInfo = info
            resolvedBaseURL = info.id

            // Detect source type for display
            if trimmed.contains("manifest") || info.physicalWidthCm != nil {
                detectedSource = "Presentation API Manifest"
            } else {
                detectedSource = "Image API"
            }

            // Auto-fill physical dimensions if available
            if let pw = info.physicalWidthCm, let ph = info.physicalHeightCm {
                realWidthCmInput = String(format: "%.1f", pw)
                realHeightCmInput = String(format: "%.1f", ph)
                physicalDimensionsDetected = true
            }

            // Load preview thumbnail
            let thumbBaseURL = info.id.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let thumbURL = thumbBaseURL + "/full/!400,400/0/default.jpg"
            if let url = URL(string: thumbURL) {
                let (data, _) = try await URLSession.shared.data(from: url)
                thumbnail = UIImage(data: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func addToAR() {
        guard let info = imageInfo,
              let widthCm = Double(realWidthCmInput),
              let heightCm = Double(realHeightCmInput) else { return }

        let sample = SampleImage(
            id: "custom_\(UUID().uuidString)",
            name: nameInput.isEmpty ? "カスタム画像" : nameInput,
            description: descriptionInput,
            detail: descriptionInput,
            sizeLabel: "カスタム",
            iiifBaseURL: resolvedBaseURL,
            pixelWidth: info.width,
            pixelHeight: info.height,
            realWidthCm: widthCm,
            realHeightCm: heightCm
        )

        dismiss()
        isGalleryPresented = false
        Task {
            await arManager.loadSample(sample)
        }
    }
}
