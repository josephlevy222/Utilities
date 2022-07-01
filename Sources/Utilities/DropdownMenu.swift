//
//  DropdownMenu.swift
//  Mode Analyzer-1D
//
//  Created by Joseph Levy on 2/20/22.
//

import SwiftUI

/// horizontalFill makes a view that fills the Horizontal space using Spacer() on the left and right
/// @ViewBuilder // this appears to be optional here since only on kind of view is returned
extension View {
    public func horizontalFill(minLength: CGFloat = 0) -> some View {
        HStack { Spacer(minLength: minLength); self; Spacer(minLength: minLength) } }
}

struct DropdownMenuStyle : MenuStyle {
    typealias Body = Menu
    func makeBody(configuration: Configuration) -> some View {
        Menu(configuration).textFieldStyle(.automatic)
    }
}
/* 
extension Menu {
    /// Creates a menu that generates its label from a AttributedString.
    ///
    /// To create the label with a localized string key, use
    /// ``Menu/init(_:content:)-7v768`` instead.
    ///
    /// - Parameters:
    ///     - attributedTitle: A string that describes the contents of the menu.
    ///     - content: A group of menu items.
    public init(attributedTitle: AttributedString, @ViewBuilder content: () -> Content) where Label == Text {
        self.init(attributedTitle.description , content: content)
    }
}*/
    
public struct DropdownMenu: View {
    public init(placeHolder: AttributedString = HTMLParser("<gray>Unselected</gray>").attributedString, selection: Binding<Int>, options: [AttributedString]) {
        self.placeHolder = placeHolder
        self._selection = selection
        self.options = options
    }
    
    // Menu does not support Text Attributes in dropdown
    var placeHolder = HTMLParser("<gray>Unselected</gray>").attributedString
    @Binding var selection: Int
    let options: [AttributedString]
    public var body: some View {
        Menu(content: {
            ForEach(options.indices, id:\.self) { i in
                Button(action: { selection = i }) {
                    Text(options[i])
                }
            }
        }, label: {
            (options.indices.contains(selection)
                ? Text(options[selection])
                : Text(placeHolder))//.foregroundColor(.gray))
        } ).menuStyle(DropdownMenuStyle()).buttonStyle(.plain)
    }
}

/// This is a Button with a Text label using a AttributedString and HTMLParser styling
/// The options array has the AttributedStrings that are chosen from the popover displayed
/// when the Button is pushed and the selection Binding is set to that element
/// A placeHolder is used for selections that are out of range in option can be set
//@available(iOS 15, *)
public struct Dropdown: View {
    //public init(placeHolder: AttributedString = HTMLParser("<gray>Unselected</gray>").attributedString, selection: Binding<Int>, options: [AttributedString]) {
    //    self.placeHolder = placeHolder
    //    self._selection = selection
    //    self.options = options
    //}
    
    var placeHolder = HTMLParser("<gray>Unselected</gray>").attributedString
    @Binding var selection: Int
    let options: [AttributedString]
    @State private var showDropDown = false
    public var body: some View {
        Button(action:  { showDropDown = true }) {
            Text(options.indices.contains(selection) ?
                 options[selection] :
                    placeHolder )//.horizontalFill()
        }
        .popover(isPresented: $showDropDown, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            VStack {
                Spacer()
                ForEach(options.indices, id:\.self) { i in
                    VStack {
                        Button(action: {
                            showDropDown = false
                            selection = i
                        }) { Text(options[i]).horizontalFill(minLength: 10) }
                        Divider()
                    }.foregroundColor(.black)
                }
            }
            .textFieldStyle(.automatic)
            .buttonStyle(.plain)
            .background(Color.white)
        }
    }
}


