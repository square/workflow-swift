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

import TutorialViews
import Workflow
import WorkflowUI

struct WelcomeScreen: Screen {
    /// The current name that has been entered.
    var name: String
    /// Callback when the name changes in the UI.
    var onNameChanged: (String) -> Void
    /// Callback when the login button is tapped.
    var onLoginTapped: () -> Void

    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        WelcomeViewController.description(for: self, environment: environment)
    }
}

final class WelcomeViewController: ScreenViewController<WelcomeScreen> {
    var welcomeView: WelcomeView

    required init(screen: WelcomeScreen, environment: ViewEnvironment) {
        self.welcomeView = WelcomeView(frame: .zero)
        super.init(screen: screen, environment: environment)
        update(with: screen)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(welcomeView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        welcomeView.frame = view.bounds.inset(by: view.safeAreaInsets)
    }

    override func screenDidChange(from previousScreen: WelcomeScreen, previousEnvironment: ViewEnvironment) {
        update(with: screen)
    }

    private func update(with screen: WelcomeScreen) {
        /// Update UI
        welcomeView.name = screen.name
        welcomeView.onNameChanged = screen.onNameChanged
        welcomeView.onLoginTapped = screen.onLoginTapped
    }
}
