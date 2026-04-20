//
//  LNFontUtils.swift
//
//  Modified by Joseph Levy on 25/4/24 to 19/8/24
//  From FontUtils.swift in LNSwiftUIUtils on GitHub
//  Created by Leo Natan on 21/10/2023.
//  Added support for leading and traitCollection, modified with(...) functions to use fontDescriptor

import SwiftUI

fileprivate extension UIFont {
	func with(weight: Weight? = nil, width: Width? = nil, symbolicTraits: UIFontDescriptor.SymbolicTraits? = nil,
			  feature: [UIFontDescriptor.FeatureKey: Int]? = nil) -> UIFont {
		var descriptor = fontDescriptor.withWeight(weight).withWidth(width)
		if let symbolicTraits {
			let traits = fontDescriptor.symbolicTraits.union(symbolicTraits)
			descriptor = descriptor.withSymbolicTraits(traits) ?? descriptor
		}
		if let feature { // Is this right?
			descriptor = descriptor.addingAttributes([.featureSettings: feature])
		}
		let rv = UIFont(descriptor: descriptor, size: pointSize)
		//print("Converted\n\t\(self)\nto\n\t\(rv)\n\n")
		return rv
	}
	
	func with(design: UIFontDescriptor.SystemDesign) -> UIFont? {
		guard var designedDescriptor = fontDescriptor.withDesign(design) else { return nil }
		designedDescriptor = designedDescriptor.withWeight(weight)
		return UIFont(descriptor: designedDescriptor, size: pointSize)
	}
	
	func with(featureType type: Int, selector: Int) -> UIFont? {
		return with(feature: [
			UIFontDescriptor.FeatureKey.type : type as Int,
			UIFontDescriptor.FeatureKey.selector: selector as Int
		])
	}
	
	var withBold: UIFont { with(symbolicTraits: .traitBold) }
	
	var withItalic: UIFont { with(symbolicTraits: .traitItalic) }
	
	func leading(_ leading: Font.Leading) -> UIFont {
		var traits = fontDescriptor.symbolicTraits
		switch leading {
		case .tight: traits.formUnion(.traitTightLeading)
		case .loose: traits.formUnion(.traitLooseLeading)
		case .standard: traits.remove(.traitTightLeading); traits.remove(.traitLooseLeading)
		@unknown default: break
		}
		return with(symbolicTraits: traits)
	}
	
	var monospaced: UIFont {
		let weight: UIFont.Weight
		if let existingWeight = (CTFontCopyTraits(self) as NSDictionary)[kCTFontWeightTrait as String] as? CGFloat {
			weight = UIFont.Weight(rawValue: existingWeight)
		} else {
			weight = .regular
		}
		return with(design: .monospaced) ?? UIFont(name: "Menlo", size: pointSize)!.with(weight: weight)
	}
}

public extension UIFontDescriptor.SystemDesign {
	init?(_ design: SwiftUI.Font.Design) {
		self = switch design {
		case .default: .default
		case .serif:  .serif
		case .rounded:  .rounded
		case .monospaced: .monospaced
		@unknown default: .default
		}
	}
}

public extension UIFont.Weight {
	init?(_ weight: SwiftUI.Font.Weight) {
		guard let rawValue = Mirror(reflecting: weight).descendant("value") as? CGFloat else { return nil }
		self = UIFont.Weight(rawValue)
	}
}

public extension UIFont.TextStyle {
	init(_ textStyle: SwiftUI.Font.TextStyle) {
		self = switch textStyle {
		case .largeTitle: .largeTitle
		case .title: .title1
		case .headline: .headline
		case .subheadline: .subheadline
		case .body: .body
		case .callout: .callout
		case .footnote: .footnote
		case .caption: .caption1
		case .title2: .title2
		case .title3: .title3
		case .caption2: .caption2
		@unknown default: .body
		}
	}
}

public extension SwiftUI.Font {
	func uiFont(with traitCollection: UITraitCollection = .current) -> UIFont? {
		guard let base = Mirror(reflecting: self).descendant("provider", "base") else { print("Did not convert"); return nil }
		return SwiftUI.Font.UIFontProvider(from: base, with: traitCollection)?.uiFont
	}
}

fileprivate extension SwiftUI.Font {
	enum UIFontProvider {
		case system(size: CGFloat, weight: Font.Weight?, design: Font.Design?, traitCollection: UITraitCollection = .current)
		case textStyle(Font.TextStyle, weight: Font.Weight?, design: Font.Design?, traitCollection: UITraitCollection = .current)
		case platform(CTFont)
		case named(UIFont)
		
		var uiFont: UIFont? {
			switch self {
			case let .system(size, weight, design, traitCollection):
				var rd = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body, compatibleWith: traitCollection)
				if let weight, let fontWeight = UIFont.Weight(weight) {
					rd = rd.withWeight(fontWeight)
				}
				if let design, let systemDesign = UIFontDescriptor.SystemDesign(design),
				   let designedDescription = rd.withDesign(systemDesign) {
					rd = designedDescription
				}
				return UIFont(descriptor: rd, size: size)
			case let .textStyle(textStyle, _, _, traitCollection):
				return UIFont.preferredFont(forTextStyle: UIFont.TextStyle(textStyle),compatibleWith: traitCollection)
			case let .platform(font):
				return font as UIFont
			case let .named(font):
				return font
			}
		}
		
		init?(from reflection: Any, with traitCollection: UITraitCollection = .current ) {
			let desc = String(describing: type(of: reflection));
			let mirror = Mirror(reflecting: reflection)
			
			if let regex = try? NSRegularExpression(pattern: "ModifierProvider<(.*)>"), /// Could be StaticModifierProvider too
			   let match = regex.firstMatch(in: desc, range: NSRange(desc.startIndex..<desc.endIndex, in: desc)) {
				let modifier = desc[Range(match.range(at: 1), in: desc)!]
				/// Recursion occurs in the guard statement  since sFont.uiFont inits UIFontProvider
				guard let sFont = mirror.descendant("base") as? Font, var font = sFont.uiFont(with: traitCollection)
				else { return nil }
				//	print(modifier)
				font = switch modifier {
				case "BoldModifier":
					font.withBold
				case "ItalicModifier":
					font.withItalic
				case "MonospacedModifier":
					font.monospaced
				case "MonospacedDigitModifier":
					font.with(featureType: kNumberSpacingType, selector: kMonospacedNumbersSelector) ?? font
				case "WeightModifier":
					if let weight = mirror.descendant("modifier", "weight", "value") as? CGFloat {
						font.with(weight: UIFont.Weight(rawValue: weight))
					} else { font }
				case "WidthModifier":
					if let width = mirror.descendant("modifier", "width") as? CGFloat {
						font.with(width: UIFont.Width(rawValue: width))
					} else { font }
				case "LeadingModifier":
					if let value = mirror.descendant("modifier", "leading") as? Font.Leading  {
						font.leading(value)
					} else { font }
				case "FeatureSettingModifier":
					if let type = mirror.descendant("modifier", "type")as? Int,
					   let selector = mirror.descendant("modifier", "selector") as? Int {
						font.with(featureType: type, selector: selector) ?? font
					} else { font }
				default:
					font
				}
				self = .named(font) // This UIFont is the SwiftUI.Font tree so far
				return
			}
			
			switch desc {
			case "SystemProvider":
				let props: (size: CGFloat?, weight: Font.Weight?, design: Font.Design?) = (
					mirror.descendant("size") as? CGFloat,
					mirror.descendant("weight") as? Font.Weight,
					mirror.descendant("design") as? Font.Design
				)
				guard let size = props.size else { return nil }
				self = .system( size: size, weight: props.weight, design: props.design, traitCollection: traitCollection)
				
			case "TextStyleProvider":
				let props: (style: Font.TextStyle?, weight: Font.Weight?, design: Font.Design?) = (
					mirror.descendant("style") as? Font.TextStyle,
					mirror.descendant("weight") as? Font.Weight,
					mirror.descendant("design") as? Font.Design
				)
				
				guard let style = props.style else { return nil }
				self = .textStyle(style, weight: props.weight, design: props.design, traitCollection: traitCollection)
				
			case "PlatformFontProvider":
				guard let font = mirror.descendant("font") as? UIFont else { return nil }
				self = .platform(font)
				
			case "NamedProvider":
				guard let name = mirror.descendant("name") as? String, let size = mirror.descendant("size") as? CGFloat
				else { return nil }
				
				let font = UIFont(name: name, size: size)
				guard var font else { return nil }
				if let textStyle = mirror.descendant("textStyle") as? SwiftUI.Font.TextStyle {
					font = UIFontMetrics(forTextStyle: UIFont.TextStyle(textStyle))
						.scaledFont(for: font, compatibleWith: traitCollection)
				}
				self = .named(font)
				
			default: print("Unhandled Font?")
				return nil
			}
		}
	}
}

// MARK: - NSAttributedString ↔ AttributedString helpers

/// Conversion code for SwiftUI.Font to UIFont in AttributedString to NSAttributedString and vice versa starts here
extension NSAttributedString {
	public var attributedStringFromUIKit : AttributedString {
		(try? AttributedString(self, including: \.uiKit)) ?? AttributedString(self)
	}
	
	convenience init(_ attributed: AttributedString) {
		do {
			let ns = try NSAttributedString(attributed, including: \.uiKit)
			self.init(attributedString: ns)
		} catch {
			self.init(string: String(attributed.characters))
		}
	}
	
	public func calculateSize(maxWidth: CGFloat = .greatestFiniteMagnitude) -> CGSize {
		let boundingRect = self.boundingRect(
			with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
			options: [.usesLineFragmentOrigin, .usesFontLeading],
			context: nil
		)
		return CGSize(width: ceil(boundingRect.width), height: ceil(boundingRect.height))
	}
}

public extension AttributeContainer {
	func swiftUIToUIKit(with traitCollection: UITraitCollection = .current) -> AttributeContainer {
		var rv = self
		if let font = rv.swiftUI.font, rv.uiKit.font == nil { //debugPrint("Converting font")
			rv.uiKit.font = font.uiFont(with: traitCollection)
		}
		if rv.uiKit.font == nil { //print("b",terminator: "")
			rv.uiKit.font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
		}
		if let foregroundColor = rv.swiftUI.foregroundColor {
			rv.uiKit.foregroundColor = UIColor(foregroundColor)
		} else { rv.uiKit.foregroundColor = rv.uiKit.foregroundColor ?? .label }
		if let backgroundColor = rv.swiftUI.backgroundColor, rv.uiKit.backgroundColor == nil {
			rv.uiKit.backgroundColor = UIColor(backgroundColor)
		}
		if let strikethroughStyle = rv.swiftUI.strikethroughStyle {
			let mirror = Mirror(reflecting: strikethroughStyle)
			let style = mirror.descendant("nsUnderlineStyle") as? NSUnderlineStyle
			let color = mirror.descendant("color") as? SwiftUI.Color
			rv.uiKit.strikethroughStyle = style
			if let color { rv.uiKit.strikethroughColor = UIColor(color) }
		}
		if let underlineStyle = rv.swiftUI.underlineStyle {
			let mirror = Mirror(reflecting: underlineStyle)
			let style = mirror.descendant("nsUnderlineStyle") as? NSUnderlineStyle
			let color = mirror.descendant("color") as? SwiftUI.Color
			
			rv.uiKit.underlineStyle = style
			if let color { rv.uiKit.underlineColor = UIColor(color) }
		}
		if let kern = rv.swiftUI.kern { rv.uiKit.kern = kern }
		
		if let tracking = rv.swiftUI.tracking {	rv.uiKit.tracking = tracking }
		
		if let baselineOffset = rv.swiftUI.baselineOffset { rv.uiKit.baselineOffset = baselineOffset }
		
		return rv
	}
}

extension AttributedString {
	/// Creates an AttributedString from a plain String with an explicit SwiftUI font. No default to avoid conflict with AttributedString(_ : , attributes:)
	public init(_ string: String, font: Font) { 
		self.init(stringLiteral: string)
		self.font = font
		self.uiKit.font = UIFont(font: font)  // uses LNFontUtils UIFont(font:) init
	}
	
	public func nsAttributedString(with traitCollection: UITraitCollection = .current) -> NSMutableAttributedString {
		runs.reduce(into: NSMutableAttributedString()) {
			$0.append(NSAttributedString(AttributedString(self[$1.range]).settingAttributes($1.attributes.swiftUIToUIKit())))
		}
	}
	
	init(_ ns: NSAttributedString) {
		self = ns.attributedStringFromUIKit
	}
	
	public func calculateSize(maxWidth: CGFloat = .greatestFiniteMagnitude) -> CGSize {
		return self.nsAttributedString().calculateSize(maxWidth: maxWidth)
	}
	
	/// AttributedString(styledMarkdown: String, fonts: [Font]) puts fonts into Headers 1-6 shown in list and setFont for SwiftUI.Font, along with setBold, and setItalic
	/// that work with SwiftUI.Font and UIFont embedded in the attributed string
	public init(styledMarkdown markdownString: String,//Header0,     1,        2,     3,      4,      5,        6
				fontStyles: [Font.TextStyle]      =      [.body,.largeTitle,.title,.title2,.title3,.headline,.subheadline],
				insertCR: Bool = true) throws {
		var output = try AttributedString(
			markdown: markdownString,
			options: .init(
				allowsExtendedAttributes: true,
				interpretedSyntax: .full,
				failurePolicy: .returnPartiallyParsedIfPossible
			),
			baseURL: nil
		)
		typealias IntentAttribute = AttributeScopes.FoundationAttributes.PresentationIntentAttribute
		for (intentBlock, intentRange) in output.runs[IntentAttribute.self].reversed() {
			guard let intentBlock = intentBlock else { continue }
			for intent in intentBlock.components {
				if case .header(level: let level) = intent.kind {
					if level > 0 && level < fontStyles.count {
						output[intentRange].font =
						UIFont.preferredFont(forTextStyle: UIFont.preferredFontStyle(from: fontStyles[level]))
					}
				}
			}
			if insertCR && intentRange.lowerBound != output.startIndex {
				output.characters.insert(contentsOf: "\n", at: intentRange.lowerBound)
			}
		}
		self = output
	}
	
	public func setFont(to: Font) -> AttributedString {
		var a = self
		a.font = to
		return a
	}
	
	public func setBold() -> AttributedString {
		runs.reduce(into: self) { newAS, run in
			if let uiFont = run.uiKit.font {
				newAS[run.range].font = uiFont.bold()
			} else {
				newAS[run.range].font = (run.font ?? .body).bold()
			}
		}
	}
	
	public func setItalic() -> AttributedString {
		runs.reduce(into: self) { newAS, run in
			if let uiFont = run.uiKit.font {
				let isBold = uiFont.contains(trait: .traitBold)
				newAS[run.range].font = isBold ?
				uiFont.italic()?.withWeight(.bold) ?? uiFont.bold() :
				uiFont.italic()
			} else {
				newAS[run.range].font = (run.font ?? .body).italic()
			}
		}
	}
	
	public func setUnderline() -> AttributedString {
		var newAS = self
		newAS.underlineStyle = NSUnderlineStyle(.single)
		return newAS
	}
}

extension String {
	public func markdownToAttributed() -> AttributedString {
		do { return try AttributedString(styledMarkdown: self) }
		catch { return AttributedString(stringLiteral: "Error parsing markdown \(error)") }
	}
}

/// Convenient extensions of UIFont and UIFontDescriptor
extension UIFont {
	public convenience init(font: Font, traitCollection: UITraitCollection = .current) {
		if let uiFont = font.uiFont(with: traitCollection) {
			self.init(descriptor: uiFont.fontDescriptor, size: 0)
		} else { self.init() }
	}
	// get font weight
	public var weight: UIFont.Weight? { fontDescriptor.weight }
	// get font width
	public var width: UIFont.Width { fontDescriptor.width }
	// Add bold trait
	public func bold() -> UIFont? {
		guard let newDescriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(.traitBold))
		else { return nil }
		return UIFont(descriptor: newDescriptor.withWidth(width), size: pointSize)
	}
	// Add italic trait
	public func italic() -> UIFont? {
		guard let newDescriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(.traitItalic))
		else { return nil }
		return UIFont(descriptor: newDescriptor.withWeight(weight).withWidth(width), size: pointSize)
	}
	public func withWeight(_ weight: UIFont.Weight?) -> UIFont {
		guard let weight else { return self }
		return UIFont(descriptor: fontDescriptor.withWeight(weight), size: pointSize)
	}
	public func withWidth(_ width: UIFont.Width?) -> UIFont {
		guard let width else { return self }
		return UIFont(descriptor: fontDescriptor.withWidth(width), size: pointSize)
	}
	// Return UIFont.TextStyle from SwiftUI.Font.TextStyle
	public class func preferredFontStyle(from: Font.TextStyle) -> UIFont.TextStyle  {
		UIFont.TextStyle(from)
	}
	func contains(trait: UIFontDescriptor.SymbolicTraits) -> Bool {
		fontDescriptor.contains(trait: trait)
	}
	func toggleSymbolicTrait(_ symbolicTraits: UIFontDescriptor.SymbolicTraits) -> UIFont {
		UIFont(descriptor: fontDescriptor.toggleSymbolicTrait(symbolicTraits),size: pointSize)
	}
}

extension UIFontDescriptor {
	func toggleSymbolicTrait(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFontDescriptor {
		withSymbolicTraits(contains(trait: traits) ? symbolicTraits.subtracting(traits) : symbolicTraits.union(traits))!
	}
	func contains(trait: UIFontDescriptor.SymbolicTraits) -> Bool {
		symbolicTraits.contains(trait)
	}
	public func withWeight(_ weight: UIFont.Weight?) -> UIFontDescriptor {
		weight == nil ? self :  addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
	}
	public func withWidth(_ width: UIFont.Width?) -> UIFontDescriptor {
		width == nil ? self : addingAttributes([.traits: [UIFontDescriptor.TraitKey.width: width]])
	}
	public var weight: UIFont.Weight { // nil means no weight trait is set
		let traits = object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any] ?? [:]
		guard let weightNumber = traits[.weight] as? NSNumber else { return .regular }
		return UIFont.Weight(rawValue: weightNumber.doubleValue)
	}
	public var width: UIFont.Width {
		let traits = object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any] ?? [:]
		guard let widthNumber = traits[.width] as? NSNumber else { return .init(0) }
		return UIFont.Width(rawValue: widthNumber.doubleValue)
	}
}
