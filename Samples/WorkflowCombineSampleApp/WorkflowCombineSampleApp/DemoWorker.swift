//
//  DemoWorker.swift
//  WorkflowCombineSampleApp
//
//  Created by Soo Rin Park on 10/28/21.
//

import Combine
import Workflow
import WorkflowCombine
import WorkflowUI

// MARK: Workers

extension DemoWorkflow {
    struct DemoWorker: WorkflowCombine.Worker {
        typealias Output = Action

        // This publisher publishes the current date on a timer that fires every second
        func run() -> AnyPublisher<Action, Never> {
            Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .map { Action(publishedDate: $0) }
                .eraseToAnyPublisher()
        }

        func isEquivalent(to otherWorker: DemoWorkflow.DemoWorker) -> Bool { true }
    }
}
