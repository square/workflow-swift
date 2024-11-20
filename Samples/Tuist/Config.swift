import ProjectDescription

let config = Config(
    // This breaks snapshot tests, because iOSSnapshotTestCase depends on XCTest.
    // ENABLE_TESTING_SEARCH_PATHS should sufficient but doesn't seem to work with
    // enforceExplicitDependencies enabled.
//    generationOptions: .options(enforceExplicitDependencies: true)
)
