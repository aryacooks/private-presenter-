import AppKit

enum ClipboardFormatting {
    static func content(from pasteboard: NSPasteboard) -> NSAttributedString? {
        let formats: [(NSPasteboard.PasteboardType, NSAttributedString.DocumentType)] = [
            (.rtf, .rtf),
            (.html, .html)
        ]
        for (type, documentType) in formats {
            if let data = pasteboard.data(forType: type),
               let content = try? NSAttributedString(
                   data: data,
                   options: [.documentType: documentType],
                   documentAttributes: nil
               ), content.length > 0 {
                return content
            }
        }
        return nil
    }

    static func scalingFonts(in content: NSAttributedString, by scale: Double) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: content)
        guard scale != 1 else { return result }
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let font = value as? NSFont else { return }
            result.addAttribute(.font, value: NSFontManager.shared.convert(font, toSize: font.pointSize * scale), range: range)
        }
        return result
    }
}

final class FormattingTextView: NSTextView {
    var presentationScale = 1.0

    override func paste(_ sender: Any?) {
        guard let content = ClipboardFormatting.content(from: .general) else {
            super.paste(sender)
            return
        }
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: content.string) else { return }
        let displayed = ClipboardFormatting.scalingFonts(in: content, by: presentationScale)
        textStorage?.replaceCharacters(in: range, with: displayed)
        setSelectedRange(NSRange(location: range.location + displayed.length, length: 0))
        didChangeText()
    }
}
