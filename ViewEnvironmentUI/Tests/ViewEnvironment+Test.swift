import ViewEnvironment

public struct TestContext: Equatable {
    static var nonDefault: Self {
        .init(
            number: 999,
            string: "Lorem ipsum",
            bool: true
        )
    }

    var number: Int = 0
    var string: String = ""
    var bool: Bool = false
}

public struct TestContextKey: ViewEnvironmentKey {
    public static var defaultValue: TestContext { .init() }
}

extension ViewEnvironment {
    var testContext: TestContext {
        get { self[TestContextKey.self] }
        set { self[TestContextKey.self] = newValue }
    }
}

extension ViewEnvironment {
    static var nonDefault: Self {
        var environment = Self.empty
        environment.testContext = .nonDefault
        return environment
    }
}
