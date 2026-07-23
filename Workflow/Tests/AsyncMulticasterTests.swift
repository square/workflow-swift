import XCTest
@testable import Workflow

@MainActor
final class AsyncMulticasterTests: XCTestCase {
    func test_eachConsumerReceivesEveryValue() async {
        let multicaster = AsyncMulticaster<Int>()

        let streamA = multicaster.makeStream(bufferingPolicy: .unbounded)
        let streamB = multicaster.makeStream(bufferingPolicy: .unbounded)

        multicaster.yield(1)
        multicaster.yield(2)
        multicaster.finish()

        var receivedA: [Int] = []
        for await value in streamA { receivedA.append(value) }
        var receivedB: [Int] = []
        for await value in streamB { receivedB.append(value) }

        XCTAssertEqual(receivedA, [1, 2])
        XCTAssertEqual(receivedB, [1, 2])
    }

    func test_initialValueIsYieldedFirst() async {
        let multicaster = AsyncMulticaster<Int>()
        let stream = multicaster.makeStream(bufferingPolicy: .unbounded, initial: 0)

        multicaster.yield(1)
        multicaster.finish()

        var received: [Int] = []
        for await value in stream { received.append(value) }
        XCTAssertEqual(received, [0, 1])
    }

    func test_bufferingNewestDropsStaleValues() async {
        let multicaster = AsyncMulticaster<Int>()
        let stream = multicaster.makeStream(bufferingPolicy: .bufferingNewest(1), initial: 0)

        // Consumer hasn't started; only the newest value should survive.
        multicaster.yield(1)
        multicaster.yield(2)
        multicaster.yield(3)
        multicaster.finish()

        var received: [Int] = []
        for await value in stream { received.append(value) }
        XCTAssertEqual(received, [3])
    }

    func test_streamsMadeAfterFinishAreImmediatelyFinished() async {
        let multicaster = AsyncMulticaster<Int>()
        multicaster.finish()

        let stream = multicaster.makeStream(bufferingPolicy: .unbounded)
        var received: [Int] = []
        for await value in stream { received.append(value) }
        XCTAssertEqual(received, [])
    }

    func test_streamsMadeAfterFinishAreImmediatelyFinished_evenWithInitialValue() async {
        let multicaster = AsyncMulticaster<Int>()
        multicaster.finish()

        let stream = multicaster.makeStream(bufferingPolicy: .unbounded, initial: 42)
        var received: [Int] = []
        for await value in stream { received.append(value) }
        XCTAssertEqual(received, [])
    }

    func test_deallocation_finishesStreams() async {
        var multicaster: AsyncMulticaster<Int>? = AsyncMulticaster<Int>()
        let stream = multicaster!.makeStream(bufferingPolicy: .unbounded)
        multicaster!.yield(1)
        multicaster = nil

        var received: [Int] = []
        for await value in stream { received.append(value) }
        XCTAssertEqual(received, [1])
    }
}
