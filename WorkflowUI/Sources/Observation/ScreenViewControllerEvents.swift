
import ViewEnvironment

public protocol ScreenViewControllerEvent<ScreenType> {
    associatedtype ScreenType: Screen

    var viewController: ScreenViewController<ScreenType> { get }
}

public struct ScreenWillLayoutSubviews<ScreenType: Screen>: ScreenViewControllerEvent {
    public let viewController: ScreenViewController<ScreenType>
}

public struct ScreenDidLayoutSubviews<ScreenType: Screen>: ScreenViewControllerEvent {
    public let viewController: ScreenViewController<ScreenType>
}

public struct ScreenWillAppear<ScreenType: Screen>: ScreenViewControllerEvent {
    public let viewController: ScreenViewController<ScreenType>
    public let animated: Bool
}

public struct ScreenDidAppear<ScreenType: Screen>: ScreenViewControllerEvent {
    public let viewController: ScreenViewController<ScreenType>
    public let animated: Bool
}

public struct ScreenDidUpdate<ScreenType: Screen>: ScreenViewControllerEvent {
    public let viewController: ScreenViewController<ScreenType>
    public let previousScreen: ScreenType
    public let previousViewEnvironment: ViewEnvironment
}
