import AppKit
import XCTest
@testable import PrivatePresenter

final class ClipboardFormattingTests: XCTestCase {
    func testEditingKeepsColourAndSmallFontAtNonDefaultZoom() throws {
        let editor = NSTextView()
        editor.textStorage?.setAttributedString(NSAttributedString(string: "Small red text", attributes: [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.red
        ]))
        var saved: NSAttributedString?
        let coordinator = AttributedTextView.Coordinator(onChange: { saved = $0 }, onFocus: {}, onHeightChange: { _ in })
        coordinator.scale = 1.5
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        let content = try XCTUnwrap(saved)
        XCTAssertEqual((content.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 6)
        XCTAssertEqual(content.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, NSColor.red)
    }

    func testRichTextKeepsOriginalAttributesAndZoomRoundTrips() throws {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 15
        let font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 42), toHaveTrait: .boldFontMask)
        let original = NSAttributedString(string: "Heading", attributes: [
            .font: font,
            .foregroundColor: NSColor.red,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .paragraphStyle: paragraph
        ])
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let data = try original.data(from: NSRange(location: 0, length: original.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        board.setData(data, forType: .rtf)
        let pasted = try XCTUnwrap(ClipboardFormatting.content(from: board))
        let restored = ClipboardFormatting.scalingFonts(in: ClipboardFormatting.scalingFonts(in: pasted, by: 1.5), by: 1 / 1.5)
        let attributes = restored.attributes(at: 0, effectiveRange: nil)
        let restoredFont = try XCTUnwrap(attributes[.font] as? NSFont)
        XCTAssertEqual(restoredFont.pointSize, 42, accuracy: 0.01)
        XCTAssertTrue(NSFontManager.shared.traits(of: restoredFont).contains(.boldFontMask))
        let colour = try XCTUnwrap((attributes[.foregroundColor] as? NSColor)?.usingColorSpace(.deviceRGB))
        XCTAssertEqual(colour.redComponent, 1, accuracy: 0.01)
        XCTAssertEqual(colour.greenComponent, 0, accuracy: 0.01)
        XCTAssertEqual(attributes[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
        let restoredParagraph = try XCTUnwrap(attributes[.paragraphStyle] as? NSParagraphStyle)
        XCTAssertEqual(restoredParagraph.alignment, .center)
        XCTAssertEqual(restoredParagraph.paragraphSpacing, 15)
    }

    func testHTMLFallbackWhenRTFIsInvalid() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setData(Data("invalid rtf".utf8), forType: .rtf)
        board.setData(Data("<html><body><b>Bold</b> <i>Italic</i></body></html>".utf8), forType: .html)
        let pasted = try XCTUnwrap(ClipboardFormatting.content(from: board))
        XCTAssertTrue(pasted.string.contains("Bold Italic"))
        let font = try XCTUnwrap(pasted.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
    }

    func testPlainTextUsesCallersFallback() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("plain text", forType: .string)
        XCTAssertNil(ClipboardFormatting.content(from: board))
    }
}
