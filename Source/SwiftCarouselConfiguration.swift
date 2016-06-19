//
//  SwiftCarouselConfiguration.swift
//  Pods
//
//  Created by Cheng-chien Kuo on 6/19/16.
//
//

public class SwiftCarouselConfiguration {
    public var selectByTapEnabled = true
    public var scrollType: SwiftCarouselScroll = .Default {
        didSet {
            if case .Max(let number) = scrollType where number <= 0 {
                scrollType = .None
            }
        }
    }
    /// Resize type of the carousel chosen from SwiftCarouselResizeType.
    public var resizeType: SwiftCarouselResizeType = .WithoutResizing(0.0)
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
    }
    
    /// Number of items that were set at the start of init.
    var originalChoicesNumber = 0
    
    /// Items that carousel shows. It is 3x more items than originalChoicesNumber.
    var choices: [UIView] = []
    
    public init() {}
}