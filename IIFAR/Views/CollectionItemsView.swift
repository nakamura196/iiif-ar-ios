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
                ImageDetailView(
                    pocketItem: item,
                    arManager: arManager,
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
            let userId = authManager.user?.uid ?? ""
            items = try await PocketAPIClient.shared.fetchItems(
                collectionId: collection.id,
                userId: userId
            )
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
                    guard let urlString = item.thumbnailURL,
                          let url = URL(string: urlString) else {
                        return (item.id, nil)
                    }
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
                if let summary = item.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// CollectionItemDetailView removed — now using shared ImageDetailView
