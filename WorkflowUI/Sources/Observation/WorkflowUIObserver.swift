/*
 * Copyright 2023 Square Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if canImport(UIKit)
import Foundation

public protocol WorkflowUIObserver {
    func observeEvent<E: WorkflowUIEvent>(_ event: E)
}

// MARK: - Global Observation (SPI)

@_spi(WorkflowUIGlobalObservation)
public protocol UIObserversInterceptor {
    func workflowUIObservers(for initialObserver: WorkflowUIObserver?) -> WorkflowUIObserver?
}

@_spi(WorkflowUIGlobalObservation)
public enum WorkflowUIObservation {
    private static var _sharedUIInterceptorStorage: UIObserversInterceptor = NoOpUIObserversInterceptor()

    public static var sharedObserversInterceptor: UIObserversInterceptor! {
        get { _sharedUIInterceptorStorage }
        set {
            guard newValue != nil else {
                _sharedUIInterceptorStorage = NoOpUIObserversInterceptor()
                return
            }

            _sharedUIInterceptorStorage = newValue
        }
    }

    private struct NoOpUIObserversInterceptor: UIObserversInterceptor {
        func workflowUIObservers(for initialObserver: WorkflowUIObserver?) -> WorkflowUIObserver? {
            initialObserver
        }
    }
}

#endif
