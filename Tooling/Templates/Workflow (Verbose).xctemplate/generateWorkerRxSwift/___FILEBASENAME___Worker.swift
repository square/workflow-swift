//  ___FILEHEADER___

import RxSwift
import Workflow
import WorkflowRxSwift
import WorkflowUI

// MARK: Workers

extension ___VARIABLE_productName___Workflow {
    struct ___VARIABLE_productName___Worker: Worker {
        enum Output {}

        func run() -> Observable<Output> {
            fatalError()
        }

        func isEquivalent(to otherWorker: ___VARIABLE_productName___Worker) -> Bool {
            return true
        }
    }
}
