//
//  RatingControl.swift
//  MyPlaces
//
//  Created by Дарья Бирюкова on 07.09.2022.
//

import UIKit

@IBDesignable class RatingControl: UIStackView { //  IBDesign Позволяет отобразить контент в Interface Builder
    
    // MARK: - Properties
    
    var rating = 0 {
        didSet {
            updateButtonSelectionState()
        }
    }
    
    private var ratingButtons =  [UIButton]()
    
    @IBInspectable var starSize: CGSize = CGSize(width: 44.0, height: 44.0) {
        didSet {
            setUpButtons()
        }
    }
    @IBInspectable var starCount: Int = 5 {
        didSet {
            setUpButtons()
        }
    }

    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpButtons()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setUpButtons()
    }
    
    // MARK: - Button action
    
    @objc func ratingButtonTapped(button: UIButton) {
        guard let index = ratingButtons.firstIndex(of: button) else { return }
        
        // Calculate the rating of selected button
        let selectedRating = index + 1
        if selectedRating == rating { // Обнуление рейтинга если он равен текущему
            rating = 0
        } else {
            rating = selectedRating
        }
    }
    // MARK: - Private methods
    
    private func setUpButtons() {
        
        for button in ratingButtons {
            removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        
        ratingButtons.removeAll()
        
        // Load button image
        let bundle = Bundle(for: type(of: self))
        
        let filledStar = UIImage(named: "filledStar",
                                 in: bundle,
                                 compatibleWith: self.traitCollection)
        let emptyStar = UIImage(named: "emptyStar",
                                in: bundle,
                                compatibleWith: self.traitCollection)
        let highlightedStar = UIImage(named: "highlightedStar",
                                      in: bundle,
                                      compatibleWith: self.traitCollection)
        
        
        
        for _ in 0..<starCount {
            // Create the button
            let button = UIButton()
            
            // Set the button images
            button.setImage(emptyStar, for: .normal)
            button.setImage(filledStar, for: .selected)
            button.setImage(highlightedStar, for: .highlighted)
            button.setImage(highlightedStar, for: [.highlighted, .selected])
            
            // Add constraints
            button.translatesAutoresizingMaskIntoConstraints = false //отключает автоматически сгенерированные констрейнты, заменяем собственными:
            button.heightAnchor.constraint(equalToConstant: starSize.height).isActive = true
            button.widthAnchor.constraint(equalToConstant: starSize.width).isActive = true
            
            // Setup the button action
            button.addTarget(self, action: #selector(ratingButtonTapped(button:)), for: .touchUpInside)
            
            // Add button to the stack
            addArrangedSubview(button)
            
            // Add a new button to the rating button array
            ratingButtons.append(button)
        }
        updateButtonSelectionState()
    }
    
    private func updateButtonSelectionState() {
        for (index, button) in ratingButtons.enumerated() {
            button.isSelected = index < rating
        }
    }
}
