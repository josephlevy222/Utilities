//
//  CaptureSize+RotatedText.swift
//  XYPlot
//
//  Created by Joseph Levy on 12/7/21.
//  Based on Rob Napier answer in StackOverFlow
//  https://stackoverflow.com/questions/58494193/swiftui-rotationeffect-framing-and-offsetting
//
import SwiftUI

struct VerticalText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).rotated()
    }
}

struct VerticalText_Previews: PreviewProvider {
    static var previews: some View {
        VerticalText("Hello World").font(.largeTitle)
    }
}

private struct SizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct WidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0.0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0.0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {

    public func captureSize(in binding: Binding<CGSize>) -> some View {
        overlay(GeometryReader { proxy in
            Color.clear.preference(key: SizeKey.self, value: proxy.size)
        })
            .onPreferenceChange(SizeKey.self) { size in binding.wrappedValue = size  }
    }
    
    public func captureWidth(in binding: Binding<CGFloat>) -> some View {
        overlay(GeometryReader { proxy in
            Color.clear.preference(key: WidthKey.self, value: proxy.size.width)
        })
            .onPreferenceChange(WidthKey.self) { width in binding.wrappedValue = width  }
    }
    
    public func captureHeight(in binding: Binding<CGFloat>) -> some View {
        overlay(GeometryReader { proxy in
            Color.clear.preference(key: HeightKey.self, value: proxy.size.height)
        })
            .onPreferenceChange(HeightKey.self) { height in binding.wrappedValue = height  }
    }
}

public struct Rotated<Rotated: View>: View {
    var view: Rotated
    var angle: Angle

    public init(_ view: Rotated, angle: Angle = .degrees(-90)) {
        self.view = view
        self.angle = angle
    }

    @State private var size: CGSize = .zero

    public var body: some View {
        // Rotate the frame, and compute the smallest integral frame that contains it
        let newFrame = CGRect(origin: .zero, size: size)
            .offsetBy(dx: -size.width/2, dy: -size.height/2)
            .applying(.init(rotationAngle: CGFloat(angle.radians)))
            .integral

            view
            .fixedSize()                    // Don't change the view's ideal frame
            .captureSize(in: $size)         // Capture the size of the view's ideal frame
            .rotationEffect(angle)          // Rotate the view
            .frame(width: newFrame.width,   // And apply the new frame
                   height: newFrame.height)
    }
}

extension View {
    public func rotated(_ angle: Angle = .degrees(-90)) -> some View {
        Rotated(self, angle: angle)
    }
}

