import SwiftUI

/// Unified detail view for both sample images and Pocket collection items.
/// Shows thumbnail, metadata, physical dimensions, attribution, and AR placement button.
struct ImageDetailView: View {
    // One of these will be set
    let sample: SampleImage?
    let pocketItem: PocketItem?

    @ObservedObject var arManager: ARManager
    @Binding var isGalleryPresented: Bool

    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = true
    @State private var isLoadingMetadata = false
    @State private var isPlacingAR = false
    @State private var manifest: IIIFManifest?
    @State private var errorMessage: String?

    // Convenience initializer for sample images (backward compatible)
    init(sample: SampleImage, arManager: ARManager, isGalleryPresented: Binding<Bool>) {
        self.sample = sample
        self.pocketItem = nil
        self.arManager = arManager
        self._isGalleryPresented = isGalleryPresented
    }

    // Initializer for Pocket collection items
    init(pocketItem: PocketItem, arManager: ARManager, isGalleryPresented: Binding<Bool>) {
        self.sample = nil
        self.pocketItem = pocketItem
        self.arManager = arManager
        self._isGalleryPresented = isGalleryPresented
    }

    private var displayName: String {
        sample?.name ?? pocketItem?.displayName ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Thumbnail
                thumbnailSection

                // AR placement button
                arButton

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // Description / Summary
                descriptionSection

                // Metadata from manifest
                if isLoadingMetadata {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let manifest {
                    metadataSection(manifest)
                }

                // Technical info (from sample or manifest)
                technicalInfoSection
            }
            .padding()
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadThumbnail()
            if pocketItem != nil {
                await loadManifest()
            }
        }
    }

    // MARK: - Thumbnail

    private var thumbnailSection: some View {
        Group {
            if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
            } else if isLoadingThumbnail {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
    }

    // MARK: - AR Button

    private var arButton: some View {
        Button {
            Task { await placeInAR() }
        } label: {
            HStack {
                if isPlacingAR {
                    ProgressView().tint(.white)
                }
                Label(NSLocalizedString("place_in_ar", comment: ""), systemImage: "arkit")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isPlacingAR ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isPlacingAR)
    }

    // MARK: - Description

    private var descriptionSection: some View {
        Group {
            if let sample {
                if !sample.description.isEmpty {
                    Text(sample.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if !sample.detail.isEmpty {
                    Text(sample.detail)
                        .font(.body)
                }
            } else if let summary = pocketItem?.summary ?? manifest?.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Metadata

    private func metadataSection(_ manifest: IIIFManifest) -> some View {
        Group {
            if !manifest.metadata.isEmpty || manifest.attribution != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("detail_metadata", comment: ""))
                        .font(.headline)
                        .padding(.top, 8)

                    ForEach(manifest.metadata, id: \.label) { entry in
                        InfoRow(label: entry.label, value: entry.value)
                    }

                    if let attribution = manifest.attribution {
                        InfoRow(
                            label: NSLocalizedString("label_attribution", comment: ""),
                            value: attribution
                        )
                    }

                    if let rights = manifest.rights {
                        InfoRow(
                            label: NSLocalizedString("label_rights", comment: ""),
                            value: rights
                        )
                    }
                }
            }
        }
    }

    // MARK: - Technical Info

    private var technicalInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("detail_technical_info", comment: ""))
                .font(.headline)
                .padding(.top, 8)

            if let sample {
                if !sample.sizeLabel.isEmpty {
                    HStack {
                        Text(sample.sizeLabel)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(sizeLabelColor(sample.sizeLabel))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        Text(sample.sizeDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                InfoRow(label: NSLocalizedString("label_real_size", comment: ""),
                        value: sample.sizeDescription)
                InfoRow(label: NSLocalizedString("label_pixels", comment: ""),
                        value: "\(sample.pixelWidth) x \(sample.pixelHeight)")
            } else if let manifest {
                InfoRow(label: NSLocalizedString("label_real_size", comment: ""),
                        value: formatSize(widthCm: manifest.realWidthCm, heightCm: manifest.realHeightCm))
                InfoRow(label: NSLocalizedString("label_pixels", comment: ""),
                        value: "\(manifest.canvasWidth) x \(manifest.canvasHeight)")
            }
        }
    }

    // MARK: - Actions

    private func loadThumbnail() async {
        if let sample {
            let img = await IIIFService.shared.fetchThumbnail(from: sample)
            thumbnailImage = img
        } else if let urlString = pocketItem?.thumbnailURL, let url = URL(string: urlString) {
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                thumbnailImage = UIImage(data: data)
            }
        }
        isLoadingThumbnail = false
    }

    private func loadManifest() async {
        guard let pocketItem else { return }
        isLoadingMetadata = true
        do {
            manifest = try await PocketAPIClient.shared.fetchManifest(manifestURL: pocketItem.manifestURL)
        } catch {
            // Non-fatal: metadata just won't show
        }
        isLoadingMetadata = false
    }

    private func placeInAR() async {
        if let sample {
            isGalleryPresented = false
            await arManager.loadSample(sample)
        } else if let pocketItem {
            isPlacingAR = true
            errorMessage = nil
            do {
                let fetchedManifest: IIIFManifest
                if let m = manifest {
                    fetchedManifest = m
                } else {
                    fetchedManifest = try await PocketAPIClient.shared.fetchManifest(manifestURL: pocketItem.manifestURL)
                    manifest = fetchedManifest
                }
                let sampleImage = await PocketAPIClient.shared.manifestToSampleImage(
                    manifest: fetchedManifest, itemId: pocketItem.id
                )
                isGalleryPresented = false
                await arManager.loadSample(sampleImage)
            } catch {
                errorMessage = error.localizedDescription
            }
            isPlacingAR = false
        }
    }

    // MARK: - Helpers

    private func sizeLabelColor(_ label: String) -> Color {
        switch label {
        case "小": return .green
        case "中": return .orange
        case "大": return .red
        default: return .gray
        }
    }

    private func formatSize(widthCm: Double, heightCm: Double) -> String {
        if widthCm >= 100 || heightCm >= 100 {
            return String(format: "%.1f x %.1f m", widthCm / 100, heightCm / 100)
        }
        return String(format: "%.1f x %.1f cm", widthCm, heightCm)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.callout)
    }
}
