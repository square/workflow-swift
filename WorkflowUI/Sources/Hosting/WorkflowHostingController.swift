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
import Workflow

/// Drives view controllers from a root Workflow.
public final class WorkflowHostingController<ScreenType, Output>: UIViewController where ScreenType: Screen {
    /// Emits output events from the bound workflow.
    public var output: Signal<Output, Never> {
        return workflowHost.output
    }

    private(set) var rootViewController: UIViewController

    private let workflowHost: WorkflowHost<AnyWorkflow<ScreenType, Output>>

    private let (lifetime, token) = Lifetime.make()

    public var rootViewEnvironment: ViewEnvironment {
        didSet {
            update(screen: workflowHost.rendering.value, environment: rootViewEnvironment)
        }
    }

    public init<W: AnyWorkflowConvertible>(
        workflow: W,
        rootViewEnvironment: ViewEnvironment = .empty,
        observers: [WorkflowObserver] = []
    ) where W.Rendering == ScreenType, W.Output == Output {
        self.workflowHost = WorkflowHost(
            workflow: workflow.asAnyWorkflow(),
            observers: observers
        )

        self.rootViewController = workflowHost
            .rendering
            .value
            .buildViewController(in: rootViewEnvironment)

        self.rootViewEnvironment = rootViewEnvironment

        super.init(nibName: nil, bundle: nil)

        addChild(rootViewController)
        rootViewController.didMove(toParent: self)

        workflowHost
            .rendering
            .signal
            .take(during: lifetime)
            .observeValues { [weak self] screen in
                guard let self = self else { return }

                self.update(screen: screen, environment: self.rootViewEnvironment)
            }
    }

    /// Updates the root Workflow in this container.
    public func update<W: AnyWorkflowConvertible>(workflow: W) where W.Rendering == ScreenType, W.Output == Output {
        workflowHost.update(workflow: workflow.asAnyWorkflow())
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func update(screen: ScreenType, environment: ViewEnvironment) {
        update(child: \.rootViewController, with: screen, in: environment)

        updatePreferredContentSizeIfNeeded()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        rootViewController.view.frame = view.bounds
        view.addSubview(rootViewController.view)

        updatePreferredContentSizeIfNeeded()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        rootViewController.view.frame = view.bounds
    }

    override public var childForStatusBarStyle: UIViewController? {
        return rootViewController
    }

    override public var childForStatusBarHidden: UIViewController? {
        return rootViewController
    }

    override public var childForHomeIndicatorAutoHidden: UIViewController? {
        return rootViewController
    }

    override public var childForScreenEdgesDeferringSystemGestures: UIViewController? {
        return rootViewController
    }

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return rootViewController.supportedInterfaceOrientations
    }

    override public var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return rootViewController.preferredStatusBarUpdateAnimation
    }

    override public var childViewControllerForPointerLock: UIViewController? {
        return rootViewController
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

#endif
