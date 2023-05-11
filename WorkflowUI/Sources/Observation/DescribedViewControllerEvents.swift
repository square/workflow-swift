
import ViewEnvironment

public protocol DescribedViewControllerEvent {
    var viewController: DescribedViewController { get }
}

public struct DescribedViewControllerWillLayoutSubviews: DescribedViewControllerEvent {
    public let viewController: DescribedViewController
}

public struct DescribedViewControllerDidLayoutSubviews: DescribedViewControllerEvent {
    public let viewController: DescribedViewController
}

public struct DescribedViewControllerWillAppear: DescribedViewControllerEvent {
    public let viewController: DescribedViewController
    public let animated: Bool
}

public struct DescribedViewControllerDidAppear: DescribedViewControllerEvent {
    public let viewController: DescribedViewController
    public let animated: Bool
}

public struct DescribedViewControllerDidUpdate: DescribedViewControllerEvent {
    public let viewController: DescribedViewController
    public let viewDescription: ViewControllerDescription
}
