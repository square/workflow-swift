
#if canImport(UIKit)

import Foundation
import UIKit
import ViewEnvironment
import Workflow
@_spi(WorkflowGlobalObservation) import Workflow

public protocol WorkflowUIObserver {
    func observeScreenEvent<EventType: ScreenViewControllerEvent, ScreenType: Screen>(_ event: EventType) where EventType.ScreenType == ScreenType

    func observeDescribedViewControllerEvent<EventType: DescribedViewControllerEvent>(_ event: EventType)
}

public extension WorkflowUIObserver {
    func observeScreenEvent<EventType: ScreenViewControllerEvent, ScreenType: Screen>(_ event: EventType) where EventType.ScreenType == ScreenType {}

    func observeDescribedViewControllerEvent<EventType: DescribedViewControllerEvent>(_ event: EventType) {}
}

final class ChainedWorkflowUIObserver: WorkflowUIObserver {
    let observers: [WorkflowUIObserver]

    init(observers: [WorkflowUIObserver]) {
        self.observers = observers
    }

    func observeScreenEvent<EventType: ScreenViewControllerEvent, ScreenType: Screen>(_ event: EventType) where EventType.ScreenType == ScreenType {
        for observer in observers {
            observer.observeScreenEvent(event)
        }
    }

    func observeDescribedViewControllerEvent<EventType: DescribedViewControllerEvent>(_ event: EventType) {
        for observer in observers {
            observer.observeDescribedViewControllerEvent(event)
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
