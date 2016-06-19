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
    
    /// Current target with velocity left
    internal var currentVelocityX: CGFloat?
    /// Maximum velocity that swipe can reach.
    internal var maxVelocity: CGFloat = 100.0
    // Bool to know if item has been selected by Tapping
    private var itemSelectedByTap = false
    /// Number of items that were set at the start of init.
    private var originalChoicesNumber = 0
    /// Items that carousel shows. It is 3x more items than originalChoicesNumber.
    private var choices: [UIView] = []
    /// Main UIScrollView.
    private var scrollView = UIScrollView()
    /// Current selected index (between 0 and choices count).
    private var currentSelectedIndex: Int?
    /// Current selected index (between 0 and originalChoicesNumber).
    private var currentRealSelectedIndex: Int?
    /// Carousel delegate that handles events like didSelect.
    public weak var delegate: SwiftCarouselDelegate?
    /// Bool to set if by tap on item carousel should select it (scroll to it).
    public var selectByTapEnabled = true
    /// Scrolling type of carousel. You can constraint scrolling through items.
    public var scrollType: SwiftCarouselScroll = .Default {
        didSet {
            if case .Max(let number) = scrollType where number <= 0 {
                scrollType = .None
            }
            
            switch scrollType {
            case .None:
                scrollView.scrollEnabled = false
            case .Max, .Freely, .Default:
                scrollView.scrollEnabled = true
            }
        }
    }
    
    
    /// Resize type of the carousel chosen from SwiftCarouselResizeType.
    public var resizeType: SwiftCarouselResizeType = .WithoutResizing(0.0) {
        didSet {
            setupViews(choices)
        }
    }
    /// If selected index is < 0, set it as nil.
    /// We won't check with count number since it might be set before assigning items.
    public var defaultSelectedIndex: Int? {
        didSet {
            if (defaultSelectedIndex < 0) {
                defaultSelectedIndex = nil
            }
        }
    }
    /// If there is defaultSelectedIndex and was selected, the variable is true.
    /// Otherwise it is not.
    public var didSetDefaultIndex: Bool = false
    /// Current selected index (calculated by searching through views),
    /// It returns index between 0 and originalChoicesNumber.
    public var selectedIndex: Int? {
        let view = viewAtLocation(CGPoint(x: scrollView.contentOffset.x + CGRectGetWidth(scrollView.frame) / 2.0, y: CGRectGetMinY(scrollView.frame)))
        guard var index = choices.indexOf({ $0 == view }) else {
            return nil
        }
        
        while index >= originalChoicesNumber {
            index -= originalChoicesNumber
        }
        
        return index
    }
    /// Current selected index (calculated by searching through views),
    /// It returns index between 0 and choices count.
    private var realSelectedIndex: Int? {
        let view = viewAtLocation(CGPoint(x: scrollView.contentOffset.x + CGRectGetWidth(scrollView.frame) / 2.0, y: CGRectGetMinY(scrollView.frame)))
        guard let index = choices.indexOf({ $0 == view }) else {
            return nil
        }
        
        return index
    }
    /// Carousel items. You can setup your carousel using this method (static items), or
    /// you can also see `itemsFactory`, which uses closure for the setup.
    /// Warning: original views are copied internally and are not guaranteed to be complete when the `didSelect` and `didDeselect` delegate methods are called. Use `itemsFactory` instead to avoid this limitation.
    public var items: [UIView] {
        get {
            return [UIView](choices[choices.count / 3..<(choices.count / 3 + originalChoicesNumber)])
        }
        set {
            originalChoicesNumber = newValue.count
            (0..<3).forEach { counter in
                let newViews: [UIView] = newValue.map { choice in
                    // Return original view if middle section
                    if counter == 1 {
                        return choice
                    } else {
                        do {
                            return try choice.copyView()
                        } catch {
                            fatalError("There was a problem with copying view.")
                        }
                    }
                }
                self.choices.appendContentsOf(newViews)
            }
            setupViews(choices)
        }
    }
    
    /// Factory for carousel items. Here you specify how many items do you want in carousel
    /// and you need to specify closure that will create that view. Remember that it should
    /// always create new view, not give the same reference all the time.
    /// If the factory closure returns a reference to a view that has already been returned, a SwiftCarouselError.ViewAlreadyAdded error is thrown.
    /// You can always setup your carousel using `items` instead.
    public func itemsFactory(itemsCount count: Int, factory: (index: Int) -> UIView) throws {
        guard count > 0 else { return }
        
        originalChoicesNumber = count
        try (0..<3).forEach { counter in
            let newViews: [UIView] = try 0.stride(to: count, by: 1).map { i in
                let view = factory(index: i)
                guard !self.choices.contains(view) else {
                    throw SwiftCarouselError.ViewAlreadyAdded
                }
                return view
            }
            self.choices.appendContentsOf(newViews)
        }
        setupViews(choices)
    }
    
    // MARK: - Inits
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
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
    public convenience init(frame: CGRect, items: [UIView]) {
        self.init(frame: frame)
        setup()
        self.items = items
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
        scrollView.addObserver(self, forKeyPath: "contentOffset", options: [.New, .Old], context: nil)
        
        if selectByTapEnabled {
            let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:)))
            gestureRecognizer.cancelsTouchesInView = false
            gestureRecognizer.delegate = self
            scrollView.addGestureRecognizer(gestureRecognizer)
        }
    }
        
    /**
     Setup views. Function that is fired up when setting the resizing type or items array.
     
     - parameter views: Current items to setup.
     */
    private func setupViews(views: [UIView]) {
        var x: CGFloat = 0.0
        if case .FloatWithSpacing(_) = resizeType {
            views.forEach { $0.sizeToFit() }
        }
        
        views.forEach { choice in
            var additionalSpacing: CGFloat = 0.0
            switch resizeType {
            case .WithoutResizing(let spacing): additionalSpacing = spacing
            case .FloatWithSpacing(let spacing): additionalSpacing = spacing
            case .VisibleItemsPerPage(let visibleItems):
                choice.frame.size.width = scrollView.frame.width / CGFloat(visibleItems)
                if (CGRectGetHeight(choice.frame) > 0.0) {
                    let aspectRatio: CGFloat = CGRectGetWidth(choice.frame)/CGRectGetHeight(choice.frame)
                    choice.frame.size.height = floor(CGRectGetWidth(choice.frame) * aspectRatio) > CGRectGetHeight(frame) ? CGRectGetHeight(frame) : floor(CGRectGetWidth(choice.frame) * aspectRatio)
                } else {
                    choice.frame.size.height = CGRectGetHeight(frame)
                }
            }
            choice.frame.origin.x = x
            x += CGRectGetWidth(choice.frame) + additionalSpacing
        }
        
        scrollView.subviews.forEach { $0.removeFromSuperview() }
        views.forEach { scrollView.addSubview($0) }
        layoutIfNeeded()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        guard (scrollView.frame.width > 0 && scrollView.frame.height > 0)  else { return }
        
        var width: CGFloat = 0.0
        switch resizeType {
        case .FloatWithSpacing(_), .WithoutResizing(_):
            width = CGRectGetMaxX(choices.last!.frame)
        case .VisibleItemsPerPage(_):
            width = choices.reduce(0.0) { $0 + CGRectGetWidth($1.frame) }
        }
        
        scrollView.contentSize = CGSize(width: width, height: CGRectGetHeight(frame))
        maxVelocity = scrollView.contentSize.width / 6.0
        
        // We do not want to change the selected index in case of hiding and
        // showing view, which also triggers layout.
        // On the other hand this method can be triggered when the defaultSelectedIndex
        // was set after the carousel init, so we check if the default index is != nil
        // and that it wasn't set before.
        guard currentSelectedIndex == nil ||
            (didSetDefaultIndex == false && defaultSelectedIndex != nil) else { return }
        
        // Center the view
        if defaultSelectedIndex != nil {
            selectItem(defaultSelectedIndex!, animated: false)
            didSetDefaultIndex = true
        } else {
            selectItem(0, animated: false)
        }
    }
    
    override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if let _ = change?[NSKeyValueChangeNewKey] where keyPath == "contentOffset" {
            // with autolayout this seems to be quite usual, we want to wait
            // until we have some size we can actualy work with
            guard (scrollView.frame.width > 0 &&
                scrollView.frame.height > 0)  else { return }
            
            let newOffset = scrollView.contentOffset
            let segmentWidth = scrollView.contentSize.width / 3
            var newOffsetX: CGFloat!
            if (newOffset.x >= segmentWidth * 2.0) { // in the 3rd part
                newOffsetX = newOffset.x - segmentWidth // move back one segment
            } else if (newOffset.x + scrollView.bounds.width) <= segmentWidth { // First part
                newOffsetX = newOffset.x + segmentWidth // move forward one segment
            }
            // We are in middle segment still so no need to scroll elsewhere
            guard newOffsetX != nil && newOffsetX > 0 else {
                return
            }
            
            self.scrollView.contentOffset.x = newOffsetX
            
            self.delegate?.didScroll?(toOffset: self.scrollView.contentOffset)
        }
    }
    
    // MARK: - Gestures
    public func viewTapped(gestureRecognizer: UIGestureRecognizer) {
        let touchPoint = gestureRecognizer.locationInView(scrollView)
        if let view = viewAtLocation(touchPoint), index = choices.indexOf(view) {
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
        guard let selectedIndex = self.selectedIndex, realSelectedIndex = self.realSelectedIndex else {
            return
        }
        
        didDeselectItem()
        delegate?.didSelectItem?(item: choices[realSelectedIndex], index: selectedIndex, tapped: itemSelectedByTap)
        itemSelectedByTap = false
        currentSelectedIndex = selectedIndex
        currentRealSelectedIndex = realSelectedIndex
        currentVelocityX = nil
        scrollView.scrollEnabled = true
    }
    
    /**
     Function that should be called when item was deselected by Carousel.
     It will also send notification to the delegate.
     */
    internal func didDeselectItem() {
        guard let currentRealSelectedIndex = self.currentRealSelectedIndex, currentSelectedIndex = self.currentSelectedIndex else {
            return
        }
        
        delegate?.didDeselectItem?(item: choices[currentRealSelectedIndex], index: currentSelectedIndex)
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
        for subview in scrollView.subviews where CGRectContainsPoint(subview.frame, touchLocation) {
            return subview
        }
        
        return nil
    }
    
    /**
     Get nearest view to the specified point location.
     
     - parameter touchLocation: Location point.
     
     - returns: UIView that is the nearest to that point (or contains that point).
     */
    internal func nearestViewAtLocation(touchLocation: CGPoint) -> UIView {
        var view: UIView!
        if let newView = viewAtLocation(touchLocation) {
            view = newView
        } else {
            // Now check left and right margins to nearest views
            var step: CGFloat = 1.0
            
            switch resizeType {
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
        if case .Max(let maxItems) = scrollType,
            let currentRealSelectedIndex = currentRealSelectedIndex,
            var newIndex = choices.indexOf ({ $0 == view }) {
            
            if UInt(abs(newIndex - currentRealSelectedIndex)) > maxItems {
                if newIndex > currentRealSelectedIndex {
                    newIndex = currentRealSelectedIndex + Int(maxItems)
                } else {
                    newIndex = currentRealSelectedIndex - Int(maxItems)
                }
            }
            
            while newIndex < 0 {
                newIndex += originalChoicesNumber
            }
            
            while newIndex > choices.count {
                newIndex -= originalChoicesNumber
            }
            
            view = choices[newIndex]
        }
        
        return view
    }
    
    /**
     Select item in the Carousel.
     
     - parameter choice:   Item index to select. If it contains number > than originalChoicesNumber,
     you need to set `force` flag to true.
     - parameter animated: If the method should try to animate the selection.
     - parameter force:    Force should be set to true if choice index is out of items bounds.
     */
    private func selectItem(choice: Int, animated: Bool, force: Bool) {
        var index = choice
        if !force {
            // allow scroll only in the range of original items
            guard choice < choices.count / 3 else {
                return
            }
            // move to same item in middle segment
            index = index + originalChoicesNumber
        }
        
        let choiceView = choices[index]
        let x = choiceView.center.x - CGRectGetWidth(scrollView.frame) / 2.0
        
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