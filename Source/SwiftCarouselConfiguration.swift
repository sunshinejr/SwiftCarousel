//
//  SwiftCarouselConfiguration.swift
//  Pods
//
//  Created by Cheng-chien Kuo on 6/19/16.
//
//

public class SwiftCarouselItemView: UIView {
    var index: Int!
    var factory: ((index: Int) -> UIView)?
    var _view: UIView?
    
    init(index: Int, factory: (index: Int) -> UIView) {
        self.index = index
        self.factory = factory
        super.init(frame: CGRectZero)
    }
    
    init(index: Int, item: UIView) {
        self.index = index
        self._view = item
        super.init(frame: CGRectZero)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func loadItemView() {
        if _view == nil {
            _view = self.factory!(index: index)
            self.addSubview(_view!)
            layoutIfNeeded()
        }
    }
}

class ChoicesProxy: CollectionType {
    typealias Index = Int
    
    private var factory: ((index: Int) -> UIView)?
    private var items: [UIView]!
    private var useFactory: Bool!
    private var itemCount: Int!
    private var _itemViews = [Int: SwiftCarouselItemView]()
    
    var startIndex: Int {
        return 0
    }
    
    var endIndex: Int {
        return count
    }
    
    var count: Int {
        return itemCount
    }
    
    init(count: Int, factory: (index: Int) -> UIView) {
        self.factory = factory
        self.useFactory = true
        self.itemCount = count
        self.items = []
    }
    
    init(items: [UIView]) {
        self.items = items
        self.useFactory = false
        self.itemCount = items.count
    }
    
    subscript(index: Int) -> SwiftCarouselItemView {
        get {
            if (self.useFactory != nil) && self.useFactory {
                if _itemViews[index] == nil {
                    _itemViews[index] = SwiftCarouselItemView(index: index, factory: factory!)
                }
                return _itemViews[index]!
            } else {
                if _itemViews[index] == nil {
                    _itemViews[index] = SwiftCarouselItemView(index: index, item: self.items[index])
                    _itemViews[index]?.loadItemView()
                }
                return _itemViews[index]!
            }
        }
    }
    
    func forEach(doThis: (element: SwiftCarouselItemView) -> Void) {
        for i in 0..<self.itemCount {
            doThis(element: self[i])
        }
    }
}

public class SwiftCarouselConfiguration {
    public var selectByTapEnabled = true
    public var preloadItemViewCount = 1
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
    public var defaultSelectedIndex: Int = 0 {
        didSet {
            if (defaultSelectedIndex < 0) {
                defaultSelectedIndex = 0
            }
            didSetDefaultIndex = true
        }
    }
    /// If there is defaultSelectedIndex and was selected, the variable is true.
    /// Otherwise it is not.
    internal var didSetDefaultIndex = false
    /// Carousel items. You can setup your carousel using this method (static items), or
    /// you can also see `itemsFactory`, which uses closure for the setup.
    /// Warning: original views are copied internally and are not guaranteed to be complete when the `didSelect` and `didDeselect` delegate methods are called. Use `itemsFactory` instead to avoid this limitation.
    public var items: [UIView] {
        get {
            return []
        }
        set {
            originalChoicesNumber = newValue.count
            self.choicesProxy = ChoicesProxy(items: newValue)
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
        self.choicesProxy = ChoicesProxy(count: count, factory: factory)
    }
    
    /// Number of items that were set at the start of init.
    var originalChoicesNumber = 0
    
    private var choicesProxy: ChoicesProxy!
    /// Items that carousel shows. It is 3x more items than originalChoicesNumber.
    var choices: ChoicesProxy {
        get {
            return choicesProxy
        }
    }
    
    public init() {}
}