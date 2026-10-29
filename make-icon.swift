import AppKit
import Foundation
let root = URL(fileURLWithPath:CommandLine.arguments[1])
let set = root.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at:set,withIntermediateDirectories:true)
for size in [16,32,64,128,256,512,1024] {
    let img = NSImage(size:NSSize(width:size,height:size))
    img.lockFocus()
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x:CGFloat(size)/1024,y:CGFloat(size)/1024)
    let bounds = NSRect(x:30,y:30,width:964,height:964)
    let shape = NSBezierPath(roundedRect:bounds,xRadius:215,yRadius:215); shape.addClip()
    let gradient = NSGradient(colors:[NSColor(calibratedRed:0.58,green:0.33,blue:0.91,alpha:1),NSColor(calibratedRed:0.22,green:0.12,blue:0.43,alpha:1)])!
    gradient.draw(in:bounds,angle:-45)
    NSColor.white.withAlphaComponent(0.07).setFill(); NSBezierPath(ovalIn:NSRect(x:480,y:400,width:650,height:650)).fill()
    NSColor.white.setStroke()
    let radio = NSBezierPath(roundedRect:NSRect(x:320,y:300,width:384,height:330),xRadius:62,yRadius:62);radio.lineWidth=22;radio.stroke()
    let antenna = NSBezierPath();antenna.move(to:NSPoint(x:390,y:630));antenna.line(to:NSPoint(x:600,y:760));antenna.lineWidth=22;antenna.lineCapStyle = .round;antenna.stroke()
    for x in [390,435,480] { let line=NSBezierPath();line.move(to:NSPoint(x:x,y:390));line.line(to:NSPoint(x:x,y:530));line.lineWidth=18;line.lineCapStyle = .round;line.stroke() }
    NSColor.white.setFill();NSBezierPath(ovalIn:NSRect(x:560,y:430,width:75,height:75)).fill()
    for (x,start,end) in [(512, -45.0,45.0),(512,135.0,225.0)] {
        for radius in [CGFloat(280),CGFloat(355)] { let p=NSBezierPath();p.appendArc(withCenter:NSPoint(x:x,y:465),radius:radius,startAngle:start,endAngle:end);p.lineWidth=20;p.lineCapStyle = .round;p.stroke() }
    }
    img.unlockFocus()
    let rep=NSBitmapImageRep(data:img.tiffRepresentation!)!
    let bytes=rep.representation(using:.png,properties:[:])!
    if size <= 512 { try bytes.write(to:set.appendingPathComponent("icon_\(size)x\(size).png")) }
    if size >= 32 { try bytes.write(to:set.appendingPathComponent("icon_\(size/2)x\(size/2)@2x.png")) }
    if size == 1024 { try bytes.write(to:root.appendingPathComponent("AppIcon-1024.png")) }
}
