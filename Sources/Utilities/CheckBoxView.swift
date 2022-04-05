//
//  CheckBoxView.swift
//  ModeAnalyzer-1D
//
//  Created by Joseph Levy on 2/2/22.
//

import Foundation
import SwiftUI


public struct CheckBoxView: View {
    @Binding var checked: Bool
    public init(checked: Binding<Bool>) {self._checked = checked} 
    public var body: some View {
        Image(systemName: checked ? "checkmark.square.fill" : "square")
            .foregroundColor(checked ? Color.accentColor : Color.secondary).frame(width: nil)
            .onTapGesture {
                self.checked.toggle()
            }
    }
}

struct CheckBoxView_Previews: PreviewProvider {
    struct CheckBoxViewHolder: View {
        @State var checked = false

        var body: some View {
            CheckBoxView(checked: $checked)
        }
    }

    static var previews: some View {
        CheckBoxViewHolder()
    }
}
