#if canImport(UIKit)
import Combine
import ReactiveSwift
import WorkflowUI

extension WorkflowHostingController {
    public var output: Signal<Output, Never> {
        Signal.unserialized { observer, lifetime in
            let cancellable = outputPublisher.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        observer.sendCompleted()

                    case .failure(let error):
                        observer.send(error: error)
                    }
                },
                receiveValue: { value in
                    observer.send(value: value)
                }
            )
            lifetime.observeEnded {
                cancellable.cancel()
            }
        }
    }
}
#endif
