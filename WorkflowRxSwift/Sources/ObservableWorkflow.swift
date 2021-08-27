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

import RxSwift
import Workflow
import class Workflow.Lifetime

extension Observable: AnyWorkflowConvertible {
    public func asAnyWorkflow() -> AnyWorkflow<Void, Element> {
        return ObservableWorkflow(observable: self).asAnyWorkflow()
    }
}

struct ObservableWorkflow<Value>: Workflow {
    public typealias Output = Value
    public typealias State = Void
    public typealias Rendering = Void

    var observable: Observable<Value>

    public init(observable: Observable<Value>) {
        self.observable = observable
    }

    public func render(state: State, context: RenderContext<Self>) -> Rendering {
        let sink = context.makeSink(of: AnyWorkflowAction.self)
        context.runSideEffect(key: "") { [observable] lifetime in
            let disposable = observable
                .map { AnyWorkflowAction(sendingOutput: $0) }
                .subscribe(on: MainScheduler.asyncInstance)
                .subscribe(onNext: { value in
                    sink.send(value)
                })

            lifetime.onEnded {
                disposable.dispose()
            }
        }
    }
}
