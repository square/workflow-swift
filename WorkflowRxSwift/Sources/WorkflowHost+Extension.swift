/*
 * Copyright 2022 Square Inc.
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

import Foundation
import RxSwift
import Workflow

public final class ObservableListener<OutputType>: Listener<OutputType> {
    private let subject = PublishSubject<OutputType>()

    public var observable: Observable<OutputType> {
        return subject.asObservable()
    }

    override public func send(_ output: OutputType) {
        subject.onNext(output)
    }
}

private enum WorkflowHostObservableListenerIdentifier {
    static let id = UUID()
}

extension WorkflowHost {
    public var renderingObservable: Observable<WorkflowType.Rendering> {
        if let listener = getRenderingListener(id: WorkflowHostObservableListenerIdentifier.id) as? ObservableListener {
            return listener.observable
        } else {
            let listener = ObservableListener<WorkflowType.Rendering>(id: WorkflowHostObservableListenerIdentifier.id)
            addRenderingListener(listener: listener)
            return listener.observable
        }
    }

    public var outputObservable: Observable<WorkflowType.Output> {
        if let listener = getOutputListener(id: WorkflowHostObservableListenerIdentifier.id) as? ObservableListener {
            return listener.observable
        } else {
            let listener = ObservableListener<WorkflowType.Output>(id: WorkflowHostObservableListenerIdentifier.id)
            addOutputListener(listener: listener)
            return listener.observable
        }
    }
}
