import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PresenterModel: ObservableObject {
    @Published private(set) var pages: [NSAttributedString] = []
    @Published var currentPage = 0
    @Published var opacity = 0.94
    @Published var fontScale = 1.0
    @Published var capturePreview: NSImage?
    @Published var statusMessage = "Legacy capture exclusion requested"
    @Published var documentName = "Untitled document"
    @Published var requestedScrollPage: Int?

    private weak var panel: NSPanel?
    private var autosaveTask: Task<Void, Never>?
    private var documentURL: URL?
    private var isRestoring = false

    var pageLabel: String {
        pages.isEmpty ? "— / —" : "\(currentPage + 1) / \(pages.count)"
    }

    var currentContent: NSAttributedString {
        guard pages.indices.contains(currentPage) else {
            return blankPage()
        }
        return pages[currentPage]
    }

    var defaultAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: 22, weight: .regular),
            .foregroundColor: NSColor.white
        ]
    }

    func attach(panel: NSPanel) {
        self.panel = panel
        if pages.isEmpty && !restoreAutosave() { newDocument() }
        applyWindowSettings()
    }

    func newDocument() {
        pages = [blankPage()]
        currentPage = 0
        documentName = "Untitled document"
        statusMessage = "Page 1 ready to edit"
        documentURL = nil
        scheduleAutosave()
    }

    func addPage() {
        let insertionIndex = min(currentPage + 1, pages.count)
        pages.insert(blankPage(), at: insertionIndex)
        currentPage = insertionIndex
        requestedScrollPage = insertionIndex
        statusMessage = "Added page \(currentPage + 1)"
        scheduleAutosave()
    }

    func confirmClearAll() {
        let alert = NSAlert()
        alert.messageText = "Clear all pages?"
        alert.informativeText = "This removes all text from this document and leaves one blank page. Save a copy first if you want to keep it."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear All")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        clearAll()
    }

    func clearAll() {
        pages = [blankPage()]
        currentPage = 0
        requestedScrollPage = 0
        markDocumentEdited()
        statusMessage = "Cleared all pages"
        scheduleAutosave()
    }

    func cleanAllFormatting() {
        guard !pages.isEmpty else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineSpacing = 6
        paragraph.paragraphSpacing = 8
        var attributes = defaultAttributes
        attributes[.paragraphStyle] = paragraph
        pages = pages.map { NSAttributedString(string: $0.string, attributes: attributes) }
        markDocumentEdited()
        statusMessage = "Clean formatting applied to all pages"
        scheduleAutosave()
    }

    private func markDocumentEdited() {
        if documentName != "Untitled document" && !documentName.hasSuffix(" (edited)") {
            documentName += " (edited)"
        }
    }

    func deleteCurrentPage() {
        deletePage(at: currentPage)
    }

    func duplicatePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        pages.insert(NSAttributedString(attributedString: pages[index]), at: index + 1)
        currentPage = index + 1
        requestedScrollPage = currentPage
        markDocumentEdited()
        statusMessage = "Duplicated page \(index + 1)"
        scheduleAutosave()
    }

    func clearPage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        pages[index] = blankPage()
        currentPage = index
        requestedScrollPage = index
        markDocumentEdited()
        statusMessage = "Cleared page \(index + 1)"
        scheduleAutosave()
    }

    func deletePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        markDocumentEdited()
        if pages.count == 1 {
            pages[0] = blankPage()
            currentPage = 0
            requestedScrollPage = 0
            statusMessage = "Cleared the only page"
            scheduleAutosave()
            return
        }
        pages.remove(at: index)
        if index < currentPage { currentPage -= 1 }
        currentPage = min(currentPage, pages.count - 1)
        requestedScrollPage = currentPage
        statusMessage = "Page deleted"
        scheduleAutosave()
    }

    func updateCurrentPage(_ content: NSAttributedString) {
        updatePage(at: currentPage, content: content)
    }

    func updatePage(at index: Int, content: NSAttributedString) {
        guard pages.indices.contains(index) else { return }
        pages[index] = content
        if documentName != "Untitled document" && !documentName.hasSuffix(" (edited)") {
            documentName += " (edited)"
        }
        scheduleAutosave()
    }

    func applyWindowSettings() {
        panel?.alphaValue = opacity
        panel?.ignoresMouseEvents = false
        panel?.sharingType = .none
    }

    func openDocument() {
        let picker = NSOpenPanel()
        picker.title = "Choose your presenter document"
        picker.prompt = "Open"
        picker.allowsMultipleSelection = false
        picker.canChooseDirectories = false
        picker.allowedContentTypes = [
            UTType(filenameExtension: "docx") ?? .data,
            .rtf,
            .plainText,
            .text,
            .pdf,
            .data
        ]

        guard picker.runModal() == .OK, let url = picker.url else { return }

        do {
            if url.pathExtension.lowercased() == "ppdoc" {
                try loadProject(from: url)
                return
            }
            let loadedPages: [NSAttributedString]
            if url.pathExtension.lowercased() == "pdf" {
                loadedPages = try PDFTextLoader.load(url: url, attributes: defaultAttributes)
            } else {
                let content = try loadAttributedDocument(url: url)
                loadedPages = TextPaginator.paginate(content)
            }

            pages = loadedPages.isEmpty
                ? [NSAttributedString(string: "The document is empty.", attributes: defaultAttributes)]
                : loadedPages
            currentPage = 0
            documentName = url.lastPathComponent
            documentURL = nil
            statusMessage = "Legacy capture exclusion requested"
            scheduleAutosave()
        } catch {
            pages = [NSAttributedString(
                string: "Could not open this document.\n\n\(error.localizedDescription)",
                attributes: defaultAttributes
            )]
            currentPage = 0
            documentName = url.lastPathComponent
        }
    }

    func pasteIntoCurrentPage() {
        let pasteboard = NSPasteboard.general
        let pastedContent: NSAttributedString?

        if let richText = ClipboardFormatting.content(from: pasteboard) {
            pastedContent = richText
        } else if let text = pasteboard.string(forType: .string), !text.isEmpty {
            pastedContent = NSAttributedString(string: text, attributes: defaultAttributes)
        } else {
            pastedContent = nil
        }

        guard let pastedContent, pastedContent.length > 0 else {
            statusMessage = "Clipboard has no text to paste"
            return
        }

        guard pages.indices.contains(currentPage) else { return }
        let updated = NSMutableAttributedString(attributedString: pages[currentPage])
        if updated.length > 0 && !updated.string.hasSuffix("\n") {
            updated.append(NSAttributedString(string: "\n", attributes: defaultAttributes))
        }
        updated.append(pastedContent)
        pages[currentPage] = updated
        statusMessage = "Pasted into page \(currentPage + 1)"
        scheduleAutosave()
    }

    func previousPage() {
        guard !pages.isEmpty else { return }
        jump(to: currentPage - 1)
    }

    func nextPage() {
        guard !pages.isEmpty else { return }
        jump(to: currentPage + 1)
    }

    func jump(to page: Int) {
        guard !pages.isEmpty else { return }
        currentPage = min(max(0, page), pages.count - 1)
        requestedScrollPage = currentPage
        scheduleAutosave()
    }

    func setVisiblePage(_ page: Int) {
        guard pages.indices.contains(page), currentPage != page else { return }
        currentPage = page
    }

    func consumeScrollRequest() {
        requestedScrollPage = nil
    }

    func saveDocument() {
        if let documentURL {
            do {
                try writeProject(to: documentURL)
                statusMessage = "Saved \(documentURL.lastPathComponent)"
            } catch {
                statusMessage = "Save failed: \(error.localizedDescription)"
            }
            return
        }
        saveDocumentAs()
    }

    func saveDocumentAs() {
        let panel = NSSavePanel()
        panel.title = "Save Presenter Document"
        panel.prompt = "Save"
        panel.nameFieldStringValue = suggestedProjectName
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, var url = panel.url else { return }
        if url.pathExtension.lowercased() != "ppdoc" {
            url.appendPathExtension("ppdoc")
        }
        do {
            try writeProject(to: url)
            documentURL = url
            documentName = url.deletingPathExtension().lastPathComponent
            statusMessage = "Saved \(url.lastPathComponent)"
            scheduleAutosave()
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func saveAutosaveNow() {
        guard !isRestoring, !pages.isEmpty else { return }
        do {
            let url = try autosaveURL()
            try writeProject(to: url)
        } catch {
            statusMessage = "Autosave failed: \(error.localizedDescription)"
        }
    }

    func toggleBold() { toggleFontTrait(.boldFontMask) }
    func toggleItalic() { toggleFontTrait(.italicFontMask) }

    func toggleUnderline() {
        guard let textView = activeTextView() else { return }
        let range = textView.selectedRange()
        if range.length == 0 {
            let current = textView.typingAttributes[.underlineStyle] as? Int ?? 0
            textView.typingAttributes[.underlineStyle] = current == 0 ? NSUnderlineStyle.single.rawValue : 0
            return
        }
        let current = textView.textStorage?.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
        textView.textStorage?.addAttribute(
            .underlineStyle,
            value: current == 0 ? NSUnderlineStyle.single.rawValue : 0,
            range: range
        )
        textView.didChangeText()
    }

    func changeFontSize(by delta: CGFloat) {
        guard let textView = activeTextView() else { return }
        let range = textView.selectedRange()
        if range.length == 0 {
            let font = textView.typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 22)
            textView.typingAttributes[.font] = NSFontManager.shared.convert(font, toSize: max(8, font.pointSize + delta))
            return
        }
        textView.textStorage?.enumerateAttribute(.font, in: range) { value, fontRange, _ in
            let font = value as? NSFont ?? NSFont.systemFont(ofSize: 22)
            textView.textStorage?.addAttribute(
                .font,
                value: NSFontManager.shared.convert(font, toSize: max(8, font.pointSize + delta)),
                range: fontRange
            )
        }
        textView.didChangeText()
    }

    func align(_ alignment: NSTextAlignment) {
        guard let textView = activeTextView() else { return }
        let selection = textView.selectedRange()
        let paragraphRange = (textView.string as NSString).paragraphRange(for: selection)
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        if paragraphRange.length > 0 {
            textView.textStorage?.addAttribute(.paragraphStyle, value: style, range: paragraphRange)
            textView.didChangeText()
        } else {
            textView.typingAttributes[.paragraphStyle] = style
        }
    }

    func pagePreview(at index: Int) -> String {
        guard pages.indices.contains(index) else { return "Blank page" }
        let compact = pages[index].string
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return compact.isEmpty ? "Blank page" : String(compact.prefix(54))
    }

    func runCaptureTest() {
        panel?.sharingType = .none
        guard let imageRef = CGWindowListCreateImage(
            .infinite,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            statusMessage = "Capture test was unavailable on this macOS version"
            return
        }
        capturePreview = NSImage(cgImage: imageRef, size: .zero)
        statusMessage = "Local legacy-capture preview only"
    }

    func closeCapturePreview() {
        capturePreview = nil
        statusMessage = "Legacy capture exclusion requested"
    }

    private func loadAttributedDocument(url: URL) throws -> NSAttributedString {
        if ["txt", "md"].contains(url.pathExtension.lowercased()) {
            let text = try String(contentsOf: url, encoding: .utf8)
            return NSAttributedString(string: text, attributes: defaultAttributes)
        }

        let imported = try NSAttributedString(
            url: url,
            options: [.documentType: documentType(for: url)],
            documentAttributes: nil
        )
        return normalizedForOverlay(imported)
    }

    private func documentType(for url: URL) -> NSAttributedString.DocumentType {
        switch url.pathExtension.lowercased() {
        case "rtf": return .rtf
        case "docx": return .officeOpenXML
        default: return .plain
        }
    }

    private func normalizedForOverlay(_ source: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: result.length)
        result.addAttribute(.foregroundColor, value: NSColor.white, range: fullRange)
        result.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            let existing = (value as? NSFont) ?? NSFont.systemFont(ofSize: 18)
            let size = max(16, min(existing.pointSize, 32))
            let replacement = NSFontManager.shared.convert(existing, toSize: size)
            result.addAttribute(.font, value: replacement, range: range)
        }
        return result
    }

    private func blankPage() -> NSAttributedString {
        NSAttributedString(string: "", attributes: defaultAttributes)
    }

    private var suggestedProjectName: String {
        let base = documentName
            .replacingOccurrences(of: " (edited)", with: "")
            .replacingOccurrences(of: ".ppdoc", with: "")
        return (base == "Untitled document" ? "Presenter Document" : base) + ".ppdoc"
    }

    private func scheduleAutosave() {
        guard !isRestoring else { return }
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            self?.saveAutosaveNow()
        }
    }

    private func autosaveURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appendingPathComponent("Private Presenter", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("Autosave.ppdoc")
    }

    private func restoreAutosave() -> Bool {
        do {
            let url = try autosaveURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return false }
            try loadProject(from: url, isAutosave: true)
            statusMessage = "Restored your last document"
            return true
        } catch {
            statusMessage = "Could not restore autosave"
            return false
        }
    }

    private func writeProject(to url: URL) throws {
        let encodedPages = try pages.map { page in
            try page.data(
                from: NSRange(location: 0, length: page.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        }
        let project = PresenterProject(
            version: 1,
            name: documentName,
            currentPage: currentPage,
            pages: encodedPages
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: url, options: .atomic)
    }

    private func loadProject(from url: URL, isAutosave: Bool = false) throws {
        let data = try Data(contentsOf: url)
        let project = try JSONDecoder().decode(PresenterProject.self, from: data)
        let decodedPages = try project.pages.map { data in
            try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        }
        isRestoring = true
        pages = decodedPages.isEmpty ? [blankPage()] : decodedPages
        currentPage = min(max(0, project.currentPage), pages.count - 1)
        documentName = isAutosave ? project.name : url.deletingPathExtension().lastPathComponent
        documentURL = isAutosave ? nil : url
        isRestoring = false
        if !isAutosave { statusMessage = "Opened \(url.lastPathComponent)" }
        scheduleAutosave()
    }

    private func activeTextView() -> NSTextView? {
        if let textView = panel?.firstResponder as? NSTextView { return textView }
        return panel?.contentView?.firstDescendant(of: NSTextView.self)
    }

    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        guard let textView = activeTextView() else { return }
        let manager = NSFontManager.shared
        let range = textView.selectedRange()
        if range.length == 0 {
            let font = textView.typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 22)
            let hasTrait = manager.traits(of: font).contains(trait)
            textView.typingAttributes[.font] = hasTrait
                ? manager.convert(font, toNotHaveTrait: trait)
                : manager.convert(font, toHaveTrait: trait)
            return
        }
        let firstFont = textView.textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            ?? NSFont.systemFont(ofSize: 22)
        let removeTrait = manager.traits(of: firstFont).contains(trait)
        textView.textStorage?.enumerateAttribute(.font, in: range) { value, fontRange, _ in
            let font = value as? NSFont ?? NSFont.systemFont(ofSize: 22)
            let converted = removeTrait
                ? manager.convert(font, toNotHaveTrait: trait)
                : manager.convert(font, toHaveTrait: trait)
            textView.textStorage?.addAttribute(.font, value: converted, range: fontRange)
        }
        textView.didChangeText()
    }
}

private struct PresenterProject: Codable {
    let version: Int
    let name: String
    let currentPage: Int
    let pages: [Data]
}

private extension NSView {
    func firstDescendant<T: NSView>(of type: T.Type) -> T? {
        if let match = self as? T { return match }
        for subview in subviews {
            if let match = subview.firstDescendant(of: type) { return match }
        }
        return nil
    }
}

enum TextPaginator {
    static func paginate(_ content: NSAttributedString) -> [NSAttributedString] {
        guard content.length > 0 else { return [] }

        let storage = NSTextStorage(attributedString: content)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)

        var result: [NSAttributedString] = []
        var coveredGlyphs = 0
        let pageTextSize = NSSize(width: 590, height: 720)

        while coveredGlyphs < layout.numberOfGlyphs {
            let container = NSTextContainer(size: pageTextSize)
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            layout.ensureLayout(for: container)

            let glyphRange = layout.glyphRange(for: container)
            guard glyphRange.length > 0 else { break }
            let characterRange = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            result.append(content.attributedSubstring(from: characterRange))
            coveredGlyphs = NSMaxRange(glyphRange)
        }

        return result
    }
}

enum PDFTextLoader {
    static func load(url: URL, attributes: [NSAttributedString.Key: Any]) throws -> [NSAttributedString] {
        guard let document = PDFKit.PDFDocument(url: url) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return (0..<document.pageCount).map { index in
            let text = document.page(at: index)?.string ?? ""
            return NSAttributedString(string: text, attributes: attributes)
        }
    }
}

import PDFKit
