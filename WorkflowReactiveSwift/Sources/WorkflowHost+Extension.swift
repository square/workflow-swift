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
import ReactiveSwift
import Workflow

public final class SignalListener<OutputType>: Listener<OutputType> {
    private let (outputEvent, outputEventObserver) = Signal<OutputType, Never>.pipe()

    public var signal: Signal<OutputType, Never> {
        return outputEvent
    }

    override public func send(_ output: OutputType) {
        outputEventObserver.send(value: output)
    }
}

private enum WorkflowHostSignalListenerIdentifier {
    static let id = UUID()
}

extension WorkflowHost {
    public var renderingSignal: Signal<WorkflowType.Rendering, Never> {
        if let signalListener = getRenderingListener(id: WorkflowHostSignalListenerIdentifier.id) as? SignalListener {
            return signalListener.signal
        } else {
            let listener = SignalListener<WorkflowType.Rendering>(id: WorkflowHostSignalListenerIdentifier.id)
            addRenderingListener(listener: listener)
            return listener.signal
        }
    }

    public var outputSignal: Signal<WorkflowType.Output, Never> {
        if let signalListener = getOutputListener(id: WorkflowHostSignalListenerIdentifier.id) as? SignalListener {
            return signalListener.signal
        } else {
            let listener = SignalListener<WorkflowType.Output>(id: WorkflowHostSignalListenerIdentifier.id)
            addOutputListener(listener: listener)
            return listener.signal
        }
    }
}
