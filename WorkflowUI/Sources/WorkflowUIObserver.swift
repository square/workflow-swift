
import Foundation
import ViewEnvironment
import Workflow
@_spi(WorkflowGlobalObservation) import Workflow

public protocol WorkflowUIObserver {
    // TODO:
    ///     * This is only used by ScreenViewController currently
    ///     * DescribedViewController has `update(description:)` which is `public` and doesn't accept a screen
    func viewControllerDidUpdateScreen<ScreenType: Screen>(
        _ viewController: UIViewController,
        screen: ScreenType,
        viewEnvironment: ViewEnvironment,
        rootWorkflow: Any
    )

    func screenDidAppear<ScreenType: Screen>(
        _ screen: ScreenType,
        viewController: UIViewController,
        animated: Bool,
        rootWorkflow: Any
    )
}

extension WorkflowUIObserver {
    func viewControllerDidUpdateScreen<ScreenType: Screen>(
        _ viewController: UIViewController,
        screen: ScreenType,
        viewEnvironment: ViewEnvironment,
        rootWorkflow: Any
    ) {}

    func screenDidAppear<ScreenType: Screen>(
        _ screen: ScreenType,
        viewController: UIViewController,
        animated: Bool,
        rootWorkflow: Any
    ) {}
}

// extension ChainedWorkflowObserver: WorkflowUIObserver {
//    public func viewControllerDidUpdateScreen<ScreenType: Screen>(
//        _ viewController: UIViewController,
//        screen: ScreenType,
//        viewEnvironment: ViewEnvironment
//    ) {
//        for case let observer as WorkflowUIObserver in observers {
//            observer.viewControllerDidUpdateScreen(viewController, screen: screen, viewEnvironment: viewEnvironment)
//        }
//    }
//
//    public func screenDidAppear<ScreenType: Screen>(
//        _ screen: ScreenType,
//        viewController: UIViewController,
//        animated: Bool
//    ) {
//        for case let observer as WorkflowUIObserver in observers {
//            observer.screenDidAppear(screen, viewController: viewController, animated: animated)
//        }
//    }
// }

final class ChainedWorkflowUIObserver: WorkflowUIObserver {
    let observers: [WorkflowUIObserver]

    init(observers: [WorkflowUIObserver]) {
        self.observers = observers
    }

    func viewControllerDidUpdateScreen<ScreenType: Screen>(
        _ viewController: UIViewController,
        screen: ScreenType,
        viewEnvironment: ViewEnvironment,
        rootWorkflow: Any
    ) {
        for observer in observers {
            observer.viewControllerDidUpdateScreen(viewController, screen: screen, viewEnvironment: viewEnvironment, rootWorkflow: rootWorkflow)
        }
    }

    func screenDidAppear<ScreenType: Screen>(
        _ screen: ScreenType,
        viewController: UIViewController,
        animated: Bool,
        rootWorkflow: Any
    ) {
        for observer in observers {
            observer.screenDidAppear(screen, viewController: viewController, animated: animated, rootWorkflow: rootWorkflow)
        }
    }
}

extension Array where Element == WorkflowUIObserver {
    func chained() -> WorkflowUIObserver? {
        if count <= 1 {
            // no wrapping needed if empty or a single element
            return first
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
    public func chainedObservers(for initialObservers: [WorkflowUIObserver]) -> WorkflowUIObserver? {
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
