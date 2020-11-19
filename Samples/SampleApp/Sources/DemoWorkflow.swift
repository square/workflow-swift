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

import ReactiveSwift
import Workflow
import WorkflowReactiveSwift
import WorkflowUI

// MARK: Input and Output

struct DemoWorkflow: Workflow {
    var name: String

    typealias Output = Never
}

// MARK: State and Initialization

extension DemoWorkflow {
    struct State {
        var signal: TimerSignal
        var colorState: ColorState
        var shouldLoad: Bool
        var subscriptionState: SubscriptionState

        enum ColorState {
            case red
            case green
            case blue
        }

        enum SubscriptionState {
            case not
            case subscribing
        }
    }

    enum LoadingState {
        case idle(String)
        case loading
    }

    func makeInitialState() -> DemoWorkflow.State {
        return State(
            signal: TimerSignal(),
            colorState: .red,
            shouldLoad: false,
            subscriptionState: .not
        )
    }
}

// MARK: Actions

extension DemoWorkflow {
    enum Action: WorkflowAction {
        typealias WorkflowType = DemoWorkflow

        case titleButtonTapped
        case subscribeTapped
        case refreshButtonTapped

        func apply(toState state: inout DemoWorkflow.State) -> DemoWorkflow.Output? {
            switch self {
            case .titleButtonTapped:
                switch state.colorState {
                case .red:
                    state.colorState = .green
                case .green:
                    state.colorState = .blue
                case .blue:
                    state.colorState = .red
                }

            case .subscribeTapped:
                switch state.subscriptionState {
                case .not:
                    state.subscriptionState = .subscribing
                case .subscribing:
                    state.subscriptionState = .not
                }

            case .refreshButtonTapped:
                state.shouldLoad = true
            }
            return nil
        }
    }
}

// MARK: Workers

struct RefreshWorker: Worker {
    enum Output {
        case success(String)
        case error(Error)
    }

    func run() -> SignalProducer<RefreshWorker.Output, Never> {
        return SignalProducer(value: .success("We did it!"))
            .delay(1.0, on: QueueScheduler.main)
    }

    func isEquivalent(to otherWorker: RefreshWorker) -> Bool {
        return true
    }
}

// MARK: Rendering

extension DemoWorkflow {
    typealias Rendering = DemoScreen

    func render(state: DemoWorkflow.State, context: RenderContext<DemoWorkflow>) -> Rendering {
        let color: UIColor
        switch state.colorState {
        case .red:
            color = .red
        case .green:
            color = .green
        case .blue:
            color = .blue
        }

        var title = "Hello, \(name)!"
        let refreshText: String
        let refreshEnabled: Bool

        if state.shouldLoad {
            let loadingState = RefreshWorker()
                .mapOutput { output -> LoadingState in
                    switch output {
                    case .success(let result):
                        return LoadingState.idle(result)
                    case .error(let error):
                        return LoadingState.idle(error.localizedDescription)
                    }
                }
                .renderLatestOutput(startingWith: .loading)
                .rendered(in: context)

            switch loadingState {
            case .idle(let refreshTitle):
                refreshText = refreshTitle
                refreshEnabled = true

                title = ReversingWorkflow(text: title)
                    .rendered(in: context)

            case .loading:
                refreshText = "Loading..."
                refreshEnabled = false
            }
        } else {
            refreshText = "Not Loaded"
            refreshEnabled = true
        }

        let subscribeTitle: String

        switch state.subscriptionState {
        case .not:
            subscribeTitle = "Subscribe"
        case .subscribing:
            // Subscribe to the timer signal, simulating the title being tapped.
            state.signal.signal
                .mapOutput { _ in Action.titleButtonTapped }
                .running(in: context, key: "timer")
            subscribeTitle = "Stop"
        }

        // Create a sink of our Action type so we can send actions back to the workflow.
        let sink = context.makeSink(of: Action.self)

        return DemoScreen(
            title: title,
            color: color,
            onTitleTap: {
                sink.send(.titleButtonTapped)
            },
            subscribeTitle: subscribeTitle,
            onSubscribeTapped: {
                sink.send(.subscribeTapped)
            },
            refreshText: refreshText,
            isRefreshEnabled: refreshEnabled,
            onRefreshTap: {
                sink.send(.refreshButtonTapped)
            }
        )
    }
}

class TimerSignal {
    let signal: Signal<Void, Never>
    let observer: Signal<Void, Never>.Observer
    let timer: Timer

    init() {
        let (signal, observer) = Signal<Void, Never>.pipe()

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak observer] _ in
            observer?.send(value: ())
        }

        self.signal = signal
        self.observer = observer
        self.timer = timer
    }
}
