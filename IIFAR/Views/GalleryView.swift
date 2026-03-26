import SwiftUI

struct GalleryView: View {
    @ObservedObject var arManager: ARManager
    @ObservedObject var authManager: AuthManager
    @Binding var isPresented: Bool
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var showingAddImage = false
    @State private var selectedTab: GalleryTab = .samples

    private enum GalleryTab: String, CaseIterable {
        case samples
        case myCollections

        var label: String {
            switch self {
            case .samples:
                return NSLocalizedString("samples", comment: "")
            case .myCollections:
                return NSLocalizedString("my_collections", comment: "")
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("", selection: $selectedTab) {
                    ForEach(GalleryTab.allCases, id: \.self) { tab in
                        Text(tab.label).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Tab content
                switch selectedTab {
                case .samples:
                    samplesListView
                case .myCollections:
                    MyCollectionsView(
                        arManager: arManager,
                        authManager: authManager,
                        isGalleryPresented: $isPresented
                    )
                }
            }
            .navigationTitle(NSLocalizedString("gallery_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("gallery_close", comment: "")) { isPresented = false }
                }
                if selectedTab == .samples {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingAddImage = true
                        } label: {
                            Label("画像を追加", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddImage) {
                AddImageView(arManager: arManager, isGalleryPresented: $isPresented)
            }
        }
        .task {
            await loadThumbnails()
        }
    }

    private var samplesListView: some View {
        List {
            ForEach(SampleImage.samples) { sample in
                NavigationLink {
                    ImageDetailView(
                        sample: sample,
                        arManager: arManager,
                        isGalleryPresented: $isPresented
                    )
                } label: {
                    SampleRow(sample: sample, thumbnail: thumbnails[sample.id])
                }
            }
        }
    }

    private func loadThumbnails() async {
        thumbnails = await IIIFService.shared.fetchAllThumbnails(from: SampleImage.samples)
    }
}

private struct SampleRow: View {
    let sample: SampleImage
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
                ProgressView()
                    .frame(width: 80, height: 80)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(sample.sizeLabel)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sizeLabelColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)

                    Text(sample.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }

                Text(sample.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text("\(sample.pixelWidth)×\(sample.pixelHeight)px → \(sample.sizeDescription)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var sizeLabelColor: Color {
        switch sample.sizeLabel {
        case "小": return .green
        case "中": return .orange
        case "大": return .red
        case "特大": return .purple
        default: return .gray
        }
    }
}
