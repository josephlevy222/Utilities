//
//  HTMLParser.swift
//
//  Created by Joseph Levy on 10/22/21.
//
//  based on
//  HTML2TextParser.swift
//
//  Created by Никита Белокриницкий on 11.03.2021.
//

import SwiftUI
import Foundation

/**
 Parser for converting HTML-tagged text to SwiftUI Text View.
 
 - warning: **Only single-word tags are supported**. Tags with more than one word or
 containing any characters besides **letters** or **numbers** are ignored and not removed.
 
 # Notes:
 1. Handles unopened/unclosed tags.
 2. Deletes tags that have no modifiers.
 3. Does **not** handle HTML characters, for example `&lt;`.
 */

public typealias Tags = Dictionary<String, (((HTMLParser) -> Void), Bool ) >

public class HTMLParser {
    //@Environment(\.sizeCategory) var fontSizeCategory // Use to set size of fonts
    /// The result of the parser's work.
    private(set) public var attributedString = AttributedString("")
    /// HTML-tagged String
    public var attributes = AttributeContainer() // Used by actions in Dictionary
    public func set(_ modification: AttributeContainer) -> Void { attributes = modification }
    private var _htmlString : String
    public var htmlString : String {
        get { return self._htmlString }
        set { self._htmlString = newValue; parse() }
    }
    /// Set of currently active tags.
    private var tags: [String] = []
    /// Uses Array since Set<String> does not keep order
    /// and OrderedSet requires Collection to be imported
   
    /// Set of supported tags and associated modifiers.
    private let availableTags: Tags?
    
    var fontSize : CGFloat = 17 /// Used for sub and superscripts
    /**
     Creates a new parser instance.
     
     - parameter htmlString: HTML-tagged string.
     - parameter availableTags: Set of supported tags and associated modifiers.
     */
    init(_ htmlString: String, availableTags: Tags? = nil) {
        self._htmlString = htmlString
        self.availableTags = availableTags
        parse()
    }
    
    /// Starts the text parsing process. The results of this method will be placed in the `attributedString` variable.
    private func parse() {
        var tag: String? = nil
        var endTag: Bool = false
        var startIndex = _htmlString.startIndex
        var endIndex = _htmlString.startIndex
        for index in _htmlString.indices {
            switch _htmlString[index] {
            case "<":
                tag = String()
                endIndex = index
                continue
                
            case "/":
                if index != _htmlString.startIndex && _htmlString[_htmlString.index(before: index)] == "<" {
                    endTag = true
                } else {
                    tag = nil
                }
                continue
                
            case ">":
                if let tag = tag {
                    addChunkOfAttributedString(String(_htmlString[startIndex..<endIndex]))
                    let lcTag = tag.lowercased()
                    if endTag {
                        tags = tags.filter { $0 != lcTag } // remove tag
                        endTag = false
                    } else {
                        if !tags.contains(lcTag) { // only one of each tag allowed
                            tags.append(lcTag)
                        }
                    }
                    startIndex = _htmlString.index(after: index)
                }
                tag = nil
                continue
                
            default:
                break
            }
            
            if tag != nil {
                if _htmlString[index].isLetter || _htmlString[index].isHexDigit {
                    tag?.append(_htmlString[index])
                }
            }
        }
        
        endIndex = _htmlString.endIndex
        if startIndex != endIndex {
            addChunkOfAttributedString(String(_htmlString[startIndex..<endIndex]))
        }
    }
    
    private func addChunkOfAttributedString(_ string: String) {
        guard !string.isEmpty else { return }
        lazy var secondTags : [String] = []
        attributes = AttributeContainer()
        let currentTags = availableTags ?? standardTags
        for tag in tags { // Add font setting tags
            if let (action, doFirst ) = currentTags[tag] {
                if doFirst { action(self) }
                else { secondTags.append(tag) }// Add tag to secondTags
            }
        }
        for tag in secondTags { // do modifying tags second
            if let (action, _) = currentTags[tag] { action(self) }
        }
        attributedString += AttributedString(string, attributes: attributes)
    }
    
    public func font(_ fontValue: Font)  {
        #if os(iOS)
        fontSize = UIFontMetrics.default.scaledValue(for: fontSizes[fontValue] ?? CGFloat(17.0))
        #else
        fontSize = fontSizes[fontValue] ?? CGFloat(17.0)
        #endif
        attributes = attributes.font(fontValue)
    }
    
    var font : Font { attributes.font ?? .body }
    var subFont : Font { subFontLookup[attributes.font ?? .body]!}
    
}
/**
 - warning: **Only single-word tags are supported**. Tags with more than one word or
 containing any characters besides **letters** or **numbers** are ignored and not removed.
 
 # Notes
 1. Basic modifiers can still be applied, such as changing the font and color of the text.
 2. Handles unopened/unclosed tags.
 3. Supports overlapping tags.
 4. Deletes tags that have no modifiers.
 5. Does **not** handle HTML characters such as `&amp;`.
 
 # Example
 ```
 var attributedString = HTMLParser("This is <b>bold</b> and <i>italic</i> text.").attributedString
 Text(attributedString)
 .foregroundColor(.blue)
 .font(.title)
 .padding()
 ```
 */

/// Set of supported tags and associated modifiers. This is used by default for all HTMLParser
/// instances except those for which the parameter availableTags: is defined in the initializer.

public let standardTags:  Tags  = [
/**
    This modifier set is presented just for reference.
    Set the necessary attributes and modifiers for your needs before use
    
    If the font is set, then make the Bool true which setFont does for you
    Because using bold() or strikethrough only makes sense
    when done after the font is set, if no font  .body is used
    
    If the font is only modified then set Bool false
    tags with true are executed before those with false
*/
    "h1": setFont(.largeTitle),
    "h2": setFont(.title),
    "h3": setFont(.headline),
    "h4": setFont(.subheadline),
    "h5": setFont(.callout),
    "h6": setFont(.caption),
    "base": setFont(.body),
    "body": setFont(.body),
    "n" : setFont(.body),
    "f":  setFont(.footnote),
    
    "sup": ({
        $0.font($0.subFont)
        $0.set($0.attributes.baselineOffset( $0.fontSize*0.3))
    }, true),
    
    "sub": ({
        $0.font($0.subFont)
        $0.set($0.attributes.baselineOffset(-$0.fontSize*0.4))
    }, true),

    "s": ({ $0.set($0.attributes.strikethroughStyle(.single)) }, false),
    "u": ({ $0.set($0.attributes.underlineStyle(.single)) }, false),
    
    "i": ({ $0.font($0.font.italic())}, false),
    "b": ({ $0.font($0.font.weight(.bold))  }, false),
    
    "gray": ( { $0.set($0.attributes.foregroundColor(.gray)) }, false),
    "red" : ( { $0.set($0.attributes.foregroundColor(.red )) }, false),
    "blue" : ( { $0.set($0.attributes.foregroundColor(.blue)) } , false),
]

// setFont is defined to make creating a font style Dictionary
// entry very simple.  See examples above.
//@available(iOS 15, *)
func setFont(_ fontValue: Font) -> (((HTMLParser) -> Void), Bool )
{ ( { $0.font(fontValue)},true) }

// These fontSizes are for the SF-Pro font which is default
// They are used in a relative way
/// Maybe some environment value should scale them?
var fontSizes : Dictionary< Font, CGFloat > = [
    .body : 17,
    .title : 28,
    .headline : 17,
    .subheadline : 15,
    .callout : 16,
    .caption : 12,
    .caption2 : 11,
    .footnote : 13,
    .largeTitle : 34,
    .title2 : 22,
    .title3 : 20
]


// Determines the best font to use in subscript and superscripts
// Based on the sizes above
var subFontLookup : Dictionary< Font, Font > = [
    .caption2 : .caption2,
    .caption : .caption2,
    .footnote : .caption2,
    .subheadline : .caption2,
    .callout : .caption,
    .body : .footnote,
    .headline : .footnote,
    .title3 : .subheadline,
    .title2 : .body,
    .title : .title3,
    .largeTitle : .title
]


