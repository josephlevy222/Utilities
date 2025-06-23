//
//  CustomDropdown.swift
//
//
//  Created by Joseph Levy on 9/11/24.
//

import SwiftUI

struct CustomDropdown: View {
	internal init(selectedOption: Binding<AttributedString?>, options: [AttributedString], isExpanded: Binding<Bool> ) {
		self._selectedOption = selectedOption
		self.options = options
		self._isExpanded = isExpanded
	}
	
	@Binding var isExpanded : Bool//= false
	@Binding var selectedOption: AttributedString?
	
	// Sample dropdown options with AttributedStrings
	let options: [AttributedString]
	@State private var optionsSize : CGSize = .zero
	@State private var fullSize: CGSize = .zero
	@State private var height: CGFloat = .zero
	@Environment(\.isEnabled) var isEnabled
	var body: some View {
		GeometryReader { proxy in
			
			ZStack {
				VStack {
					ForEach(options.indices, id:\.self) {
						if $0 == options.count - 1 {Text(options[$0]).padding(.horizontal)}
						else { Text(options[$0]).padding()}
					}
				}.captureSize(in: $optionsSize)
					.opacity(0)
				ZStack {
					Color(UIColor.label).opacity(isExpanded ? 0.1 : 0).onTapGesture {isExpanded = false }
						.offset(x: -12)
						.ignoresSafeArea()
					VStack(spacing: 0){
						Button(action: {}) {
							HStack {
								Text("Select an option")
								Image(systemName:  "chevron.up" )
							}
						}
					}
					.captureHeight(in: $height).opacity(0)}

				VStack {
					// The dropdown button showing the selected option or a default text
					Button(action: {
						withAnimation {
							isExpanded.toggle() // Toggle dropdown visibility
						}
					}) {
						HStack {
							// Show the selected option or placeholder
							if let selectedOption = selectedOption {
								Text(selectedOption)
							} else {
								Text("Select an option")
									.foregroundColor(.gray)
							}
							Spacer()
							Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
								.foregroundColor(.gray)
						}
						.frame(width: optionsSize.width)
						.padding()
						.background(Color(UIColor.secondarySystemBackground))
						.cornerRadius(8)
					}
					Spacer() // Use spacer to push the button to the top
				}.frame(width: 760)
				
				
				// The modal dropdown menu (conditionally shown)
				.overlay {
					if isExpanded {
						VStack(spacing: 0) {
							ForEach(options.indices, id: \.self) { index in
								Button(action: {
									selectedOption = options[index] // Update the selected option
									withAnimation {
										isExpanded = false // Collapse the dropdown
									}
								}) {
									Text(options[index]).padding(.horizontal)
										.frame(width: optionsSize.width, alignment: .leading)
										.padding()
									//.background(Color(UIColor.systemBackground))
									//.cornerRadius(8)
									
								}
								.buttonStyle(PlainButtonStyle()) // Remove default button styling
								Divider()
							}.frame(width: optionsSize.width) // Adjusts width as needed
							Spacer()
						}.frame(height: optionsSize.height)
							.background(Color(UIColor.secondarySystemBackground))
							.cornerRadius(8)
							.shadow(radius: 5)
							.padding()
							.offset(x: -16, y: optionsSize.height/2.0-proxy.frame(in: .global).height/2.0+height+20+20)
					}
				}
				
				
				
			}.onAppear {
				let frame = proxy.frame(in: .global)
				print("size: \(proxy.size)")
				print("inset: \(proxy.safeAreaInsets)")
				print("frame: \(String(describing: proxy.frame))")
				print("frame minX, maxX, minY, maxY, width, height")
				print(frame.minX, frame.maxX, frame.minY, frame.maxY, frame.width, frame.height)
			}
			
		}
	}
}



#Preview {
	
	struct Preview : View {
		@State var selection : AttributedString?
		@State var isExpanded: Bool = false
		let texts = [
			"\u{03b5}<sub>1</sub>            \u{03b5}<sub>2</sub>"
			,"n             k"
			,"n        \u{03b1}(cm<sup>-1</sup>)"
			,"Al<sub>x</sub>Ga<sub>1-x</sub>As  \u{03b1}(cm<sup>-1</sup>)"
			,"In<sub>x</sub>Ga<sub>1-x</sub>As<sub>y</sub>P<sub>1-y</sub>"
		].map { HTMLParser($0).attributedString }
		var body: some View {
			VStack {
				HStack {
					CustomDropdown(selectedOption: $selection, options: texts, isExpanded: $isExpanded)
						.padding(.leading).frame(width: 220, height: 50)
					Spacer()
					Text("More Text ")
				}
				Spacer()
			}
		
		}
	}
	return Preview()
}
