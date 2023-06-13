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

import ViewEnvironment

/// A `ViewEnvironment` propagation mode that can be inserted into the propagation hierarchy.
///
/// This node can be useful when you want to re-route the propagation path and/or provide customizations to the
/// environment as it flows between two nodes.
///
@_spi(ViewEnvironmentWiring)
public class ViewEnvironmentPropagationNode: ViewEnvironmentPropagating, ViewEnvironmentObserving {
    public typealias EnvironmentAncestorProvider = () -> ViewEnvironmentPropagating?

    public typealias EnvironmentDescendantsProvider = () -> [ViewEnvironmentPropagating]

    public var environmentAncestorProvider: EnvironmentAncestorProvider {
        didSet { setNeedsEnvironmentUpdate() }
    }

    public var environmentDescendantsProvider: EnvironmentDescendantsProvider {
        didSet { setNeedsEnvironmentUpdate() }
    }

    public var customizeEnvironment: (inout ViewEnvironment) -> Void {
        didSet { setNeedsEnvironmentUpdate() }
    }

    public var environmentDidChangeObserver: ((ViewEnvironment) -> Void)? {
        didSet { setNeedsEnvironmentUpdate() }
    }

    public var applyEnvironment: (ViewEnvironment) -> Void {
        didSet { setNeedsEnvironmentUpdate() }
    }

    public init(
        environmentAncestor: @escaping EnvironmentAncestorProvider = { nil },
        environmentDescendants: @escaping EnvironmentDescendantsProvider = { [] },
        customizeEnvironment: @escaping (inout ViewEnvironment) -> Void = { _ in },
        environmentDidChange: ((ViewEnvironment) -> Void)? = nil,
        applyEnvironment: @escaping (ViewEnvironment) -> Void = { _ in }
    ) {
        self.environmentAncestorProvider = environmentAncestor
        self.environmentDescendantsProvider = environmentDescendants
        self.customizeEnvironment = customizeEnvironment
        self.environmentDidChangeObserver = environmentDidChange
        self.applyEnvironment = applyEnvironment
    }

    public var defaultEnvironmentAncestor: ViewEnvironmentPropagating? {
        environmentAncestorProvider()
    }

    public var defaultEnvironmentDescendants: [ViewEnvironmentPropagating] {
        environmentDescendantsProvider()
    }

    public func setNeedsApplyEnvironment() {
        applyEnvironmentIfNeeded()
    }

    public func customize(environment: inout ViewEnvironment) {
        customizeEnvironment(&environment)
    }

    public func environmentDidChange() {
        guard let didChange = environmentDidChangeObserver else { return }

        didChange(environment)
    }

    public func apply(environment: ViewEnvironment) {
        applyEnvironment(environment)
    }
}
