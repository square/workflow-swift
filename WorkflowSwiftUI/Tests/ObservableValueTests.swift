//
//  ObservableValueTests.swift
//
//
//  Created by Mark Johnson on 8/11/22.
//

import Combine
import XCTest
@testable import WorkflowSwiftUI

@available(iOS 13.0, macOS 10.15, *)
class ObservableValueTests: XCTestCase {
    func testValueProperty() throws {
        let (observableValue, _) = ObservableValue.makeObservableValue("Initial Value")
        XCTAssertEqual("Initial Value", observableValue.value)
    }

    func testSinkUpdatingValue() throws {
        let (observableValue, sink) = ObservableValue.makeObservableValue("Initial Value")
        XCTAssertEqual("Initial Value", observableValue.value)
        sink.send("Updated Value")
        XCTAssertEqual("Updated Value", observableValue.value)
    }

    func testMemberLookup() throws {
        let model = Model(title: "Title", isOn: false)
        let (observableValue, _) = ObservableValue.makeObservableValue(model)
        XCTAssertEqual("Title", observableValue.title)
    }

    func testScopedValue() throws {
        let model = Model(title: "Title", isOn: false)
        let (observableValue, _) = ObservableValue.makeObservableValue(model)
        let scopedValue = observableValue.scope(\.title)
        XCTAssertEqual("Title", scopedValue.value)
    }

    func testScopedValueUpdating() throws {
        var model = Model(title: "Title", isOn: false)
        let (observableValue, sink) = ObservableValue.makeObservableValue(model)
        let scopedValue = observableValue.scope(\.title)
        model.title = "Updated Title"
        sink.send(model)
        XCTAssertEqual("Updated Title", scopedValue.value)
    }

    func testObservingObjectChange() throws {
        var model = Model(title: "Title", isOn: false)
        let (observableValue, sink) = ObservableValue.makeObservableValue(model)
        model.title = "Updated Title"
        let expectation = XCTestExpectation()
        let cancellable = observableValue.objectWillChange.sink {
            expectation.fulfill()
        }
        sink.send(model)
        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
    }

    func testObjectWillChangeNotFiringForEquatableObjects() throws {
        let model = Model(title: "Title", isOn: false)
        let (observableValue, sink) = ObservableValue.makeObservableValue(model, isDuplicate: { $0 == $1 })
        let expectation = XCTestExpectation()
        expectation.isInverted = true
        let cancellable = observableValue.objectWillChange.sink {
            expectation.fulfill()
        }
        sink.send(model)
        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
    }

    func testObjectWillChangeNotFiringForEquatableScopedObjects() throws {
        let model = Model(title: "Title", isOn: false)
        let (observableValue, sink) = ObservableValue.makeObservableValue(model)
        let scopedValue = observableValue.scope(\.title)
        let expectation = XCTestExpectation()
        expectation.isInverted = true
        let cancellable = scopedValue.objectWillChange.sink {
            expectation.fulfill()
        }
        sink.send(model)
        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
    }
}

private struct Model: Equatable {
    var title: String
    var isOn: Bool
}
