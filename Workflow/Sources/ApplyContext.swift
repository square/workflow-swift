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
/// that provides an integration point with the runtime that can be used to read property values
/// off of the current `Workflow` instance.
public struct ApplyContext<WorkflowType: Workflow> {
    private let wrappedContext: any ApplyContextType<WorkflowType>

    init<Impl: ApplyContextType>(_ context: Impl)
        where Impl.WorkflowType == WorkflowType
    {
        self.wrappedContext = context
    }

    public subscript<Value>(
        props keyPath: KeyPath<WorkflowType, Value>
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

// TODO: this is currently a class so that we can zero out the storage
// when it's invalidated. it'd be nice to instead make the `ApplyContext`
// type itself `~Escapable` since that's really the behavior that we want
// to enforce.

/// The `ApplyContext` used by the Workflow runtime when applying actions.
final class ConcreteApplyContext<WorkflowType: Workflow>: ApplyContextType {
    private(set) var storage: Storage<WorkflowType>?

    private var validatedStorage: Storage<WorkflowType> {
        guard let storage else {
            fatalError("Attempt to use an action application context for Workflow type '\(WorkflowType.self)' after it was invalidated.")
        }
        return storage
    }

    init(
        _ value: WorkflowType
    ) {
        self.storage = Storage(value)
    }

    init(storage: Storage<WorkflowType>) {
        self.storage = storage
    }

    public subscript<Value>(
        workflowValue keyPath: KeyPath<WorkflowType, Value>
    ) -> Value {
        validatedStorage.value[keyPath: keyPath]
    }

    // MARK: -

    func invalidate() {
        storage = nil
    }
}
