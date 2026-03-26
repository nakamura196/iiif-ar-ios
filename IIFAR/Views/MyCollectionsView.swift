import SwiftUI

struct MyCollectionsView: View {
    @ObservedObject var arManager: ARManager
    @ObservedObject var authManager: AuthManager
    @Binding var isGalleryPresented: Bool
    @State private var collections: [PocketCollection] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if !authManager.isLoggedIn {
                notLoggedInView
            } else if isLoading {
                loadingView
            } else if let errorMessage {
                errorView(errorMessage)
            } else if collections.isEmpty {
                emptyView
            } else {
                collectionsList
            }
        }
        .task {
            if authManager.isLoggedIn {
                await loadCollections()
            }
        }
        .refreshable {
            await loadCollections()
        }
    }

    private var notLoggedInView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("login_for_collections", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(NSLocalizedString("loading_collections", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await loadCollections() }
            } label: {
                Text(NSLocalizedString("retry", comment: ""))
                    .font(.subheadline.bold())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("no_collections", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var collectionsList: some View {
        List(collections) { collection in
            NavigationLink {
                CollectionItemsView(
                    collection: collection,
                    arManager: arManager,
                    authManager: authManager,
                    isGalleryPresented: $isGalleryPresented
                )
            } label: {
                CollectionRow(collection: collection)
            }
        }
    }

    private func loadCollections() async {
        isLoading = true
        errorMessage = nil
        do {
            collections = try await PocketAPIClient.shared.fetchCollections()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct CollectionRow: View {
    let collection: PocketCollection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(collection.displayName)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            if let summary = collection.displaySummary {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            if let count = collection.itemCount {
                Text(String(format: NSLocalizedString("items_count", comment: ""), count))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
