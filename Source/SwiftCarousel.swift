/*
 * Copyright (c) 2015 Droids on Roids LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit

public class SwiftCarousel: UIView {
    //MARK: - Properties
    var configuration: SwiftCarouselConfiguration!
    /// Current target with velocity left
    internal var currentVelocityX: CGFloat?
    /// Maximum velocity that swipe can reach.
    internal var maxVelocity: CGFloat = 100.0
    // Bool to know if item has been selected by Tapping
    private var itemSelectedByTap = false
    /// Main UIScrollView.
    private var scrollView = UIScrollView()
    /// Current selected index (between 0 and choices count).
    private var currentSelectedIndex: Int?
    /// Carousel delegate that handles events like didSelect.
    public weak var delegate: SwiftCarouselDelegate?
    /// Current selected index (calculated by searching through views),
    /// It returns index between 0 and originalChoicesNumber.
    public var selectedIndex: Int? {
        guard var index = viewIndexAtLocation(CGPoint(x: scrollView.contentOffset.x, y: CGRectGetMinY(scrollView.frame))) else {
            return nil
        }
        
        while index >= configuration.originalChoicesNumber {
            index -= configuration.originalChoicesNumber
        }
        
        return index
    }
    
    // MARK: - Inits
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    /**
     Initialize carousel with items & frame.
     
     - parameter frame:   Carousel frame.
     - parameter items: Items to put in carousel.
     
     Warning: original views in `items` are copied internally and are not guaranteed to be complete when the `didSelect` and `didDeselect` delegate methods are called. Use `itemsFactory` instead to avoid this limitation.
     
     */
    public init(frame: CGRect, configuration: SwiftCarouselConfiguration) {
        super.init(frame: frame)
        self.configuration = configuration
        setup()
    }
    
    deinit {
        scrollView.removeObserver(self, forKeyPath: "contentOffset")
    }
    
    // MARK: - Setups
    
    /**
     Main setup function. Here should be everything that needs to be done once.
     */
    private func setup() {
        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.scrollEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
        
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[scrollView]|",
            options: .AlignAllCenterX,
            metrics: nil,
            views: ["scrollView": scrollView])
        )
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[scrollView]|",
            options: .AlignAllCenterY,
            metrics: nil,
            views: ["scrollView": scrollView])
        )
        
        backgroundColor = .clearColor()
        scrollView.backgroundColor = .clearColor()
        
        if self.configuration.selectByTapEnabled {
            let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:)))
            gestureRecognizer.cancelsTouchesInView = false
            gestureRecognizer.delegate = self
            scrollView.addGestureRecognizer(gestureRecognizer)
        }
        
        switch self.configuration.scrollType {
        case .None:
            scrollView.scrollEnabled = false
        case .Max, .Freely, .Default:
            scrollView.scrollEnabled = true
        }
        
        setupViews(configuration.choices)
    }
    
    /**
     Setup views. Function that is fired up when setting the resizing type or items array.
     
     - parameter views: Current items to setup.
     */
    private func setupViews(views: ChoicesProxy) {
        var x: CGFloat = 0.0
        var scrollViewWidth: CGFloat = 0.0
        scrollView.frame = self.frame
        
        views.forEach { choice in
            var additionalSpacing: CGFloat = 0.0
            switch self.configuration.resizeType {
            case .WithoutResizing(let spacing):
                additionalSpacing = spacing
                choice.frame.size.width = CGRectGetWidth(self.frame)
                choice.frame.size.height = CGRectGetHeight(self.frame)
            case .FloatWithSpacing(let spacing):
                additionalSpacing = spacing
                choice.frame.size.width = CGRectGetWidth(self.frame)
                choice.frame.size.height = CGRectGetHeight(self.frame)
                choice.sizeToFit()
            case .VisibleItemsPerPage(let visibleItems):
                choice.frame.size.width = self.scrollView.frame.width / CGFloat(visibleItems)
                if (CGRectGetHeight(choice.frame) > 0.0) {
                    let aspectRatio: CGFloat = CGRectGetWidth(choice.frame)/CGRectGetHeight(choice.frame)
                    choice.frame.size.height = floor(CGRectGetWidth(choice.frame) * aspectRatio) > CGRectGetHeight(self.frame) ? CGRectGetHeight(self.frame) : floor(CGRectGetWidth(choice.frame) * aspectRatio)
                } else {
                    choice.frame.size.height = CGRectGetHeight(self.frame)
                }
            }
            choice.frame.origin.x = x
            x += CGRectGetWidth(choice.frame) + additionalSpacing
        }
        
        scrollView.subviews.forEach { $0.removeFromSuperview() }
        views.forEach { self.scrollView.addSubview($0) }
        layoutIfNeeded()
        
        guard (scrollView.frame.width > 0 && scrollView.frame.height > 0)  else { return }
        
        switch self.configuration.resizeType {
        case .FloatWithSpacing(_), .WithoutResizing(_):
            scrollViewWidth = configuration.choices.reduce(0.0) { $0 + CGRectGetWidth($1.frame) }
        case .VisibleItemsPerPage(let visibleItems):
            scrollViewWidth = configuration.choices.reduce(0.0) { $0 + CGRectGetWidth($1.frame)/CGFloat(visibleItems) }
        }
        
        scrollView.contentSize = CGSize(width: scrollViewWidth, height: CGRectGetHeight(frame))
        maxVelocity = scrollView.contentSize.width / 6.0
        selectItem(self.configuration.defaultSelectedIndex, animated: false)
    }
    
    // MARK: - Gestures
    public func viewTapped(gestureRecognizer: UIGestureRecognizer) {
        let touchPoint = gestureRecognizer.locationInView(scrollView)
        if let view = viewAtLocation(touchPoint), index = viewIndexAtLocation(touchPoint) {
            itemSelectedByTap = true
            selectItem(index, animated: true, force: true)
        }
    }
    
    // MARK: - Helpers
    
    /**
     Function that should be called when item was selected by Carousel.
     It will deselect all items that were selected before, and send
     notification to the delegate.
     */
    internal func didSelectItem() {
        guard let selectedIndex = selectedIndex else {
            return
        }
        
        didDeselectItem()
        delegate?.didSelectItem?(item: configuration.choices[selectedIndex]._view!, index: selectedIndex, tapped: itemSelectedByTap)
        itemSelectedByTap = false
        currentSelectedIndex = selectedIndex
        currentVelocityX = nil
        scrollView.scrollEnabled = true
    }
    
    /**
     Function that should be called when item was deselected by Carousel.
     It will also send notification to the delegate.
     */
    internal func didDeselectItem() {
        guard let currentSelectedIndex = self.currentSelectedIndex else {
            return
        }
        delegate?.didDeselectItem?(item: configuration.choices[currentSelectedIndex]._view!, index: currentSelectedIndex)
    }
    
    /**
     Detects if new point to scroll to will change the part (from the 3 parts used by Carousel).
     First and third parts are not shown to the end user, we are managing the scrolling between
     them behind the stage. The second part is the part user thinks it sees.
     
     - parameter point: Destination point.
     
     - returns: Bool that says if the part will change.
     */
    private func willChangePart(point: CGPoint) -> Bool {
        if (point.x >= scrollView.contentSize.width * 2.0 / 3.0 ||
            point.x <= scrollView.contentSize.width / 3.0) {
            return true
        }
        
        return false
    }
    
    /**
     Get view (from the items array) at location (if it exists).
     
     - parameter touchLocation: Location point.
     
     - returns: UIView that contains that point (if it exists).
     */
    private func viewAtLocation(touchLocation: CGPoint) -> UIView? {
        let index = viewIndexAtLocation(touchLocation)
        let view = self.loadItemView(index!)
        return view
    }
    
    private func viewIndexAtLocation(touchLocation: CGPoint) -> Int? {
        for subview in scrollView.subviews where CGRectContainsPoint(subview.frame, touchLocation) {
            return scrollView.subviews.indexOf(subview)
        }
        
        return self.configuration.defaultSelectedIndex
    }
    
    /**
     Get nearest view to the specified point location.
     
     - parameter touchLocation: Location point.
     
     - returns: UIView that is the nearest to that point (or contains that point).
     */
    internal func nearestViewAtLocation(touchLocation: CGPoint) -> UIView {
        var view: UIView!
        var index = viewIndexAtLocation(touchLocation)
        if let newView = viewAtLocation(touchLocation) {
            view = newView
        } else {
            // Now check left and right margins to nearest views
            var step: CGFloat = 1.0
            
            switch self.configuration.resizeType {
            case .FloatWithSpacing(let spacing):
                step = spacing
            case .WithoutResizing(let spacing):
                step = spacing
            default:
                break
            }
            
            var targetX = touchLocation.x
            
            // Left
            var leftView: UIView?
            
            repeat {
                targetX -= step
                leftView = viewAtLocation(CGPoint(x: targetX, y: touchLocation.y))
            } while (leftView == nil)
            
            let leftMargin = touchLocation.x - CGRectGetMaxX(leftView!.frame)
            
            // Right
            var rightView: UIView?
            
            repeat {
                targetX += step
                rightView = viewAtLocation(CGPoint(x: targetX, y: touchLocation.y))
            } while (rightView == nil)
            
            let rightMargin = CGRectGetMinX(rightView!.frame) - touchLocation.x
            
            if rightMargin < leftMargin {
                
                view = rightView!
            } else {
                view = leftView!
            }
        }
        
        // Check if the view is in bounds of scrolling type
        if case .Max(let maxItems) = self.configuration.scrollType,
            let currentSelectedIndex = currentSelectedIndex,
            var newIndex = index {
            
            if UInt(abs(newIndex - currentSelectedIndex)) > maxItems {
                if newIndex > currentSelectedIndex {
                    newIndex = currentSelectedIndex + Int(maxItems)
                } else {
                    newIndex = currentSelectedIndex - Int(maxItems)
                }
            }
            
            while newIndex < 0 {
                newIndex += configuration.originalChoicesNumber
            }
            
            while newIndex > configuration.choices.count {
                newIndex -= configuration.originalChoicesNumber
            }
            
            view = loadItemView(newIndex)
        }
        
        return view
    }
    
    private func loadItemView(index: Int) -> UIView {
        let indexList = getPreloadIndexList(index)
        for i in indexList {
            let viewToLoad = configuration.choices[i] as! SwiftCarouselItemView
            viewToLoad.loadItemView()
        }
        let view = configuration.choices[index]
        return view
    }
    
    private func getPreloadIndexList(index: Int) -> [Int] {
        var lowerBound = index - self.configuration.preloadItemViewCount
        var upperBound = index + self.configuration.preloadItemViewCount
        if (lowerBound < 0) {
            lowerBound = 0
        }
        if (upperBound >= self.configuration.originalChoicesNumber) {
            upperBound = self.configuration.originalChoicesNumber - 1
        }
        return (lowerBound...upperBound).map{$0}
    }
    
    /**
     Select item in the Carousel.
     
     - parameter choice:   Item index to select. If it contains number > than originalChoicesNumber,
     you need to set `force` flag to true.
     - parameter animated: If the method should try to animate the selection.
     - parameter force:    Force should be set to true if choice index is out of items bounds.
     */
    private func selectItem(choice: Int, animated: Bool, force: Bool) {
        let itemView = self.loadItemView(choice)
        let x = itemView.center.x - CGRectGetWidth(scrollView.frame) / 2.0
        
        let newPosition = CGPoint(x: x, y: scrollView.contentOffset.y)
        let animationIsNotNeeded = CGPointEqualToPoint(newPosition,scrollView.contentOffset)
        scrollView.setContentOffset(newPosition, animated: animated)
        
        if !animated || animationIsNotNeeded {
            didSelectItem()
        }
    }
    
    /**
     Select item in the Carousel.
     
     - parameter choice:   Item index to select.
     - parameter animated: Bool to tell if the selection should be animated.
     
     */
    public func selectItem(choice: Int, animated: Bool) {
        selectItem(choice, animated: animated, force: false)
    }
}