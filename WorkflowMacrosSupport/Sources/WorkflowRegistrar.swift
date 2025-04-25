// MARK: -

public struct WorkflowRegistrar: Equatable, Hashable, Codable {
    public init() {}
    public func mutate() {
        print("workflow registrar detected mutation")
        _accessDetectedTL.state = true
//        _accessDetected = true
    }
}

// fileprivate var _accessDetected = false

// import os

final class Ref<T: Sendable>: Sendable {
    var state: T

    init(_ value: T) {
        self.state = value
    }
}

@TaskLocal
private var _accessDetectedTL = Ref(false)

public func detectAccesses<T>(
    accessDetected: inout Bool,
    callback: () -> T
) -> T {
//    _accessDetected = false
//    defer { _accessDetected = false }
    let rez = $_accessDetectedTL.withValue(_accessDetectedTL) {
        _accessDetectedTL.state = false
        defer { accessDetected = _accessDetectedTL.state }
        return callback()
    }
    return rez

//    let result = callback()
//    accessDetected = _accessDetected
//    return result
}
