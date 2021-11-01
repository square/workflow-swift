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
    struct DemoWorker: Worker {
        typealias Output = Action

        // This publisher publishes the current date on a timer that fires every second
        func run() -> AnyPublisher<DemoWorkflow.Action, Never> {
            Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .replaceError(with: Date())
                .map { .init(publishedDate: $0) }
                .eraseToAnyPublisher()
        }

        func isEquivalent(to otherWorker: DemoWorkflow.DemoWorker) -> Bool { true }
    }
}
