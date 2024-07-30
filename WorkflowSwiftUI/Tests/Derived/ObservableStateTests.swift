// Derived from
// https://github.com/pointfreeco/swift-composable-architecture/blob/1.12.1/Tests/ComposableArchitectureTests/ObservableTests.swift

import CasePaths
import IdentifiedCollections
import Perception
import WorkflowSwiftUI
import XCTest

final class ObservableStateTests: XCTestCase {
    func testBasics() async {
        var state = ChildState()
        let countDidChange = expectation(description: "count.didChange")

        withPerceptionTracking {
            _ = state.count
        } onChange: {
            countDidChange.fulfill()
        }

        state.count += 1
        await fulfillment(of: [countDidChange], timeout: 0)
        XCTAssertEqual(state.count, 1)
    }

    func testChildCountMutation() async {
        var state = ParentState()
        let childCountDidChange = expectation(description: "child.count.didChange")

        withPerceptionTracking {
            _ = state.child.count
        } onChange: {
            childCountDidChange.fulfill()
        }
        withPerceptionTracking {
            _ = state.child
        } onChange: {
            XCTFail("state.child should not change.")
        }

        state.child.count += 1
        await fulfillment(of: [childCountDidChange], timeout: 0)
        XCTAssertEqual(state.child.count, 1)
    }

    func testChildReset() async {
        var state = ParentState()
        let childDidChange = expectation(description: "child.didChange")

        let child = state.child
        withPerceptionTracking {
            _ = child.count
        } onChange: {
            XCTFail("child.count should not change.")
        }
        withPerceptionTracking {
            _ = state.child
        } onChange: {
            childDidChange.fulfill()
        }

        state.child = ChildState(count: 42)
        await fulfillment(of: [childDidChange], timeout: 0)
        XCTAssertEqual(state.child.count, 42)
    }

    func testReplaceChild() async {
        var state = ParentState()
        let childDidChange = expectation(description: "child.didChange")

        withPerceptionTracking {
            _ = state.child
        } onChange: {
            childDidChange.fulfill()
        }

        state.child.replace(with: ChildState(count: 42))
        await fulfillment(of: [childDidChange], timeout: 0)
        XCTAssertEqual(state.child.count, 42)
    }

    func testResetChild() async {
        var state = ParentState(child: ChildState(count: 42))
        let childDidChange = expectation(description: "child.didChange")

        withPerceptionTracking {
            _ = state.child
        } onChange: {
            childDidChange.fulfill()
        }

        state.child.reset()
        await fulfillment(of: [childDidChange], timeout: 0)
        XCTAssertEqual(state.child.count, 0)
    }

    func testSwapSiblings() async {
        var state = ParentState(
            child: ChildState(count: 1),
            sibling: ChildState(count: -1)
        )
        let childDidChange = expectation(description: "child.didChange")
        let siblingDidChange = expectation(description: "sibling.didChange")

        withPerceptionTracking {
            _ = state.child
        } onChange: {
            childDidChange.fulfill()
        }
        withPerceptionTracking {
            _ = state.sibling
        } onChange: {
            siblingDidChange.fulfill()
        }

        state.swap()
        await fulfillment(of: [childDidChange], timeout: 0)
        await fulfillment(of: [siblingDidChange], timeout: 0)
        XCTAssertEqual(state.child.count, -1)
        XCTAssertEqual(state.sibling.count, 1)
    }

    func testOptional() async {
        // nil -> value
        do {
            var state = ParentState(optional: nil)
            let optionalDidChange = expectation(description: "optional.didChange")
            
            withPerceptionTracking {
                _ = state.optional
            } onChange: {
                optionalDidChange.fulfill()
            }
            
            state.optional = ChildState(count: 42)
            await fulfillment(of: [optionalDidChange], timeout: 0)
            XCTAssertEqual(state.optional?.count, 42)
        }

        // nil -> nil
        do {
            var state = ParentState(optional: nil)
            let optionalDidChange = expectation(description: "optional.didChange")
            
            withPerceptionTracking {
                _ = state.optional
            } onChange: {
                optionalDidChange.fulfill()
            }
            
            state.optional = nil
            await fulfillment(of: [optionalDidChange], timeout: 0)
            XCTAssertNil(state.optional)
        }

        // value -> nil
        do {
            var state = ParentState(optional: ChildState())
            let optionalDidChange = expectation(description: "optional.didChange")
            
            withPerceptionTracking {
                _ = state.optional
            } onChange: {
                optionalDidChange.fulfill()
            }
            
            state.optional = nil
            await fulfillment(of: [optionalDidChange], timeout: 0)
            XCTAssertNil(state.optional)
        }
    }

    func testMutateOptional() async {
        var state = ParentState(optional: ChildState())
        let optionalCountDidChange = expectation(description: "optional.count.didChange")

        withPerceptionTracking {
            _ = state.optional
        } onChange: {
            XCTFail("Optional should not change")
        }
        let optional = state.optional
        withPerceptionTracking {
            _ = optional?.count
        } onChange: {
            optionalCountDidChange.fulfill()
        }

        state.optional?.count += 1
        await fulfillment(of: [optionalCountDidChange], timeout: 0)
        XCTAssertEqual(state.optional?.count, 1)
    }

    func testReplaceWithCopy() async {
        let childState = ChildState(count: 1)
        var childStateCopy = childState
        childStateCopy.count = 2
        var state = ParentState(child: childState, sibling: childStateCopy)
        let childCountDidChange = expectation(description: "child.count.didChange")

        withPerceptionTracking {
            _ = state.child.count
        } onChange: {
            childCountDidChange.fulfill()
        }

        state.child.replace(with: state.sibling)

        await fulfillment(of: [childCountDidChange], timeout: 0)
        XCTAssertEqual(state.child.count, 2)
        XCTAssertEqual(state.sibling.count, 2)
    }

    func testIdentifiedArray_AddElement() {
        var state = ParentState()
        let rowsDidChange = expectation(description: "rowsDidChange")

        withPerceptionTracking {
            _ = state.rows
        } onChange: {
            rowsDidChange.fulfill()
        }

        state.rows.append(ChildState())
        XCTAssertEqual(state.rows.count, 1)
        wait(for: [rowsDidChange], timeout: 0)
    }

    func testIdentifiedArray_MutateElement() {
        var state = ParentState(rows: [
            ChildState(),
            ChildState(),
        ])
        let firstRowCountDidChange = expectation(description: "firstRowCountDidChange")

        withPerceptionTracking {
            _ = state.rows
        } onChange: {
            XCTFail("rows should not change")
        }
        withPerceptionTracking {
            _ = state.rows[0]
        } onChange: {
            XCTFail("rows[0] should not change")
        }
        withPerceptionTracking {
            _ = state.rows[0].count
        } onChange: {
            firstRowCountDidChange.fulfill()
        }
        withPerceptionTracking {
            _ = state.rows[1].count
        } onChange: {
            XCTFail("rows[1].count should not change")
        }

        state.rows[0].count += 1
        XCTAssertEqual(state.rows[0].count, 1)
        wait(for: [firstRowCountDidChange], timeout: 0)
    }

    func testCopy() {
        var state = ParentState()
        var childCopy = state.child.copy()
        childCopy.count = 42
        let childCountDidChange = expectation(description: "childCountDidChange")

        withPerceptionTracking {
            _ = state.child.count
        } onChange: {
            childCountDidChange.fulfill()
        }

        state.child.replace(with: childCopy)
        XCTAssertEqual(state.child.count, 42)
        wait(for: [childCountDidChange], timeout: 0)
    }

    func testArrayAppend() {
        var state = ParentState()
        let childrenDidChange = expectation(description: "childrenDidChange")

        withPerceptionTracking {
            _ = state.children
        } onChange: {
            childrenDidChange.fulfill()
        }

        state.children.append(ChildState())
        wait(for: [childrenDidChange])
    }

    func testArrayMutate() {
        var state = ParentState(children: [ChildState()])

        withPerceptionTracking {
            _ = state.children
        } onChange: {
            XCTFail("children should not change")
        }

        state.children[0].count += 1
    }
}

@ObservableState
private struct ChildState: Equatable, Identifiable {
    let id = UUID()
    var count = 0
    mutating func replace(with other: Self) {
        self = other
    }

    mutating func reset() {
        self = Self()
    }

    mutating func copy() -> Self {
        self
    }
}

@ObservableState
private struct ParentState: Equatable {
    var child = ChildState()
    var children: [ChildState] = []
    var optional: ChildState?
    var rows: IdentifiedArrayOf<ChildState> = []
    var sibling = ChildState()
    mutating func swap() {
        let childCopy = child
        child = sibling
        sibling = childCopy
    }
}
