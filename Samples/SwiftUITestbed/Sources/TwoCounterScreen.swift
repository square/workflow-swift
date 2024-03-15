//
//  TwoCounterScreen.swift
//  Development-SwiftUITestbed
//
//  Created by Andrew Watt on 3/11/24.
//

import Foundation
import SwiftUI
import MarketUI
import MarketWorkflowUI
import ViewEnvironment
import Workflow
import Perception

struct TwoCounterScreen: SwiftUIScreen {

    let model: TwoCounterModel

    static func makeView(store: Store<TwoCounterModel>) -> some View {
        TwoCounterView(store: store)
    }
}

extension TwoCounterScreen: MarketBackStackContentScreen {
    var backStackIdentifier: AnyHashable? {
        "TwoCounterScreen"
    }

    func backStackItem(in environment: ViewEnvironment) -> MarketNavigationItem {
        MarketNavigationItem(title: .text("Two Counters"))
    }
}

struct TwoCounterView: View {
    @Perception.Bindable var store: Store<TwoCounterModel>

    var body: some View {
        WithPerceptionTracking {
            let _ = Self._printChanges()
            VStack {
//                Toggle(
//                    "Show Sum",
//                    isOn: $store.showSum.sending(sink: \.sumAction, action: \.showSum)
//                )
//                ToggleWrapper(isOn: $store.showSum.sending(sink: \.sumAction, action: \.showSum))
                ToggleWrapper(isOn: $store.showSum)

                Button("Add Counter") {
                    store.counterAction.send(.addCounter)
                }

                CounterView(store: store.counter1, index: 0)

                CounterView(store: store.counter2, index: 1)

                if store.showSum {
                    Text("Sum: \(store.counter1.count + store.counter2.count)")
                }
            }
            .padding()
        }
    }
}

struct ToggleWrapper: View {
    @Binding var isOn: Bool
    var body: some View {
//        WithPerceptionTracking {
            let _ = Self._printChanges()

            Toggle("Show Sum", isOn: $isOn)
//        }
    }
}

struct TwoCounterModel: ObservableModel {
    typealias State = TwoCounterWorkflow.State

    let accessor: StateAccessor<State>

    let counter1: CounterWorkflow.Model
    let counter2: CounterWorkflow.Model

//    let onShowSumToggle: (Bool) -> Void
    let sumAction: Sink<TwoCounterWorkflow.SumAction>
    let counterAction: Sink<TwoCounterWorkflow.CounterAction>
}

#if DEBUG

import SwiftUI

struct TwoCounterScreen_Preview: PreviewProvider {
    static var previews: some View {
        TwoCounterWorkflow()
            .mapRendering(TwoCounterScreen.init)
            .marketPreview { output in
            }
    }
}

#endif
