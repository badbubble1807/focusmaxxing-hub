//
//  SettingsHeaderFooterView.swift
//  AltStore
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit


final class SettingsHeaderFooterView: UITableViewHeaderFooterView
{
    @IBOutlet var primaryLabel: UILabel!
    @IBOutlet var secondaryLabel: UILabel!
    @IBOutlet var button: UIButton!
        
    @IBOutlet private var stackView: UIStackView!
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        
        self.contentView.layoutMargins = .zero
        self.contentView.preservesSuperviewLayoutMargins = true
        
        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.stackView)
        
        NSLayoutConstraint.activate([self.stackView.leadingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.leadingAnchor),
                                     self.stackView.trailingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.trailingAnchor),
                                     self.stackView.topAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.topAnchor),
                                     self.stackView.bottomAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.bottomAnchor)])

        // focusmaxxing hub: a heading over a group, set the way the desktop panel sets
        // COMMONLY BLOCKED - small, heavy, wide-tracked, muted. the words arrive already in
        // capitals from SettingsViewController.prepare(_:for:isHeader:), so only the spacing
        // between the letters has to be added, and it has to be added as an attribute because a
        // label has nowhere else to keep it.
        self.primaryLabel.font = FMXFont.of(11.5, .heavy)
        self.primaryLabel.textColor = FMXTheme.muted

        self.secondaryLabel.font = FMXFont.of(12.5, .regular)
        self.secondaryLabel.textColor = FMXTheme.faint

        self.button.titleLabel?.font = FMXFont.of(13, .bold)
        self.button.setTitleColor(FMXTheme.accentText, for: .normal)
    }

    /// the letter spacing the design system asks of a section title. it has to be reapplied every
    /// time the words change, so the view that sets the words calls this.
    func fmxApplyTracking()
    {
        guard let text = self.primaryLabel.text, !text.isEmpty else { return }
        self.primaryLabel.attributedText = NSAttributedString(string: text, attributes: [
            .font: FMXFont.of(11.5, .heavy),
            .foregroundColor: FMXTheme.muted,
            .kern: 1.0,
        ])
    }
}
