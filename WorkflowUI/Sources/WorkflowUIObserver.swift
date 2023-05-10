
#if canImport(UIKit)

import Foundation
import UIKit
import ViewEnvironment
import Workflow
@_spi(WorkflowGlobalObservation) import Workflow

public protocol WorkflowUIObserver {
    // MARK: ScreenViewController

    func screenDidUpdate<ScreenType: Screen>(
        _ viewController: ScreenViewController<ScreenType>,
        previousScreen: ScreenType,
        previousEnvironment: ViewEnvironment
    )

    func screenWillAppear<ScreenType: Screen>(
        _ viewController: ScreenViewController<ScreenType>,
        animated: Bool
    )

    func screenDidAppear<ScreenType: Screen>(
        _ viewController: ScreenViewController<ScreenType>,
        animated: Bool
    )

    func screenWillLayoutSubviews<ScreenType: Screen>(
        viewController: ScreenViewController<ScreenType>
    )

    func screenDidLayoutSubviews<ScreenType: Screen>(
        viewController: ScreenViewController<ScreenType>
    )

    // MARK: DescribedViewController

    func describedViewControllerWillAppear(
        _ viewController: DescribedViewController,
        animated: Bool
    )

    func describedViewControllerDidAppear(
        _ viewController: DescribedViewController,
        animated: Bool
    )

    func describedViewControllerDidUpdate(
        _ viewController: DescribedViewController,
        description: ViewControllerDescription
    )

    func describedViewControllerWillLayoutSubviews(
        _ viewController: DescribedViewController
    )

    func describedViewControllerDidLayoutSubviews(
        _ viewController: DescribedViewController
    )
}

public extension WorkflowUIObserver {
    func screenDidUpdate<ScreenType: Screen>(
        _ viewController: ScreenViewController<ScreenType>,
        previousScreen: ScreenType,
        previousEnvironment: ViewEnvironment
    ) {}

    func screenWillAppear<ScreenType: Screen>(
        _ viewController: ScreenViewController<ScreenType>,
        animated: Bool
    ) {}

    func screenDidAppear<ScreenType: Screen>(
        _ viewController: ScreenViewController<ScreenType>,
        animated: Bool
    ) {}

    func screenWillLayoutSubviews<ScreenType: Screen>(
        viewController: ScreenViewController<ScreenType>
    ) {}

    func screenDidLayoutSubviews<ScreenType: Screen>(
        viewController: ScreenViewController<ScreenType>
    ) {}

    func describedViewControllerWillAppear(
        _ viewController: DescribedViewController,
        animated: Bool
    ) {}

    func describedViewControllerDidAppear(
        _ viewController: DescribedViewController,
        animated: Bool
    ) {}

    func describedViewControllerDidUpdate(
        _ viewController: DescribedViewController,
        description: ViewControllerDescription
    ) {}

    func describedViewControllerWillLayoutSubviews(
        _ viewController: DescribedViewController
    ) {}

    func describedViewControllerDidLayoutSubviews(
        _ viewController: DescribedViewController
    ) {}
}

final class ChainedWorkflowUIObserver: WorkflowUIObserver {
    let observers: [WorkflowUIObserver]

    init(observers: [WorkflowUIObserver]) {
        self.observers = observers
    }

    func screenDidUpdate<ScreenType: Screen>(
        _ viewController: ScreenViewController<ScreenType>,
        previousScreen: ScreenType,
        previousEnvironment: ViewEnvironment
    ) {
        for observer in observers {
            observer.screenDidUpdate(viewController, previousScreen: previousScreen, previousEnvironment: previousEnvironment)
        }
    }

    func screenWillAppear<ScreenType: Screen>(
        _ viewController: ScreenViewController<ScreenType>,
        animated: Bool
    ) {
        for observer in observers {
            observer.screenWillAppear(viewController, animated: animated)
        }
    }

    func screenDidAppear<ScreenType: Screen>(
        _ viewController: ScreenViewController<ScreenType>,
        animated: Bool
    ) {
        for observer in observers {
            observer.screenDidAppear(viewController, animated: animated)
        }
    }

    func screenWillLayoutSubviews<ScreenType: Screen>(
        viewController: ScreenViewController<ScreenType>
    ) {
        for observer in observers {
            observer.screenWillLayoutSubviews(viewController: viewController)
        }
    }

    func screenDidLayoutSubviews<ScreenType: Screen>(
        viewController: ScreenViewController<ScreenType>
    ) {
        for observer in observers {
            observer.screenDidLayoutSubviews(viewController: viewController)
        }
    }

    func describedViewControllerWillAppear(
        _ viewController: DescribedViewController,
        animated: Bool
    ) {
        for observer in observers {
            observer.describedViewControllerWillAppear(viewController, animated: animated)
        }
    }

    func describedViewControllerDidAppear(
        _ viewController: DescribedViewController,
        animated: Bool
    ) {
        for observer in observers {
            observer.describedViewControllerDidAppear(viewController, animated: animated)
        }
    }

    func describedViewControllerDidUpdate(
        _ viewController: DescribedViewController,
        description: ViewControllerDescription
    ) {
        for observer in observers {
            observer.describedViewControllerDidUpdate(viewController, description: description)
        }
    }

    func describedViewControllerWillLayoutSubviews(
        _ viewController: DescribedViewController
    ) {
        for observer in observers {
            observer.describedViewControllerWillLayoutSubviews(viewController)
        }
    }

    func describedViewControllerDidLayoutSubviews(
        _ viewController: DescribedViewController
    ) {
        for observer in observers {
            observer.describedViewControllerDidLayoutSubviews(viewController)
        }
    }
}

extension Array where Element == WorkflowUIObserver {
    func chained() -> WorkflowUIObserver {
        if count == 1 {
            // no wrapping needed if a single element
            return self[0]
        } else {
            return ChainedWorkflowUIObserver(observers: self)
        }
    }
}

// MARK: - Global Observation (SPI)

@_spi(WorkflowGlobalObservation)
public protocol UIObserversInterceptor {
    /// Provides a single access point to provide the final list of `WorkflowObserver` used by the runtime.
    /// This may be used to ensure a known set of observers is used in a particular order for all
    /// `WorkflowHost`s created over the life of a program.
    /// - Parameter initialObservers: Array of observers passed to a `WorkflowHost` constructor
    /// - Returns: The array of `WorkflowObserver`s to be used by the `WorkflowHost`
    func workflowObservers(for initialObservers: [WorkflowUIObserver]) -> [WorkflowUIObserver]
}

@_spi(WorkflowGlobalObservation)
extension UIObserversInterceptor {
    public func chainedObservers(for initialObservers: [WorkflowUIObserver]) -> WorkflowUIObserver {
        return workflowObservers(for: initialObservers).chained()
    }
}

@_spi(WorkflowGlobalObservation)
extension WorkflowObservation {
    private static var _sharedUIInterceptorStorage: UIObserversInterceptor = NoOpUIObserversInterceptor()

    /// The `DefaultObserversProvider` used by all runtimes.
    public static var sharedUIObserversInterceptor: UIObserversInterceptor! {
        get {
            _sharedUIInterceptorStorage
        }
        set {
            guard newValue != nil else {
                _sharedUIInterceptorStorage = NoOpUIObserversInterceptor()
                return
            }

            _sharedUIInterceptorStorage = newValue
        }
    }

    private struct NoOpUIObserversInterceptor: UIObserversInterceptor {
        func workflowObservers(for initialObservers: [WorkflowUIObserver]) -> [WorkflowUIObserver] {
            initialObservers
        }
    }
}

#endif
