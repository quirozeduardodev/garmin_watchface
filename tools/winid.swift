import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list {
  let owner = w[kCGWindowOwnerName as String] as? String ?? ""
  if owner.lowercased().contains("simulator") || owner.lowercased().contains("connectiq") {
    let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    print(w[kCGWindowNumber as String]!, owner, w[kCGWindowName as String] ?? "", b["Width"]!, b["Height"]!)
  }
}
