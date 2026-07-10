import UIKit

extension UIColor {
    static func hexColor(_ hex: String) -> UIColor {
        return hexColor(hex, alpha: 1.0)
    }
    
    static func hexColor(_ hex: String, alpha: CGFloat) -> UIColor {
        var cString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if cString.count < 6 {
            return .clear
        }
        
        if cString.hasPrefix("0X") || cString.hasPrefix("0x") {
            cString = String(cString.dropFirst(2))
        }
        
        if cString.hasPrefix("#") {
            cString = String(cString.dropFirst())
        }
        
        if cString.count != 6 {
            return .clear
        }
        
        let startIndex = cString.startIndex
        let rString = String(cString[startIndex..<cString.index(startIndex, offsetBy: 2)])
        let gString = String(cString[cString.index(startIndex, offsetBy: 2)..<cString.index(startIndex, offsetBy: 4)])
        let bString = String(cString[cString.index(startIndex, offsetBy: 4)..<cString.index(startIndex, offsetBy: 6)])
        
        var r: UInt64 = 0
        var g: UInt64 = 0
        var b: UInt64 = 0
        
        Scanner(string: rString).scanHexInt64(&r)
        Scanner(string: gString).scanHexInt64(&g)
        Scanner(string: bString).scanHexInt64(&b)
        
        return UIColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: alpha
        )
    }
}

