/*
 * Copyright 2020 Square Inc.
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

import ReactiveSwift
import UIKit
import ViewEnvironmentUI
import Workflow

public final class WorkflowHostingController<ScreenType, Output>: UIViewController where ScreenType: Screen {
    public typealias CustomizeEnvironment = (inout ViewEnvironment) -> Void

    /// Emits output events from the bound workflow.
    public var output: Signal<Output, Never> {
        workflowHost.output
    }

    private(set) var rootViewController: UIViewController

    private let workflowHost: WorkflowHost<AnyWorkflow<ScreenType, Output>>

    private let (lifetime, token) = Lifetime.make()

    public var customizeEnvironment: CustomizeEnvironment {
        didSet {
            setNeedsEnvironmentUpdate()
        }
    }

    public init<W: AnyWorkflowConvertible>(
        workflow: W,
        observers: [WorkflowObserver] = [],
        customizeEnvironment: @escaping CustomizeEnvironment = { _ in }
    ) where W.Rendering == ScreenType, W.Output == Output {
        self.workflowHost = WorkflowHost(
            workflow: workflow.asAnyWorkflow(),
            observers: observers
        )

        self.customizeEnvironment = customizeEnvironment

        // Customize the default environment for the first render so that we can perform updates and query view
        // controller containment methods before the view has been added to the hierarchy.
        var customizedEnvironment: ViewEnvironment = .empty
        customizeEnvironment(&customizedEnvironment)

        rootViewController = workflowHost
            .rendering
            .value
            .viewControllerDescription(environment: customizedEnvironment)
            .buildViewController()

        super.init(nibName: nil, bundle: nil)

        addChild(rootViewController)
        rootViewController.didMove(toParent: self)

        workflowHost
            .rendering
            .signal
            .take(during: lifetime)
            .observeValues { [weak self] screen in
                self?.update(screen: screen)
            }

        setNeedsEnvironmentUpdate()
    }

    /// Updates the root Workflow in this container.
    public func update<W: AnyWorkflowConvertible>(workflow: W) where W.Rendering == ScreenType, W.Output == Output {
        workflowHost.update(workflow: workflow.asAnyWorkflow())
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func update(screen: ScreenType) {
        update(screen: screen, environment: environment)
    }

    private func update(screen: ScreenType, environment: ViewEnvironment) {
        let previousRoot = rootViewController

        update(child: \.rootViewController, with: screen, in: environment)

        if previousRoot !== rootViewController {
            setNeedsEnvironmentUpdate()
        }

        updatePreferredContentSizeIfNeeded()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        let environment = self.environment

        // Update before loading the contained view controller's view so that the environment can fully propagate
        // before descendant views have loaded.
        // Many screens rely on `ViewEnvironment` validations in viewDidLoad which could be using the initial
        // `ViewEnvironment` without this explicit update.
        update(screen: workflowHost.rendering.value, environment: environment)

        view.backgroundColor = .white

        rootViewController.view.frame = view.bounds
        view.addSubview(rootViewController.view)

        updatePreferredContentSizeIfNeeded()
    }

    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        applyEnvironmentIfNeeded()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        rootViewController.view.frame = view.bounds
    }

    override public var childForStatusBarStyle: UIViewController? {
        rootViewController
    }

    override public var childForStatusBarHidden: UIViewController? {
        rootViewController
    }

    override public var childForHomeIndicatorAutoHidden: UIViewController? {
        rootViewController
    }

    override public var childForScreenEdgesDeferringSystemGestures: UIViewController? {
        rootViewController
    }

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        rootViewController.supportedInterfaceOrientations
    }

    override public var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        rootViewController.preferredStatusBarUpdateAnimation
    }

    override public var childViewControllerForPointerLock: UIViewController? {
        rootViewController
    }

    override public func preferredContentSizeDidChange(
        forChildContentContainer container: UIContentContainer
    ) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)

        guard container === rootViewController else { return }

        updatePreferredContentSizeIfNeeded()
    }

    private func updatePreferredContentSizeIfNeeded() {
        let newPreferredContentSize = rootViewController.preferredContentSize

        guard newPreferredContentSize != preferredContentSize else { return }

        preferredContentSize = newPreferredContentSize
    }
}

extension WorkflowHostingController: ViewEnvironmentObserving {
    public func customize(environment: inout ViewEnvironment) {
        customizeEnvironment(&environment)
    }

    public func environmentDidChange() {
        update(screen: workflowHost.rendering.value, environment: environment)
    }
}

#endif
