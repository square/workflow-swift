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

import Workflow
import WorkflowUI

struct StockScreen: Screen {
    var stockValue: Double?

    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        return StockViewController.description(for: self, environment: environment)
    }
}

private final class StockViewController: ScreenViewController<StockScreen> {
    let stockValueLabel = UILabel(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()

        stockValueLabel.backgroundColor = .cyan

        stockValueLabel.textColor = .black
        stockValueLabel.textAlignment = .center
        view.addSubview(stockValueLabel)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        stockValueLabel.frame = view.bounds
    }

    override func screenDidChange(from previousScreen: StockScreen, previousEnvironment: ViewEnvironment) {
        super.screenDidChange(from: previousScreen, previousEnvironment: previousEnvironment)

        if let stockValue = screen.stockValue {
            stockValueLabel.text = "\(stockValue)"
        } else {
            stockValueLabel.text = "Loading..."
        }
    }
}
