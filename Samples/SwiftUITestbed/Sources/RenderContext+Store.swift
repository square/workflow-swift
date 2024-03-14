//
//  RenderContext+Store.swift
//  Development-SwiftUITestbed
//
//  Created by Andrew Watt on 3/11/24.
//

import Foundation
import Workflow
import ComposableArchitecture

extension RenderContext where WorkflowType.State: ObservableState {

    func makeStateLens(
        state: WorkflowType.State
    ) -> StateLens<WorkflowType.State> {
        StateLens(state: state, sendValue: makeStateMutationSink().send)
    }

    func makeStoreModel<Action: WorkflowAction>(
        state: WorkflowType.State
    ) -> StoreModel<WorkflowType.State, Action>
    where Action.WorkflowType == WorkflowType
    {
        StoreModel(
            lens: makeStateLens(state: state),
            sendAction: makeSink(of: Action.self).send
        )
    }
}
