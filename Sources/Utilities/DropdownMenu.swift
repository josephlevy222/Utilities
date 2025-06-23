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

// Picker does not support Text Attributes in dropdown
public struct DropdownPicker: View {
    public init(placeHolder: AttributedString = HTMLParser("<gray>Unselected</gray>").attributedString, selection: Binding<Int>, options: [AttributedString]) {
        self.placeHolder = placeHolder
        self._selection = selection
        self.options = options
    }
    
    var placeHolder = HTMLParser("<gray>Unselected</gray>").attributedString
    @Binding var selection: Int
    let options: [AttributedString]
    public var body: some View {
        Picker("", selection: $selection){
            ForEach(options.indices, id: \.self) { i in
				Text(options[i])
            }
        }.pickerStyle(.menu)
    }
}
// Menu does not support Text Attributes in dropdown
public struct DropdownMenu: View {
    public init(placeHolder: String = "Unselected", selection: Binding<Int>, options: [String]) {
        self.placeHolder = placeHolder
        self._selection = selection
        self.options = options
    }
    
    // Menu does not support Text Attributes in dropdown
    var placeHolder = "Unselected"
    @Binding var selection: Int
	@State var showMenu = false
    let options: [String]
    public var body: some View {
        Menu {
            ForEach(options.indices, id:\.self) { i in
                Button(action: { selection = i }) {
					Text(options[i])
                }
            }
        } label: {
            (options.indices.contains(selection)
                ? Text(options[selection])
                : Text(placeHolder).foregroundColor(.gray))
		}.menuStyle(DropdownMenuStyle())//.buttonStyle(.plain)
    }
}

// Menu does not support Text Attributes in dropdown
public struct DropdownMenuAttributedText: View {
	public init(placeHolder: String = "Unselected", selection: Binding<Int>, options: [AttributedString]) {
		self.placeHolder = placeHolder
		self._selection = selection
		self.options = options
		self.optionImages = options.map { option in
			Image(uiImage: Text(option).foregroundStyle(.black).snapshot())}
	}
	
	// Menu does not support Text Attributes in dropdown
	var placeHolder = "Unselected"
	@Binding var selection: Int
	@State var showMenu = false
	let options: [AttributedString]
	let optionImages: [Image]
	public var body: some View {
		Menu {
			ForEach(options.indices, id:\.self) { i in
				Button { selection = i } label: {
					Text(options[i])}
			}
		} label: {
			(options.indices.contains(selection)
			 ? Text(options[selection])
			 : Text(placeHolder).foregroundColor(.gray))
		}.menuStyle(DropdownMenuStyle())//.buttonStyle(.plain)
	}
}

 extension View {
	func snapshot() -> UIImage {
		let controller = UIHostingController(rootView: self.edgesIgnoringSafeArea(.all))
		/// Note: The.edgesIgnoringSafeArea(.all) is needed too avoid clipping
		let targetSize = controller.view.intrinsicContentSize
		controller.view.bounds = CGRect(origin: .zero, size: targetSize)
		controller.view.backgroundColor = .clear
		let renderer = UIGraphicsImageRenderer(size: targetSize)
		return renderer.image { _ in
			controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
		}
	}
}

struct MenuList : View {
	var texts: [AttributedString]
	@Binding var selection: Int
	@Binding var showMenu: Bool
	var alignment: TextAlignment = .leading
	var body: some View {
		List {
			Section(header: Text("Select One")) {
				ForEach(texts.indices, id:\.self) { i in
					Text(texts[i])
						.onTapGesture {
							selection = i
							showMenu = false
						}
				}.frame(width: 210)
			}
		}.frame(width: 210, height: 280)
	}
}

/// This is a Button with a Text label using a AttributedString and HTMLParser styling
/// The options array has the AttributedStrings that are chosen from the popover displayed
/// when the Button is pushed and the selection Binding is set to that element
/// A placeHolder is used for selections that are out of range in option can be set
public struct Dropdown: View {

    public init(placeHolder: AttributedString = HTMLParser("<gray>Unselected</gray>").attributedString, selection: Binding<Int>, options: [AttributedString]) {
        self.placeHolder = placeHolder
        self._selection = selection
        self.options = options
    }
    
    public var placeHolder = HTMLParser("<gray>Unselected</gray>").attributedString
    @Binding public var selection: Int
    public let options: [AttributedString]
    @State private var showDropDown = false
    public var body: some View {
        Button(action:  { showDropDown = true }) {
            Text(options.indices.contains(selection) ?
                 options[selection] :
                    placeHolder )//.horizontalFill()
        }
        .popover(isPresented: $showDropDown, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
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
            //.background(Color.white)
        }
    }
}


//#Preview {
	struct Preview: View {
		@State private var selection = 0
		var texts = [
			"\u{03b5}<sub>1</sub>            \u{03b5}<sub>2</sub>"
			,"n             k"
			,"       n        \u{03b1}(cm<sup>-1</sup>)"
			,"Al<sub>x</sub>Ga<sub>1-x</sub>As  \u{03b1}(cm<sup>-1</sup>)"
			,"In<sub>x</sub>Ga<sub>1-x</sub>As<sub>y</sub>P<sub>1-y</sub>"
		].map { HTMLParser($0).attributedString }
		@State var fixed = false
		var body: some View {
			VStack {
				//DropdownMenu(selection: $selection, options: ["Permitivity","Index","Index/Loss","AlGaAs","InGaASP"])
				//DropdownMenuAttributedText(selection: $selection, options: texts)
				Dropdown(selection: $selection, options: texts)
				
				Button(action: { selection = selection + 1; if selection == 5 {selection = 0 } }) {
					Text(texts[selection])
				}
			}
		}
	}
	//return Preview()
//}

// MARK: - Example Usage
let options1 = createAttributedOptions()
let options2 = createLongAttributedOptions()
struct Preview2: View {
	@State private var selection = 0
	@State private var selectedText1 = AttributedString("Select an option")
	@State private var selectedText2 = AttributedString("Select an option")
	@State private var dropdown = false
	var body: some View {
		ZStack {
			GeometryReader { geometry in
				ScrollView {
					VStack(spacing: 30) {
						Text("Smart AttributedString Dropdown")
							.font(.headline)
							.fontWeight(.bold)
							.padding()
						
						// Top dropdown (should open downward)
						VStack(spacing: 8) {
							Text("Smart Dropdown (top of screen):")
								.font(.headline)
							Dropdown(selection: $selection, options: options1
									 //							Dropdown(
									 //								options: createAttributedOptions(),
									 //								selectedOption: selectedText1,
									 //								onSelectionChanged: { newSelection in
									 //									selectedText1 = newSelection
									 //								}//,
									 //dropdown: $dropdown
							)
							.frame(maxWidth: 250)
						}
						
						Spacer()//minLength: 300)
						
						// Middle content
						ZStack {
							Rectangle()
								.fill(Color.blue.opacity(0.5))
								.frame(height: 150)
							Text("Content that shows dropdown doesn't affect layout")
								.foregroundColor(.white)
								.multilineTextAlignment(.center)
						}
						//.zIndex(-1)
						
						Spacer()
						
						// Bottom dropdown (should open upward)
						VStack(alignment: .leading, spacing: 8) {
							Text("Ultra Smart Dropdown (bottom area):")
								.font(.headline)
							
							Dropdown(
								selection: $selection,
								options: options2
								//								,maxDropdownWidth: 280,
								//								selectedOption: selectedText2,
								//								onSelectionChanged: { newSelection in
								//									selectedText2 = newSelection
								//}//,
								//dropdown: $dropdown
							)
							.frame(maxWidth: 200)
						}
						
						Text("Selected: \(options2[selection])")
							.padding()
							.background(Color.gray.opacity(0.1).background(Color.white))
							.cornerRadius(8)
						
						Spacer(minLength: 100)
					}
					.padding(.horizontal)
				}
			}
			//			Color.gray.opacity(dropdown ? 0.1 : 0).onTapGesture {
			//				dropdown = false
			//			}
		}
	}
}
private func createAttributedOptions() -> [AttributedString] {
	var options: [AttributedString] = []
	
	var boldText = AttributedString("Bold Text")
	if #available(iOS 16.0, *) {
		boldText.font = .boldSystemFont(ofSize: 16)
	}
	options.append(boldText)
	
	var italicText = AttributedString("Italic Text")
	if #available(iOS 16.0, *) {
		italicText.font = .italicSystemFont(ofSize: 16)
	}
	options.append(italicText)
	
	var coloredText = AttributedString("Colored Text")
	if #available(iOS 16.0, *) {
		coloredText.foregroundColor = .blue
	}
	options.append(coloredText)
	
	var combinedText = AttributedString("Bold + Colored")
	if #available(iOS 16.0, *) {
		combinedText.font = .boldSystemFont(ofSize: 16)
		combinedText.foregroundColor = .red
	}
	options.append(combinedText)
	
	return options
}

private func createLongAttributedOptions() -> [AttributedString] {
	var options = createAttributedOptions()
	
	var underlinedText = AttributedString("Underlined Option")
	if #available(iOS 16.0, *) {
		underlinedText.underlineStyle = .single
	}
	options.append(underlinedText)
	
	var strikethroughText = AttributedString("Strikethrough Option")
	if #available(iOS 16.0, *) {
		strikethroughText.strikethroughStyle = .single
	}
	options.append(strikethroughText)
	
	options.append(AttributedString("Very Long Text Option That Might Need Wrapping"))
	options.append(AttributedString("Another Long Option"))
	
	return options
}
//}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		Preview2()
	}
}

