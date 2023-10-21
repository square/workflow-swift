/*
 * Copyright 2023 Square Inc.
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

import Combine

public final class AnyStore<Value>: Store {
    let store: any Store<Value>

    init(_ store: any Store<Value>) {
        self.store = store
    }

    public var value: Value {
        store.value
    }

    public var objectWillChange: ObjectWillChangePublisher {
        store.objectWillChange.map { _ in }
    }
}
