import Combine

public struct ReadOnlyCurrentValueSubject<Output, Failure>: Combine.Publisher where Failure: Error {
    private let currentValueSubject: CurrentValueSubject<Output, Failure>

    public var value: Output {
        currentValueSubject.value
    }

    private init(_ value: Output) {
        self.currentValueSubject = CurrentValueSubject<Output, Failure>(value)
    }

    public static func publisher(value: Output) -> (Self, CurrentValueSubject<Output, Failure>) {
        let publisher = Self(value)
        return (publisher, publisher.currentValueSubject)
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        currentValueSubject.receive(subscriber: subscriber)
    }
}
