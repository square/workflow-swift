/*
 * Copyright Square Inc.
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

/// Internal utility protocol so that `WorkflowTesting` can provide an alternate implementation
protocol ApplyContextType<WorkflowType> {
    associatedtype WorkflowType: Workflow

    subscript<Value>(
        workflowValue keyPath: KeyPath<WorkflowType, Value>
    ) -> Value { get }
}

/// Runtime context passed as a parameter to `WorkflowAction`'s `apply()` method
/// that provides an integration point with the runtime that can be used to read values from
/// the current `Workflow` instance.
///
/// Read-only access to `Workflow` values is exposed via the `subscript[workflowValue:]` API,
/// which accepts a read-only `KeyPath` to a `Workflow`'s value.
///
/// Usage example:
///
/// ```swift
///     struct MyWorkflow: Workflow {
///         let shouldSuppressOutput: Bool
///
///         // ... implementation ...
///     }
///
///     enum MyAction: WorkflowAction {
///         typealias WorkflowType = MyWorkflow
///
///         case one
///         case two
///
///         func apply(toState state: inout WorkflowType.State, context: ApplyContext<WorkflowType>) -> WorkflowType.Output? {
///             // Make conditional choices based on the `Workflow`'s instance values
///             let shouldSuppressOutput = context[workflowValue: \.shouldSuppressOutput]
///             if shouldSuppressOutput { return nil }
///
///             // ... implementation ...
///         }
///     }
/// ```
///
/// > Warning: The instance of this type passed to the `apply()` method should not escape from that method.
/// Attempting to access the instance after the `apply()` method has returned is a client error and will crash.
public struct ApplyContext<WorkflowType: Workflow> {
    let wrappedContext: any ApplyContextType<WorkflowType>

    init<Impl: ApplyContextType>(_ context: Impl)
        where Impl.WorkflowType == WorkflowType
    {
        self.wrappedContext = context
    }

    public subscript<Value>(
        workflowValue keyPath: KeyPath<WorkflowType, Value>
    ) -> Value {
        wrappedContext[workflowValue: keyPath]
    }
}

extension ApplyContext {
    static func make<Wrapped: ApplyContextType>(
        implementation: Wrapped
    ) -> ApplyContext<Wrapped.WorkflowType>
        where Wrapped.WorkflowType == WorkflowType
    {
        ApplyContext(implementation)
    }
}

// FIXME: this is currently a class so that we can zero out the storage
// when it's invalidated. it'd be nice to eventually make the `ApplyContext`
// type itself `~Escapable` since that's really the behavior that we want
// to enforce.

/// The `ApplyContext` used by the Workflow runtime when applying actions.
final class ConcreteApplyContext<WorkflowType: Workflow>: ApplyContextType {
    private(set) var storage: WorkflowType?

    private var validatedStorage: WorkflowType {
        guard let storage else {
            fatalError("Attempt to use an ApplyContext for Workflow of type '\(WorkflowType.self)' after it was invalidated. The context is only valid during a call to an apply(...) method.")
        }

        return storage
    }

    init(storage: WorkflowType) {
        self.storage = storage
    }

    subscript<Value>(
        workflowValue keyPath: KeyPath<WorkflowType, Value>
    ) -> Value {
        validatedStorage[keyPath: keyPath]
    }

    // MARK: -

    func invalidate() {
        storage = nil
    }
}
