import AppKit
// Genera fondos 260x260 usando solo colores de la paleta del FR255 (00/55/AA/FF).
let N = 260
let out = CommandLine.arguments[1]
func save(_ name: String, _ f: (Int, Int) -> UInt32) {
  var px = [UInt8](repeating: 0, count: N*N*4)
  for y in 0..<N { for x in 0..<N {
    let c = f(x, y); let i = (y*N+x)*4
    px[i] = UInt8((c>>16)&0xFF); px[i+1] = UInt8((c>>8)&0xFF); px[i+2] = UInt8(c&0xFF); px[i+3] = 255
  }}
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: N, pixelsHigh: N, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: N*4, bitsPerPixel: 32)!
  memcpy(rep.bitmapData!, px, px.count)
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out + "/" + name + ".png"))
}
let bayer: [[Double]] = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]].map { $0.map { ($0 + 0.5) / 16.0 } }
// v en [0, stops.count-1] -> color con tramado ordenado
func dither(_ stops: [UInt32], _ v: Double, _ x: Int, _ y: Int) -> UInt32 {
  let vv = max(0, min(Double(stops.count - 1), v))
  let i = Int(vv.rounded(.down)); let fr = vv - Double(i)
  if i >= stops.count - 1 { return stops.last! }
  return fr > bayer[y % 4][x % 4] ? stops[i+1] : stops[i]
}
func rr(_ x: Int, _ y: Int) -> Double { let dx = Double(x) - 129.5, dy = Double(y) - 129.5; return (dx*dx+dy*dy).squareRoot() }
func noise(_ x: Double, _ y: Double, _ s: Double) -> Double {
  return sin(x*0.031*s + 1.3) + sin(y*0.027*s + 0.4) + 0.8*sin((x+y)*0.019*s + 2.1)
       + 0.6*sin((x-y)*0.043*s + 0.7) + 0.5*sin(x*0.071*s - y*0.052*s + 3.0)
}

// 2 Azul degradado (radial)
save("bg2") { x, y in dither([0x000000, 0x000055, 0x0000AA], 2.0 * (1 - rr(x,y)/135.0) * 1.15 - 0.15, x, y) }
// 3 Crepúsculo (vertical)
save("bg3") { x, y in dither([0x000000, 0x000055, 0x550055], Double(y)/260.0 * 2.2 - 0.3, x, y) }
// 4 Fibra de carbono
save("bg4") { x, y in
  let c = 6; let cx = x / c, cy = y / c
  let on = ((cx + cy) % 2 == 0) ? (y % 4 == 0) : (x % 4 == 0)
  return on ? 0x555555 : 0x000000 }
// 5 Rayos
save("bg5") { x, y in
  let r = rr(x,y); if r < 34 { return 0 }
  let a = atan2(Double(y)-129.5, Double(x)-129.5) * 180 / .pi + 360
  let step = 6.0; let d = abs(a - (a/step).rounded()*step) * .pi / 180 * r
  return d < 0.55 ? 0x555555 : 0x000000 }
// 6 Panal (hexágonos): borde = puntos casi equidistantes de dos centros
var centers: [(Double, Double)] = []
let hs = 16.0, hh = hs * sqrt(3) / 2
for row in -1...20 { for col in -1...20 {
  centers.append((Double(col) * hs + (row % 2 == 0 ? 0 : hs/2), Double(row) * hh))
}}
save("bg6") { x, y in
  var d1 = 1e9, d2 = 1e9
  for c in centers {
    let dx = c.0 - Double(x), dy = c.1 - Double(y)
    if abs(dx) > 30 || abs(dy) > 30 { continue }
    let dd = (dx*dx + dy*dy).squareRoot()
    if dd < d1 { d2 = d1; d1 = dd } else if dd < d2 { d2 = dd }
  }
  return (d2 - d1) < 1.0 ? 0x555555 : 0x000000 }
// 7 Guilloché (clavos de París)
save("bg7") { x, y in
  let u = (x + y) % 12, v = (x - y + 1200) % 12
  if u == 0 || v == 0 { return 0x555555 }
  return ((u < 6) != (v < 6)) && (u + v) % 4 == 0 ? 0x000055 : 0x000000 }
// 8 Topográfico
save("bg8") { x, y in
  let k = 2.4
  let a = Int((noise(Double(x), Double(y), 1.0) * k).rounded(.down))
  let b = Int((noise(Double(x+1), Double(y), 1.0) * k).rounded(.down))
  let c = Int((noise(Double(x), Double(y+1), 1.0) * k).rounded(.down))
  return (a != b || a != c) ? ((a % 3 == 0) ? 0x55AA55 : 0x005500) : 0x000000 }
// 9 Radar
save("bg9") { x, y in
  let r = rr(x,y)
  if abs(r - (r/26).rounded()*26) < 0.6 && r > 5 { return 0x005500 }
  if x == 130 || y == 130 { return 0x005500 }
  let a = atan2(Double(y)-129.5, Double(x)-129.5) * 180 / .pi
  let sweep = a - (-90.0); let sw = sweep < 0 ? sweep + 360 : sweep
  if sw > 320 { return dither([0x000000, 0x005500], (sw - 320)/40.0 * 0.7, x, y) }
  return 0x000000 }
// 10 Camuflaje
save("bg10") { x, y in
  let n1 = noise(Double(x), Double(y), 1.6), n2 = noise(Double(y)+40, Double(x)+90, 2.3)
  if n1 > 1.3 { return 0x555500 }
  if n2 > 1.1 { return 0x005500 }
  if n1 < -1.6 { return 0x555555 }
  return 0x000000 }
