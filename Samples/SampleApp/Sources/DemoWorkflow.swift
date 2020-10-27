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
    typealias State = Void
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

enum LoadingState {
    case idle(title: String)
    case loading
}

enum ColorState {
    case red, green, blue

    var next: ColorState {
        switch self {
        case .red:
            return .green
        case .green:
            return .blue
        case .blue:
            return .red
        }
    }

    var color: UIColor {
        switch self {
        case .green:
            return UIColor.green
        case .blue:
            return UIColor.blue
        case .red:
            return UIColor.red
        }
    }
}

enum SubscriptionState {
    case not
    case subscribing

    var toggled: Self {
        switch self {
        case .not:
            return .subscribing
        case .subscribing:
            return .not
        }
    }
}

extension DemoWorkflow {
    typealias Rendering = DemoScreen

    func render(state: DemoWorkflow.State, context: RenderContext<DemoWorkflow>) -> Rendering {
        let (color, colorUpdater) = HookWorkflow(defaultValue: ColorState.red)
            .rendered(in: context)

        let (loadingState, loadingStateUpdater) = HookWorkflow(defaultValue: LoadingState.idle(title: "Not Loaded"))
            .rendered(in: context)

        var title = "Hello, \(name)!"
        let refreshText: String
        let refreshEnabled: Bool

        switch loadingState {
        case .idle(title: let refreshTitle):
            refreshText = refreshTitle
            refreshEnabled = true

            title = ReversingWorkflow(text: title)
                .rendered(in: context)

        case .loading:
            refreshText = "Loading..."
            refreshEnabled = false

            RefreshWorker()
                .onOutput { _, output in
                    DispatchQueue.main.async {
                        switch output {
                        case .success(let result):
                            loadingStateUpdater(.idle(title: result))
                        case .error(let error):
                            loadingStateUpdater(.idle(title: error.localizedDescription))
                        }
                    }
                    return nil
                }
                .running(in: context)
        }

        let subscribeTitle: String

        let (subscriptionState, subscriptionStateUpdater) = HookWorkflow(defaultValue: SubscriptionState.not)
            .rendered(in: context)

        switch subscriptionState {
        case .not:
            subscribeTitle = "Subscribe"
        case .subscribing:
            let (signal, _) = HookWorkflow(defaultValue: TimerSignal()).rendered(in: context)
            // Subscribe to the timer signal, simulating the title being tapped.
            signal.signal
                .onOutput { _, _ in
                    DispatchQueue.main.async {
                        colorUpdater(color.next)
                    }
                    return nil
                }
                .running(in: context, key: "timer")
            subscribeTitle = "Stop"
        }

        return DemoScreen(
            title: title,
            color: color.color,
            onTitleTap: {
                colorUpdater(color.next)
            },
            subscribeTitle: subscribeTitle,
            onSubscribeTapped: {
                subscriptionStateUpdater(subscriptionState.toggled)
            },
            refreshText: refreshText,
            isRefreshEnabled: refreshEnabled,
            onRefreshTap: {
                loadingStateUpdater(.loading)
            }
        )
    }
}

private class TimerSignal {
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
