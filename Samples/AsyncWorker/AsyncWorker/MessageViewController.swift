//
//  MessageViewController.swift
//  AsyncWorker
//
//  Created by Mark Johnson on 6/21/22.
//

import UIKit
import Workflow
import WorkflowUI

struct MessageScreen: Screen {
    let model: Model

    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        MessageViewController.description(for: self, environment: environment)
    }
}

class MessageViewController: ScreenViewController<MessageScreen> {
    let label = UILabel()

    override func loadView() {
        label.text = screen.model.message
        view = label
    }

    override func screenDidChange(from previousScreen: MessageScreen, previousEnvironment: ViewEnvironment) {
        label.text = screen.model.message
    }
}
