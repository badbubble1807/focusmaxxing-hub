//
//  FMXFont.swift
//  Focusmaxxing Hub
//
//  Manrope, which is what focusmaxxing is set in.
//
//  the extension popup and the windows app load it as woff2 out of the fonts/ folder at the top of
//  the desktop repository. a phone cannot read woff2, and the only file Google publishes on GitHub
//  is the variable one, whose default instance is ExtraLight - ship that and every screen comes out
//  thin. so scripts/fmx/get-fonts.js fetches five real static faces and drops them in
//  AltStore/Resources; Info.plist names them under UIAppFonts.
//
//  the names below are not a guess and not a pattern: they were read out of the files themselves.
//  Google builds these faces from the variable font, whose family is "Manrope ExtraLight", so every
//  one of them is called ManropeExtraLight-something whatever weight it actually is. Their
//  usWeightClass really is 400, 500, 600, 700 and 800.
//
//  nothing here can fail loudly on a phone, so everything falls back: a face that did not register
//  gives the system font at the same size and weight, which is what the app looked like before.
//

import UIKit
import CoreText

enum FMXFont {
    // the file in the bundle, and the name the face calls itself once it is registered
    private static let faces: [(file: String, name: String, weight: UIFont.Weight)] = [
        ("Manrope-400", "ManropeExtraLight-Regular", .regular),
        ("Manrope-500", "ManropeExtraLight-Medium", .medium),
        ("Manrope-600", "ManropeExtraLight-SemiBold", .semibold),
        ("Manrope-700", "ManropeExtraLight-Bold", .bold),
        ("Manrope-800", "ManropeExtraLight-ExtraBold", .heavy),
    ]

    /// Manrope at a size and a weight, or the system font if it is not there.
    static func of(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let name = FMXFont.name(for: weight)
        if let font = UIFont(name: name, size: size) { return font }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    /// Manrope with figures that all take the same width, for anything that counts. Its ordinary
    /// figures are proportional - a 1 is a third narrower than a 0 - so a countdown drawn in them
    /// shuffles sideways as it ticks. The font carries a "tnum" feature for exactly this, and
    /// theme.css asks for the same thing (`font-variant-numeric: tabular-nums`) on the switch and
    /// every clock in the other two apps.
    static func counting(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = FMXFont.of(size, weight)
        let settings: [[UIFontDescriptor.FeatureKey: Any]] = [[
            .type: kNumberSpacingType,
            .selector: kMonospacedNumbersSelector,
        ]]
        let descriptor = base.fontDescriptor.addingAttributes([.featureSettings: settings])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// the closest face we ship. nothing lighter than regular is bundled, because nothing in the
    /// product is set lighter than regular.
    private static func name(for weight: UIFont.Weight) -> String {
        switch weight {
        case .black, .heavy: return "ManropeExtraLight-ExtraBold"
        case .bold: return "ManropeExtraLight-Bold"
        case .semibold: return "ManropeExtraLight-SemiBold"
        case .medium: return "ManropeExtraLight-Medium"
        default: return "ManropeExtraLight-Regular"
        }
    }

    /// Info.plist's UIAppFonts should have registered these at launch. This runs once anyway and
    /// registers by hand whatever is missing, so a face that ended up somewhere else in the bundle
    /// still arrives instead of quietly leaving the app in the system font.
    static func registerIfNeeded() {
        for face in FMXFont.faces where UIFont(name: face.name, size: 12) == nil {
            guard let url = Bundle.main.url(forResource: face.file, withExtension: "ttf")
                    ?? Bundle.main.url(forResource: face.file, withExtension: "ttf", subdirectory: "Fonts")
            else {
                debugLog("[FMXFont] \(face.file).ttf is not in the app at all")
                continue
            }

            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                debugLog("[FMXFont] registered \(face.name) by hand")
            } else {
                debugLog("[FMXFont] could not register \(face.file).ttf: \(String(describing: error?.takeRetainedValue()))")
            }
        }

        if UIFont(name: "ManropeExtraLight-Bold", size: 12) == nil {
            debugLog("[FMXFont] Manrope is not available; the screens will use the system font")
        }
    }
}
