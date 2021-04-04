//
//  HookWorkflow.swift
//  Workflow
//
//  Created by Dhaval Shreyas on 10/26/20.
//

import Foundation

public struct HookWorkflow<Value>: Workflow {
    public typealias State = Value
    public typealias Rendering = (Value, (Value) -> Void)

    let defaultValue: Value
    public init(defaultValue: Value) {
        self.defaultValue = defaultValue
    }

    public func makeInitialState() -> Value {
        defaultValue
    }

    public func render(state: Value, context: RenderContext<HookWorkflow<Value>>) -> Rendering {
        let sink = context.makeSink(of: AnyWorkflowAction.self).contraMap { (val: Value) in
            .init { state in
                state = val
                return nil
            }
        }
        let updater: (Value) -> Void = { val in
            sink.send(val)
        }
        return (state, updater)
    }
}
