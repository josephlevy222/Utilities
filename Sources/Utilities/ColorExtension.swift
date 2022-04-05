//
//  ColorExtension.swift
//  Utility

// Created by Tianna Henry-Lewis on 2021-12-17.
// Modified by Joseph Levy on 3/25/22.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    
    public var components: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        
        var r: CGFloat = 0,  g: CGFloat = 0,  b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        else { return (0,0,0,0) }
        return (r,g,b,a)
        
        #elseif canImport(AppKit)
        let ciColor = CIColor(color: NSColor(self)) ?? CIColor(color: .black)!
        r=ciColor.red; g=ciColor.green; b=ciColor.blue; a=ciColor.alpha
        return (r,g,b,a)
        #endif
    }
    
    public var sARGB: Int {
        // returns Int in hex 0xOORRGGBB where each double letter
        // is 0x00 to 0xFF (0 to 255 in decimal) of the components
        // opacity, red, green, and blue
        
        // Func to make 8-bit in component from CGFloat
        func intColor(_ x: CGFloat) -> Int {Int((x*255).rounded())}
        
        let color = components
        let red = intColor(color.r)
        let green = intColor(color.g)
        let blue = intColor(color.b)
        let opacity = intColor(color.a)
        return  ((opacity*256+red)*256+green)*256+blue
    }
    
    public init(sARGB: Int) {
        var s = sARGB
        func next() -> Double { // extract LS 8-bits
            defer { s = s >> 8 } // be ready for next component
            return Double(s & 0xFF)/255.0
        }
        let b = next(), g = next(), r = next(), o = next()
        self = Color(red: r, green: g, blue: b, opacity: o)
    }
}

//func IntToHexString(_ c: Int) -> String { String(format: "%x", c)}

struct ColorExtension: PreviewProvider {
    static var color: Color  = Color.purple.opacity(0.5)
    static var previews: some View {
        StatefulPreviewWrapper(color) {bind in
            VStack {
                ColorPicker("Choose",selection: bind).frame(width: 110)
                Text("Int:  \(String(format: "%x", bind.wrappedValue.sARGB))" )
                Color(sARGB: bind.wrappedValue.sARGB).frame(width: 100, height: 100)
            }
        }
    }
}

// From Jim Dovey on Apple Developers Forum
// used this allow the use of State var in preview
// https://developer.apple.com/forums/thread/118589
// seems slow...
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    var content: (Binding<Value>) -> Content
    
    var body: some View {
        content($value)
    }
    
    init(_ value: Value, content: @escaping (Binding<Value>) -> Content) {
        self._value = State(wrappedValue: value)
        self.content = content
    }
}
