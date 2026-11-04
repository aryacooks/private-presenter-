import AppKit
import XCTest
@testable import PrivatePresenter

final class DocumentActionsTests: XCTestCase {
    @MainActor
    func testPageActionsTargetChosenPageAndKeepSelectionValid() {
        let model = PresenterModel()
        model.newDocument()
        let original = NSAttributedString(string: "First", attributes: [.font: NSFont.boldSystemFont(ofSize: 30)])
        model.updateCurrentPage(original)
        model.addPage()
        model.updateCurrentPage(NSAttributedString(string: "Second"))
        model.duplicatePage(at: 0)
        XCTAssertEqual(model.pages.map(\.string), ["First", "First", "Second"])
        XCTAssertTrue(model.pages[1].isEqual(to: original))
        model.clearPage(at: 1)
        XCTAssertEqual(model.pages.map(\.string), ["First", "", "Second"])
        model.jump(to: 2)
        model.deletePage(at: 0)
        XCTAssertEqual(model.pages.map(\.string), ["", "Second"])
        XCTAssertEqual(model.currentPage, 1)
        XCTAssertEqual(model.requestedScrollPage, 1)
        model.deleteCurrentPage()
        model.deleteCurrentPage()
        XCTAssertEqual(model.pages.map(\.string), [""])
        XCTAssertEqual(model.currentPage, 0)
    }

    @MainActor
    func testCleanFormattingKeepsAllTextAndPages() throws {
        let model = PresenterModel()
        model.newDocument()
        let text = "Heading\nSecond line\n\nNew paragraph"
        model.updateCurrentPage(NSAttributedString(string: text, attributes: [
            .font: NSFont.boldSystemFont(ofSize: 40),
            .foregroundColor: NSColor.red,
            .backgroundColor: NSColor.yellow,
            .underlineStyle: 1
        ]))
        model.addPage()
        model.updateCurrentPage(NSAttributedString(string: "Another page"))
        model.cleanAllFormatting()
        XCTAssertEqual(model.pages.map(\.string), [text, "Another page"])
        XCTAssertEqual(model.currentPage, 1)
        for page in model.pages {
            let attributes = page.attributes(at: 0, effectiveRange: nil)
            let font = try XCTUnwrap(attributes[.font] as? NSFont)
            XCTAssertEqual(font.pointSize, 22)
            XCTAssertFalse(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
            XCTAssertEqual(attributes[.foregroundColor] as? NSColor, .white)
            XCTAssertNil(attributes[.backgroundColor])
            XCTAssertNil(attributes[.underlineStyle])
            XCTAssertEqual((attributes[.paragraphStyle] as? NSParagraphStyle)?.alignment, .left)
        }
    }

    @MainActor
    func testClearAllLeavesOneBlankPage() {
        let model = PresenterModel()
        model.newDocument()
        model.updateCurrentPage(NSAttributedString(string: "First"))
        model.addPage()
        model.updateCurrentPage(NSAttributedString(string: "Second"))
        model.clearAll()
        XCTAssertEqual(model.pages.map(\.string), [""])
        XCTAssertEqual(model.currentPage, 0)
        XCTAssertEqual(model.requestedScrollPage, 0)
    }
}
