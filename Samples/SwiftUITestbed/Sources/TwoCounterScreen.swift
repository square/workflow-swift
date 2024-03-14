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
    let store: Store<TwoCounterModel>

    var body: some View {
        VStack {
            CounterView(store: store.counter1, index: 0)

            CounterView(store: store.counter2, index: 1)
        }
    }
}

struct TwoCounterModel: ObservableModel {
    typealias State = TwoCounterWorkflow.State

    let lens: StateLens<State>

    let counter1: CounterWorkflow.Model
    let counter2: CounterWorkflow.Model
}
