import SwiftUI

struct CollectionItemsView: View {
    let collection: PocketCollection
    @ObservedObject var arManager: ARManager
    @ObservedObject var authManager: AuthManager
    @Binding var isGalleryPresented: Bool
    @State private var items: [PocketItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var thumbnailImages: [String: UIImage] = [:]

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(NSLocalizedString("loading_collections", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await loadItems() }
                    } label: {
                        Text(NSLocalizedString("retry", comment: ""))
                            .font(.subheadline.bold())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("no_items", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                itemsList
            }
        }
        .navigationTitle(collection.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadItems()
        }
        .refreshable {
            await loadItems()
        }
    }

    private var itemsList: some View {
        List(items) { item in
            NavigationLink {
                CollectionItemDetailView(
                    item: item,
                    arManager: arManager,
                    authManager: authManager,
                    isGalleryPresented: $isGalleryPresented
                )
            } label: {
                ItemRow(item: item, thumbnail: thumbnailImages[item.id])
            }
        }
    }

    private func loadItems() async {
        isLoading = true
        errorMessage = nil
        do {
            let token = try await authManager.getIdToken()
            let client = PocketAPIClient(idToken: token)
            items = try await client.fetchItems(collectionId: collection.id)
            await loadThumbnails()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadThumbnails() async {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for item in items {
                group.addTask {
                    guard let url = item.thumbnailURL else { return (item.id, nil) }
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        let image = UIImage(data: data)
                        return (item.id, image)
                    } catch {
                        return (item.id, nil)
                    }
                }
            }
            for await (id, image) in group {
                if let image {
                    thumbnailImages[id] = image
                }
            }
        }
    }
}

private struct ItemRow: View {
    let item: PocketItem
    let thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let thumb = item.thumbnail?.first,
                   let w = thumb.width, let h = thumb.height {
                    Text("\(w) x \(h) px")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Item Detail View (fetches manifest and shows AR placement)

struct CollectionItemDetailView: View {
    let item: PocketItem
    @ObservedObject var arManager: ARManager
    @ObservedObject var authManager: AuthManager
    @Binding var isGalleryPresented: Bool
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = true
    @State private var isLoadingManifest = false
    @State private var manifest: IIIFManifest?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Thumbnail preview
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

                // AR placement button
                Button {
                    Task {
                        await placeInAR()
                    }
                } label: {
                    HStack {
                        if isLoadingManifest {
                            ProgressView()
                                .tint(.white)
                        }
                        Label(NSLocalizedString("place_in_ar", comment: ""), systemImage: "arkit")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isLoadingManifest ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoadingManifest)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // Manifest info (if loaded)
                if let manifest {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("detail_technical_info", comment: ""))
                            .font(.headline)
                            .padding(.top, 8)
                        DetailInfoRow(
                            label: NSLocalizedString("label_pixels", comment: ""),
                            value: "\(manifest.canvasWidth) x \(manifest.canvasHeight)"
                        )
                        DetailInfoRow(
                            label: NSLocalizedString("label_real_size", comment: ""),
                            value: String(
                                format: NSLocalizedString("physical_size", comment: ""),
                                formatSize(widthCm: manifest.realWidthCm, heightCm: manifest.realHeightCm)
                            )
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let url = item.thumbnailURL else {
            isLoadingThumbnail = false
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            thumbnailImage = UIImage(data: data)
        } catch {
            // Thumbnail loading is best-effort
        }
        isLoadingThumbnail = false
    }

    private func placeInAR() async {
        isLoadingManifest = true
        errorMessage = nil
        do {
            let token = try await authManager.getIdToken()
            let client = PocketAPIClient(idToken: token)
            let fetchedManifest = try await client.fetchManifest(itemId: item.id)
            manifest = fetchedManifest

            let sample = SampleImage(
                id: item.id,
                name: fetchedManifest.label,
                description: fetchedManifest.summary ?? item.displayName,
                detail: fetchedManifest.summary ?? "",
                sizeLabel: sizeLabel(for: fetchedManifest),
                iiifBaseURL: fetchedManifest.iiifServiceURL,
                pixelWidth: fetchedManifest.canvasWidth,
                pixelHeight: fetchedManifest.canvasHeight,
                realWidthCm: fetchedManifest.realWidthCm,
                realHeightCm: fetchedManifest.realHeightCm
            )

            isGalleryPresented = false
            await arManager.loadSample(sample)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingManifest = false
    }

    private func sizeLabel(for manifest: IIIFManifest) -> String {
        let maxCm = max(manifest.realWidthCm, manifest.realHeightCm)
        if maxCm < 50 {
            return NSLocalizedString("size_small", comment: "")
        } else if maxCm < 100 {
            return NSLocalizedString("size_medium", comment: "")
        } else if maxCm < 200 {
            return NSLocalizedString("size_large", comment: "")
        } else {
            return NSLocalizedString("size_extra_large", comment: "")
        }
    }

    private func formatSize(widthCm: Double, heightCm: Double) -> String {
        if widthCm >= 100 || heightCm >= 100 {
            return String(format: "%.1f x %.1f m", widthCm / 100, heightCm / 100)
        }
        return String(format: "%.1f x %.1f cm", widthCm, heightCm)
    }
}

private struct DetailInfoRow: View {
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
