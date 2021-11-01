# WorkflowCombineSampleApp 

This sample project utilizes the WorkflowCombine library to demonstrate its usage in a `Workflow`. It is a simple app with a label that updates the current date & time every second.

# Usage

Thanks to the `AnyWorkflowConvertible` protocol, both the `WorkflowReactiveSwift` and `WorkflowCombine` Workers have identical api interface. To to migrate your `WorkflowReactiveSwift` `Worker`s to use the `WorkflowCombine`  `Worker`s, you will need to do the following:

1. Change `import` statements to use `WorkflowCombine` and `Combine`
2. Replace `SignalProducer` into `AnyPublisher` for the return type of `run`
3. Change the `run` implementation to the `Combine` equivalence. Most likely this will be the step that that requires the most attention, however if the tests were written for the `Workflow` it can be used to validate the new implementation without the need to change the tests.

Below is an example of a simple `Worker` in both `WorkflowReactiveSwift` and `WorkflowCombine` that emits a signal every second with the current date.

### `WorkflowReactiveSwift`

```swift
struct TimerWorker: Worker {
        typealias Output = Date
    
    func run() -> SignalProducer<Output, Never> {
        SignalProducer
            .timer(interval: DispatchTimeInterval.seconds(1), on: QueueScheduler.main)
    }
    
    func isEquivalent(to otherWorker: TimerWorker2) -> Bool { true }
}
```

### `WorkflowCombine`

```swift
struct TimerWorker: Worker {
    typealias Output = Date
    
    func run() -> AnyPublisher<Output, Never> {
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .eraseToAnyPublisher()
    }
    
    func isEquivalent(to otherWorker: Self) -> Bool { true }
}
```

### Notes

This library does **not** remove the usage of the `ReactiveSwift` library from the `Workflow` library. Currently the `Workflow` implementation is tightly coupled with `ReactiveSwift`, and this library is only limited to the `Worker`. Therefore, when utilizing both the existing `Workflow` and the new `Combine` backed `Worker` , you will need to utilize both the `ReactiveSwift` and `Combine` libraries.
