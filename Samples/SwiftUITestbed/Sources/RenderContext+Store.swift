//
//  RenderContext+Store.swift
//  Development-SwiftUITestbed
//
//  Created by Andrew Watt on 3/11/24.
//

import Foundation
import Workflow

extension RenderContext {
    func makeStoreModel<Action: WorkflowAction>(
        state: WorkflowType.State
    ) -> StoreModel<WorkflowType.State, Action>
    where Action.WorkflowType == WorkflowType
    {
        StoreModel(
            state: state,
            sendAction: makeSink(of: Action.self).send,
            sendValue: makeStateMutationSink().send
        )
    }
}
