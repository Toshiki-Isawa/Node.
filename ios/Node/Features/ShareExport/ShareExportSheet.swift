import SwiftUI

/// カードビューを 1:1 の画像に書き出し、共有 / 写真に保存を提供する共通シート。
/// `card` は `ShareCardRenderer` でレンダリングされるため、ブラーなど描画できない要素は避ける。
struct ShareExportSheet<Card: View>: View {
    let fileName: String
    let analyticsKind: String
    var analyticsService: AnalyticsService?
    @ViewBuilder var card: () -> Card

    @Environment(\.dismiss) private var dismiss

    @State private var previewImage: UIImage?
    @State private var exportURL: URL?
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var didFail = false

    var body: some View {
        NavigationStack {
            ZStack {
                NodeColor.graphite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: NodeSpacing.sp6) {
                        Text("画像をシェア")
                            .font(NodeFont.display(NodeFont.title1, weight: .light))
                            .foregroundStyle(NodeColor.bone)

                        preview

                        if didFail {
                            MetaLabel(text: "画像の生成に失敗しました。", color: NodeColor.syncFail)
                        }

                        if let saveMessage {
                            MetaLabel(text: "\(saveMessage)", color: NodeColor.mossSoft)
                        }

                        exportActions

                        MetaLabel(text: "1:1 · 1080px · 端末内生成", color: NodeColor.fog)
                    }
                    .padding(NodeSpacing.sp6)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(NodeColor.fog)
                }
            }
        }
        .task { await render() }
    }

    private var preview: some View {
        Group {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: NodeRadius.lg)
                            .stroke(NodeColor.hairline, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .fill(NodeColor.charcoal)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 280)
                    .overlay {
                        if !didFail {
                            ProgressView().tint(NodeColor.moss)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var exportActions: some View {
        HStack(spacing: NodeSpacing.sp3) {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("共有", systemImage: "square.and.arrow.up")
                        .font(NodeFont.text(NodeFont.callout, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(NodeColor.graphite)
                        .background(Capsule().fill(NodeColor.moss))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    analyticsService?.capture(
                        AnalyticsEvent.imageExported,
                        properties: ["kind": analyticsKind, "destination": "share"]
                    )
                })
            }

            Button {
                Task { await saveToPhotos() }
            } label: {
                Label(isSaving ? "保存中…" : "写真に保存", systemImage: "photo.badge.plus")
                    .font(NodeFont.text(NodeFont.callout, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(NodeColor.bone)
                    .background(
                        Capsule().stroke(NodeColor.moss.opacity(0.5), lineWidth: 1)
                    )
            }
            .disabled(previewImage == nil || isSaving)
        }
        .opacity(previewImage == nil ? 0.4 : 1)
    }

    @MainActor
    private func render() async {
        guard previewImage == nil else { return }
        guard let image = ShareCardRenderer.renderSquare(content: card) else {
            didFail = true
            return
        }
        previewImage = image
        exportURL = ShareCardRenderer.writeTemporaryJPEG(image, name: fileName)
        if exportURL == nil {
            didFail = true
        }
    }

    private func saveToPhotos() async {
        guard let previewImage else { return }
        isSaving = true
        saveMessage = nil
        defer { isSaving = false }

        do {
            try await ShareCardRenderer.saveToPhotos(previewImage)
            saveMessage = String(localized: "写真ライブラリに保存しました。")
            analyticsService?.capture(
                AnalyticsEvent.imageExported,
                properties: ["kind": analyticsKind, "destination": "photos"]
            )
        } catch {
            saveMessage = error.localizedDescription
        }
    }
}
