//  ___FILEHEADER___

import ReactiveSwift
import Workflow
import WorkflowReactiveSwift
import WorkflowUI

// MARK: Workers

extension ___VARIABLE_productName___Workflow {
    struct ___VARIABLE_productName___Worker: Worker {
        enum Output {}

        func run() -> SignalProducer<Output, Never> {
            fatalError()
        }

        func isEquivalent(to otherWorker: ___VARIABLE_productName___Worker) -> Bool {
            return true
        }
    }
}
