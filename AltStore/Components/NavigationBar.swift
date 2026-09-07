//
//  NavigationBar.swift
//  AltStore
//
//  Created by Riley Testut on 7/15/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit


class NavigationBarAppearance: UINavigationBarAppearance
{
    // We sometimes need to ignore user interaction so
    // we can tap items underneath the navigation bar.
    var ignoresUserInteraction: Bool = false
    
    override func copy(with zone: NSZone? = nil) -> Any
    {
        let copy = super.copy(with: zone) as! NavigationBarAppearance
        copy.ignoresUserInteraction = self.ignoresUserInteraction
        return copy
    }
}

class NavigationBar: UINavigationBar
{    
    @IBInspectable var automaticallyAdjustsItemPositions: Bool = true
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        #if !os(tvOS)
        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithDefaultBackground()
        standardAppearance.shadowColor = nil
        
        let edgeAppearance = UINavigationBarAppearance()
        edgeAppearance.configureWithOpaqueBackground()
        edgeAppearance.backgroundColor = self.barTintColor
        edgeAppearance.shadowColor = nil

        // focusmaxxing hub: the words go on whatever the bar's colour turns out to be. they used
        // to be set only when a bar had a tint of its own, and only one storyboard bar has one -
        // so the titles on Apps, My apps, Settings and the app detail were left in Apple's font
        // while the rest of the product is in Manrope. 28 for a large title, not the system's 34,
        // because the longest one here is "Focusmaxxing mobile" and a large title truncates rather
        // than shrinking; it is the same recipe as FMXTheme.style(navigationItem:).
        let textAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: FMXTheme.text,
                                                             .font: FMXFont.of(17, .bold)]
        let largeTextAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: FMXTheme.text,
                                                                  .font: FMXFont.of(28, .heavy)]

        standardAppearance.titleTextAttributes = textAttributes
        standardAppearance.largeTitleTextAttributes = largeTextAttributes
        edgeAppearance.titleTextAttributes = textAttributes
        edgeAppearance.largeTitleTextAttributes = largeTextAttributes

        if let tintColor = self.barTintColor
        {
            standardAppearance.backgroundColor = tintColor
        }
        else
        {
            standardAppearance.backgroundColor = nil
        }
        
        self.scrollEdgeAppearance = edgeAppearance
        self.standardAppearance = standardAppearance
        #else
        if let tintColor = self.barTintColor {
            self.barTintColor = tintColor
            self.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        }
        #endif
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        if self.automaticallyAdjustsItemPositions
        {
            // We can't easily shift just the back button up, so we shift the entire content view slightly.
            for contentView in self.subviews
            {
                guard NSStringFromClass(type(of: contentView)).contains("ContentView") else { continue }
                contentView.center.y -= 2
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView?
    {
        #if !os(tvOS)
        if let appearance = self.topItem?.standardAppearance as? NavigationBarAppearance, appearance.ignoresUserInteraction
        {
            // Ignore touches.
            return nil
        }
        #endif
        
        return super.hitTest(point, with: event)
    }
}
