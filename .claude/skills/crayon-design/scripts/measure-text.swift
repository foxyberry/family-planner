// Measures text widths in Playpen Sans, the app's font, so minimum widths come from real text.
// Usage: swift measure-text.swift <size> <regular|medium|semibold|bold> "text" ["text" ...]
// Run anywhere inside the repo; it finds ios/DesignSystem/Resources/Fonts/PlaypenSans[wght].ttf.
import CoreText
import Foundation

let args = CommandLine.arguments.dropFirst()
guard args.count >= 3, let size = Double(args.first!) else {
    print("usage: swift measure-text.swift <size> <regular|medium|semibold|bold> \"text\" ...")
    exit(2)
}
let weights: [String: Double] = ["regular": 400, "medium": 500, "semibold": 600, "bold": 700]
let weightName = args.dropFirst().first!
guard let wght = weights[weightName] else { print("weight must be regular, medium, semibold or bold"); exit(2) }
func repoRoot() -> String {
    let git = Process()
    git.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    git.arguments = ["rev-parse", "--show-toplevel"]
    let out = Pipe()
    git.standardOutput = out
    try? git.run()
    git.waitUntilExit()
    let path = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return path.trimmingCharacters(in: .whitespacesAndNewlines)
}
let url = URL(fileURLWithPath: repoRoot() + "/ios/DesignSystem/Resources/Fonts/PlaypenSans[wght].ttf")
guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
      let base = descs.first else { print("font not found at \(url.path); run inside the repo"); exit(1) }
// 'wght' axis tag = 0x77676874
let varDesc = CTFontDescriptorCreateCopyWithAttributes(base, [
    kCTFontVariationAttribute: [0x77676874: wght]
] as CFDictionary)
let font = CTFontCreateWithFontDescriptor(varDesc, CGFloat(size), nil)
for text in args.dropFirst(2) {
    let s = NSAttributedString(string: text, attributes: [.init(kCTFontAttributeName as String): font])
    let line = CTLineCreateWithAttributedString(s)
    let w = CTLineGetTypographicBounds(line, nil, nil, nil)
    print(String(format: "%7.1f  %@", w, text))
}
