/*
 * Copyright 2025 Square Inc.
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

import Testing

@testable import Workflow

@MainActor
struct SinkEventHandlerTests {
    @Test
    func initialState() async throws {
        let subject = SinkEventHandler()
        #expect(subject.state == .busy)
    }

    @Test
    func stateTransitions() async throws {
        let subject = SinkEventHandler(state: .ready)

        #expect(subject.state == .ready)

        var stateDuringPerform: SinkEventHandler.State?
        var stateDuringEnqueue: SinkEventHandler.State?
        subject.performOrEnqueueEvent {
            stateDuringPerform = subject.state
        } deferred: {
            stateDuringEnqueue = subject.state
        }

        #expect(stateDuringPerform == .busy)
        #expect(stateDuringEnqueue == nil)
        #expect(subject.state == .ready)
    }

    // we are asserting things & depending on the main dispatch queue
    @MainActor
    @Test
    func reentrancyHandling() async throws {
        let subject = SinkEventHandler(state: .ready)

        var performCount = 0
        var enqueueCount = 0
        let incrementPerform = { performCount += 1 }
        let incrementEnqueue = { enqueueCount += 1 }

        subject.performOrEnqueueEvent {
            incrementPerform()
            subject.performOrEnqueueEvent {
                Issue.record("should not perform")
            } deferred: {
                incrementEnqueue()
            }
        } deferred: {
            Issue.record("should not enqueue")
        }

        // should have synchronously performed once and not yet enqueued
        #expect(performCount == 1)
        #expect(enqueueCount == 0)

        await drainMainQueue()

        // should have invoked the enqueued event
        #expect(performCount == 1)
        #expect(enqueueCount == 1)
    }

    @MainActor
    @Test
    func callbackReentrancyHandling() async throws {
        let subject = SinkEventHandler(state: .ready)

        var performCount = 0
        var enqueueCount = 0
        let incrementPerform = { performCount += 1 }
        let incrementEnqueue = { enqueueCount += 1 }

        let callback = subject.makeOnSinkEventCallback()

        callback( /* immediatePerform */ {
            incrementPerform()
            callback( /* immediatePerform */ {
                Issue.record("should not perform")
            }, /* deferredPerform */ {
                incrementEnqueue()
            })
        }, /* deferredPerform */ {
            Issue.record("should not enqueue")
        })

        // should have synchronously performed once and not yet enqueued
        #expect(performCount == 1)
        #expect(enqueueCount == 0)

        await drainMainQueue()

        // should have invoked the enqueued event
        #expect(performCount == 1)
        #expect(enqueueCount == 1)
    }

    @MainActor
    @Test
    func callbackIgnoresEventAfterDeinit() async throws {
        weak var weakRef: SinkEventHandler?
        let callback: OnSinkEvent
        let subject = SinkEventHandler(state: .ready)
        weakRef = subject
        callback = subject.makeOnSinkEventCallback()
        _ = consume subject

        // should not invoke anything because event handler deinited
        callback( /* immediatePerform */ {
            Issue.record("should not perform")
        }, /* deferredPerform */ {
            Issue.record("should not enqueue")
        })

        #expect(weakRef == nil)
    }

    @Test
    func explicitEventHandlingDisabled() async throws {
        let subject = SinkEventHandler(state: .ready)

        #expect(subject.state == .ready)

        subject.withEventHandlingSuspended {
            #expect(subject.state == .busy)

            subject.withEventHandlingSuspended {
                #expect(subject.state == .busy)
            }
        }

        #expect(subject.state == .ready)
    }
}
