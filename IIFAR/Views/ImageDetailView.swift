import SwiftUI

struct ImageDetailView: View {
    let sample: SampleImage
    @ObservedObject var arManager: ARManager
    @Binding var isGalleryPresented: Bool
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Image preview
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                    } else if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }

                // AR placement button - prominent
                Button {
                    isGalleryPresented = false
                    Task {
                        await arManager.loadSample(sample)
                    }
                } label: {
                    Label("ARで配置", systemImage: "arkit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                // Size badge
                HStack {
                    Text(sample.sizeLabel)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(sizeLabelColor)
                        .foregroundColor(.white)
                        .cornerRadius(6)

                    Text(sample.sizeDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Description
                Text(sample.detail)
                    .font(.body)

                // Technical info
                VStack(alignment: .leading, spacing: 8) {
                    Text("技術情報")
                        .font(.headline)
                        .padding(.top, 8)
                    InfoRow(label: "ピクセル", value: "\(sample.pixelWidth)×\(sample.pixelHeight)")
                    InfoRow(label: "実寸", value: sample.sizeDescription)
                    InfoRow(label: "cm/px (横)", value: String(format: "%.4f", sample.cmPerPixelX))
                    InfoRow(label: "cm/px (縦)", value: String(format: "%.4f", sample.cmPerPixelY))
                }
            }
            .padding()
        }
        .navigationTitle(sample.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let img = await IIIFService.shared.fetchThumbnail(from: sample)
            image = img
            isLoading = false
        }
    }

    private var sizeLabelColor: Color {
        switch sample.sizeLabel {
        case "小": return .green
        case "中": return .orange
        case "大": return .red
        default: return .gray
        }
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
