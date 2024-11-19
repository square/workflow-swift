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

import BackStackContainer
import UIKit
import Workflow
import WorkflowUI

public final class TutorialHostingViewController: UIViewController {
    let containerViewController: UIViewController

    public init() {
        // Create a `WorkflowHostingController` with the `RootWorkflow` as the root workflow
        self.containerViewController = WorkflowHostingController(workflow: RootWorkflow())

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        addChild(containerViewController)
        view.addSubview(containerViewController.view)
        containerViewController.didMove(toParent: self)
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        containerViewController.view.frame = view.bounds
    }
}
