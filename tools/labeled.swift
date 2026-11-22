import AppKit
// uso: labeled out.png cols cropX cropY cropW cropH archivo1 nombre1 archivo2 nombre2 ...
let a = CommandLine.arguments
let out = a[1]; let cols = Int(a[2])!
let cr = CGRect(x: Double(a[3])!, y: Double(a[4])!, width: Double(a[5])!, height: Double(a[6])!)
var items: [(String, String)] = []
var i = 7
while i + 1 < a.count { items.append((a[i], a[i+1])); i += 2 }
let W = Int(cr.width), H = Int(cr.height), LH = 34, PAD = 10
let rows = (items.count + cols - 1) / cols
let TW = W + PAD, TH = H + LH + PAD
let img = NSImage(size: NSSize(width: TW * cols + PAD, height: TH * rows + PAD))
img.lockFocus()
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: img.size.width, height: img.size.height).fill()
let style = NSMutableParagraphStyle(); style.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 20, weight: .semibold), .foregroundColor: NSColor.black, .paragraphStyle: style]
for (k, it) in items.enumerated() {
  let col = k % cols, row = k / cols
  let x = PAD + col * TW, yTop = PAD + row * TH
  let y = Int(img.size.height) - yTop - H
  if let src = NSImage(contentsOfFile: it.0)?.cgImage(forProposedRect: nil, context: nil, hints: nil), let c = src.cropping(to: cr) {
    NSImage(cgImage: c, size: NSSize(width: W, height: H)).draw(in: NSRect(x: x, y: y, width: W, height: H))
  }
  (it.1 as NSString).draw(in: NSRect(x: x, y: y - LH, width: W, height: LH - 6), withAttributes: attrs)
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
