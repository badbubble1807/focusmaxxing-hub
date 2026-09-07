//
//  InsetGroupTableViewCell.swift
//  AltStore
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

extension InsetGroupTableViewCell
{
    @objc enum Style: Int
    {
        case single
        case top
        case middle
        case bottom
    }
}

final class InsetGroupTableViewCell: UITableViewCell
{
#if !TARGET_INTERFACE_BUILDER
    @IBInspectable var style: Style = .single {
        didSet {
            self.update()
        }
    }
#else
    @IBInspectable var style: Int = 0
#endif
    
    @IBInspectable var isSelectable: Bool = false
    
    private let separatorView = UIView()
    private let insetView = UIView()
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        
        self.selectionStyle = .none
        
        self.separatorView.translatesAutoresizingMaskIntoConstraints = false
        // focusmaxxing hub: the same card, hairline and radius as every other row in the product
        self.separatorView.backgroundColor = FMXTheme.hairline
        self.addSubview(self.separatorView)
        
        self.insetView.layer.masksToBounds = true
        self.insetView.layer.cornerRadius = FMXTheme.radiusSmall
        // card on ink is a two-shade difference, so a row on its own is given an edge. a row in
        // a group is not: the border would run along every join and double up with the
        // separator that is already there (update() decides, by style).
        self.insetView.layer.borderColor = FMXTheme.hairline.cgColor
        
        // Get the preferred background color from Interface Builder.
        self.insetView.backgroundColor = self.backgroundColor
        self.backgroundColor = nil
        
        self.addSubview(self.insetView, pinningEdgesWith: UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15))
        self.sendSubviewToBack(self.insetView)
        
        NSLayoutConstraint.activate([self.separatorView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 30),
                                     self.separatorView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -30),
                                     self.separatorView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                                     self.separatorView.heightAnchor.constraint(equalToConstant: 1)])
        
        self.update()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)
        
        if animated
        {
            UIView.animate(withDuration: 0.4) {
                self.update()
            }
        }
        else
        {
            self.update()
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool)
    {
        super.setHighlighted(highlighted, animated: animated)
        
        if animated
        {
            UIView.animate(withDuration: 0.4) {
                self.update()
            }
        }
        else
        {
            self.update()
        }
    }
}

private extension InsetGroupTableViewCell
{
    func update()
    {
        // focusmaxxing hub: only a row that is a card on its own gets an edge drawn round it. a
        // row in a group would draw that edge along the join with the row above and below, on top
        // of the separator that is already there.
        self.insetView.layer.borderWidth = (self.style == .single) ? 1 : 0

        switch self.style
        {
        case .single:
            self.insetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.separatorView.isHidden = true

        case .top:
            self.insetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.separatorView.isHidden = false
            
        case .middle:
            self.insetView.layer.maskedCorners = []
            self.separatorView.isHidden = false
            
        case .bottom:
            self.insetView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.separatorView.isHidden = true
        }
        
        if self.isSelectable && (self.isHighlighted || self.isSelected)
        {
            self.insetView.backgroundColor = FMXTheme.cardLifted
        }
        else
        {
            self.insetView.backgroundColor = FMXTheme.card
        }
    }
}
