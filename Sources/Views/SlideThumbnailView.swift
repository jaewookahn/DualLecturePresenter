import SwiftUI
import AppKit
import PDFKit

public struct SlideThumbnailView: View {
    @ObservedObject public var model: PresenterModel
    
    public init(model: PresenterModel) {
        self.model = model
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    if let doc = model.instructorDoc {
                        ForEach(0..<doc.pageCount, id: \.self) { idx in
                            ThumbnailCell(
                                pageIndex: idx,
                                isSelected: model.currentPageIndex == idx,
                                doc: doc,
                                action: {
                                    model.goToPage(idx)
                                }
                            )
                            .id(idx)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Text("PDF 없음")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .onChange(of: model.currentPageIndex) { newIndex in
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .frame(width: 160)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct ThumbnailCell: View {
    let pageIndex: Int
    let isSelected: Bool
    let doc: PDFDocument
    let action: () -> Void
    
    @State private var thumbnailImage: NSImage?
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .aspectRatio(4/3, contentMode: .fit)
                    
                    if let image = thumbnailImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(4)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )
                .shadow(color: isSelected ? Color.accentColor.opacity(0.4) : Color.black.opacity(0.1), radius: isSelected ? 4 : 2)
                
                Text("\(pageIndex + 1)")
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        guard thumbnailImage == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let page = doc.page(at: pageIndex) else { return }
            let size = CGSize(width: 140, height: 105)
            let thumb = page.thumbnail(of: size, for: .cropBox)
            DispatchQueue.main.async {
                self.thumbnailImage = thumb
            }
        }
    }
}
