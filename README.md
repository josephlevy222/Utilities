# Utilities

Various additions to SwiftUI and iOS 15/ macOS 12

CaptureSize+RotatedText 
- Supports preferenceKeys for view size passing up the hierarchy and rotated text which has a frame sized correctly

CheckBoxView 
- Gives a small checkbox as an alternative to a toggle

ColorExtension 
- Adds
    components  - to get the ARGB of a Color  
    sARGB - to get an Int with that is 0xAARRGGBB 
    init(sARGB: Int) - to create Color from sARGB Int

DropdownMenu
- Adds 
    Dropdown to get a popup menu from options: [AttributedString]
    DropdownMenu to get a Menu from options (needs work)

HTMLParser
- makes an AttributedString from a String with user defined Tags a la HTML
