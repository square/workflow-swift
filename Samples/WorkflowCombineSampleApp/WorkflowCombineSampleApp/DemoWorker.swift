//
//  DemoWorker.swift
//  WorkflowCombineSampleApp
//
//  Created by Soo Rin Park on 10/28/21.
//

import Combine
import ReactiveSwift
import Workflow
import WorkflowCombine
import WorkflowReactiveSwift
import WorkflowUI

// MARK: Workers

extension DemoWorkflow {
    struct DemoWorker: WorkflowCombine.Worker {
        typealias Output = Action

        // This publisher publishes the current date on a timer that fires every second
        func run() -> AnyPublisher<DemoWorkflow.Action, Never> {
            Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .map { .init(publishedDate: $0) }
                .eraseToAnyPublisher()
        }

        func isEquivalent(to otherWorker: DemoWorkflow.DemoWorker) -> Bool { true }
    }
}

/// Identifcal implementation of the Combine Worker using the WorkflowReactiveSwift library instead.
/// To ensure that both implementations are correct, run the test suite with each implementation uncommented.
// extension DemoWorkflow {
//    struct DemoWorker: WorkflowReactiveSwift.Worker {
//        typealias Output = Action
//
//        func run() -> SignalProducer<DemoWorkflow.Action, Never> {
//            SignalProducer
//                .timer(interval: DispatchTimeInterval.seconds(1), on: QueueScheduler())
//                .map { .init(publishedDate: $0) }
//        }
//
//        func isEquivalent(to otherWorker: DemoWorkflow.DemoWorker) -> Bool { true }
//    }
// }
