import AppKit
import SwiftUI

struct PresenterView: View {
    @ObservedObject var model: PresenterModel
    @State private var pageHeights: [Int: CGFloat] = [:]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: NSColor(calibratedWhite: 0.055, alpha: 0.97)))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }

            VStack(spacing: 0) {
                header
                Divider().overlay(Color.white.opacity(0.12))
                document
                Divider().overlay(Color.white.opacity(0.12))
                controls
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let preview = model.capturePreview {
                capturePreview(preview)
            }
        }
        .padding(10)
        .background(Color.clear)
        .onChange(of: model.opacity) { _ in model.applyWindowSettings() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
                .shadow(color: .orange.opacity(0.6), radius: 5)
            VStack(alignment: .leading, spacing: 2) {
                Text("PRIVATE PRESENTER")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                Text(model.documentName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(model.statusMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Button("Paste into Page") { model.pasteIntoCurrentPage() }
                .controlSize(.small)
                .help("Append clipboard text to the selected page")
            Button("Add Page") { model.addPage() }
                .controlSize(.small)
            Button("Save") { model.saveDocument() }
                .controlSize(.small)
            Button("Open…") { model.openDocument() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
    }

    private var document: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("CONTINUOUS DOCUMENT · PAGE \(model.currentPage + 1)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        formattingToolbar
                    }
                    .padding(.horizontal, 24)
                    .frame(height: 42)

                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            ForEach(model.pages.indices, id: \.self) { index in
                                continuousPage(index)
                                    .id(index)
                                    .background {
                                        GeometryReader { geometry in
                                            Color.clear.preference(
                                                key: PagePositionPreferenceKey.self,
                                                value: [index: geometry.frame(in: .named("continuousDocument")).minY]
                                            )
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    .coordinateSpace(name: "continuousDocument")
                    .onPreferenceChange(PagePositionPreferenceKey.self) { positions in
                        guard let closest = positions.min(by: {
                            abs($0.value - 12) < abs($1.value - 12)
                        })?.key else { return }
                        model.setVisiblePage(closest)
                    }
                    .onChange(of: model.requestedScrollPage) { requestedPage in
                        guard let requestedPage else { return }
                        proxy.scrollTo(requestedPage, anchor: .top)
                        model.consumeScrollRequest()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().overlay(Color.white.opacity(0.12))
                pageSidebar { index in
                    model.jump(to: index)
                    proxy.scrollTo(index, anchor: .top)
                    model.consumeScrollRequest()
                }
            }
        }
    }

    private func continuousPage(_ index: Int) -> some View {
        AttributedTextView(
            content: model.pages[index],
            scale: model.fontScale,
            scrollEnabled: false,
            onChange: { model.updatePage(at: index, content: $0) },
            onFocus: { model.setVisiblePage(index) },
            onHeightChange: { height in
                if abs((pageHeights[index] ?? 0) - height) > 1 {
                    pageHeights[index] = height
                }
            }
        )
        .frame(height: pageHeights[index] ?? 72)
        .overlay(alignment: .topLeading) {
            if model.pages[index].length == 0 {
                Text("Type here, or paste with Command-V…")
                    .font(.system(size: 18))
                    .foregroundStyle(.tertiary)
                    .allowsHitTesting(false)
                    .padding(.top, 12)
                    .padding(.leading, 8)
            }
        }
    }

    private var formattingToolbar: some View {
        HStack(spacing: 3) {
            formatButton("bold", help: "Bold — Command-B") { model.toggleBold() }
            formatButton("italic", help: "Italic — Command-I") { model.toggleItalic() }
            formatButton("underline", help: "Underline — Command-U") { model.toggleUnderline() }
            Divider().frame(height: 18).padding(.horizontal, 3)
            formatButton("textformat.size.smaller", help: "Decrease selected text size") {
                model.changeFontSize(by: -2)
            }
            formatButton("textformat.size.larger", help: "Increase selected text size") {
                model.changeFontSize(by: 2)
            }
            Divider().frame(height: 18).padding(.horizontal, 3)
            formatButton("text.alignleft", help: "Align left") { model.align(.left) }
            formatButton("text.aligncenter", help: "Align center") { model.align(.center) }
            formatButton("text.alignright", help: "Align right") { model.align(.right) }
        }
    }

    private func formatButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 22, height: 20)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .help(help)
    }

    private func pageSidebar(onSelect: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("PAGES")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { model.addPage() } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("Add Page — Command-Shift-N")
            }
            .padding(.horizontal, 14)
            .frame(height: 40)

            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(model.pages.indices, id: \.self) { index in
                        Button { onSelect(index) } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(index == model.currentPage ? Color.black : Color.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(index == model.currentPage ? Color.white : Color.white.opacity(0.08))
                                    .clipShape(Circle())
                                Text(model.pagePreview(at: index))
                                    .font(.system(size: 11))
                                    .foregroundStyle(index == model.currentPage ? Color.white : Color.secondary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
                            .background(index == model.currentPage ? Color.white.opacity(0.12) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            pageActions(at: index)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            Divider().overlay(Color.white.opacity(0.1))
            Button { model.addPage() } label: {
                Label("New page", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(12)
            Menu("Page actions") {
                pageActions(at: model.currentPage)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 176)
        .background(Color.black.opacity(0.16))
    }

    @ViewBuilder
    private func pageActions(at index: Int) -> some View {
        Button("Duplicate Page") { model.duplicatePage(at: index) }
        Button("Clear Page Text") { model.clearPage(at: index) }
        Divider()
        Button("Delete Page", role: .destructive) { model.deletePage(at: index) }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button { model.previousPage() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(model.currentPage == 0 || model.pages.isEmpty)

            Text(model.pageLabel)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(minWidth: 70)

            Button { model.nextPage() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(model.pages.isEmpty || model.currentPage >= model.pages.count - 1)

            Divider().frame(height: 18)

            Image(systemName: "textformat.size.smaller")
            Slider(value: $model.fontScale, in: 0.7...1.7, step: 0.05)
                .frame(width: 100)
            Image(systemName: "textformat.size.larger")

            Divider().frame(height: 18)

            Image(systemName: "circle.lefthalf.filled")
            Slider(value: $model.opacity, in: 0.35...1.0, step: 0.05)
                .frame(width: 90)

            Spacer()

            Menu("Document") {
                Button("Clean Formatting — All Pages") { model.cleanAllFormatting() }
                Divider()
                Button("Clear All…", role: .destructive) { model.confirmClearAll() }
            }
            .fixedSize()
            .help("Clean formatting or clear the entire document")

            Button("Local Capture Test") { model.runCaptureTest() }
                .controlSize(.small)

            Button { model.deleteCurrentPage() } label: {
                Image(systemName: "trash")
            }
            .controlSize(.small)
            .help("Delete selected page")

        }
        .padding(.horizontal, 18)
        .frame(height: 54)
    }

    private func capturePreview(_ image: NSImage) -> some View {
        ZStack {
            Color.black.opacity(0.88)
            VStack(spacing: 14) {
                Text("Local Legacy-Capture Test")
                    .font(.title2.bold())
                Text("This preview exercises an older macOS capture path only. Even if the overlay is absent here, it may still appear in Zoom, Meet, Teams, or modern whole-display capture. Verify with a private call using the exact app and sharing mode.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2)))
                    .padding(.horizontal, 30)
                    .frame(maxHeight: 390)
                Button("Done") { model.closeCapturePreview() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(10)
    }
}

struct AttributedTextView: NSViewRepresentable {
    let content: NSAttributedString
    let scale: Double
    var scrollEnabled = true
    let onChange: (NSAttributedString) -> Void
    var onFocus: () -> Void = {}
    var onHeightChange: (CGFloat) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, onFocus: onFocus, onHeightChange: onHeightChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = scrollEnabled
        scroll.autohidesScrollers = true
        scroll.verticalScrollElasticity = scrollEnabled ? .automatic : .none

        let textView = FormattingTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = !scrollEnabled
        textView.autoresizingMask = [.width]
        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        context.coordinator.scale = scale
        (textView as? FormattingTextView)?.presentationScale = scale
        let displayed = NSMutableAttributedString(attributedString: content)
        let fullRange = NSRange(location: 0, length: displayed.length)
        displayed.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            let font = (value as? NSFont) ?? NSFont.systemFont(ofSize: 20)
            displayed.addAttribute(
                .font,
                value: NSFontManager.shared.convert(font, toSize: font.pointSize * scale),
                range: range
            )
        }
        if textView.attributedString().isEqual(to: displayed) == false {
            context.coordinator.isApplyingModelChange = true
            textView.textStorage?.setAttributedString(displayed)
            textView.scrollToBeginningOfDocument(nil)
            context.coordinator.isApplyingModelChange = false
        }
        if content.length == 0 {
            textView.typingAttributes = [
                .font: NSFont.systemFont(ofSize: 22 * scale),
                .foregroundColor: NSColor.white
            ]
        }
        if !scrollEnabled {
            DispatchQueue.main.async {
                let availableWidth = max(1, scroll.contentSize.width)
                textView.frame.size.width = availableWidth
                textView.textContainer?.containerSize = NSSize(
                    width: availableWidth,
                    height: CGFloat.greatestFiniteMagnitude
                )
                textView.layoutManager?.ensureLayout(for: textView.textContainer!)
                let usedHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 0
                context.coordinator.onHeightChange(max(56, ceil(usedHeight + textView.textContainerInset.height * 2 + 4)))
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let onChange: (NSAttributedString) -> Void
        let onFocus: () -> Void
        let onHeightChange: (CGFloat) -> Void
        var scale = 1.0
        var isApplyingModelChange = false

        init(
            onChange: @escaping (NSAttributedString) -> Void,
            onFocus: @escaping () -> Void,
            onHeightChange: @escaping (CGFloat) -> Void
        ) {
            self.onChange = onChange
            self.onFocus = onFocus
            self.onHeightChange = onHeightChange
        }

        func textDidBeginEditing(_ notification: Notification) {
            onFocus()
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingModelChange,
                  let textView = notification.object as? NSTextView else { return }

            let unscaled = NSMutableAttributedString(attributedString: textView.attributedString())
            let fullRange = NSRange(location: 0, length: unscaled.length)
            if scale != 1.0 {
                unscaled.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                    guard let font = value as? NSFont else { return }
                    let baseSize = font.pointSize / scale
                    unscaled.addAttribute(
                        .font,
                        value: NSFontManager.shared.convert(font, toSize: baseSize),
                        range: range
                    )
                }
            }
            onChange(unscaled)
        }
    }
}

private struct PagePositionPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
