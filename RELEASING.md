# Releasing workflow

## Production Releases

### Updating the release
1. Update `WORKFLOW_VERSION` in `version.rb` based on [`semver`](https://semver.org/).

1. Create a PR with the version change and merge to `main`.

1. Create the release on GitHub:
   1. Go to the [Releases](https://github.com/square/workflow-swift/releases) and `Draft a new release`.
   1. `Choose a tag` and create a tag for the new version. ex: `v1.0.0`.
   1. `Generate release notes`.
   1. Ensure the `Title` corresponds to the version we're publishing and the generated `Release Notes` are accurate.
   1. Hit `Publish release`.

At this point, the new release is available and can be consumed using the Swift Package Manager.

[Square specific] To make the new version available internally, [bump the version](https://go/spm-bump-dependency) through SPM.

### Publishing to CocoaPods

1. Xcode 15.4 is the currently recommended version to use to publish all pods. Due to a bug in CocoaPods, you will also need to download Xcode 14.2 and copy `Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/arc`from within the Xcode 14.2 app to the same location in Xcode 15.4.

1. Make sure you are set up with [`bundle exec pod trunk`](https://guides.cocoapods.org/making/getting-setup-with-trunk.html) and your CocoaPods account is a contributor for all pods. If you need to be added as a contributor, please [open a ticket requesting access](https://github.com/square/workflow-swift/issues/new).
    1. For Squares, membership is managed through the `workflow-swift-owners` registry group. Please request access to that group through Registry.
    1. Once you have access, you can register a session with `bundle exec pod trunk` using the group e-mail alias `workflow-swift-owners@squareup.com`:  
`bundle exec pod trunk register workflow-swift-owners@squareup.com 'Workflow Swift Owners' --description='Your computer description'`.
    1. You should receive an email from CocoaPods to confirm your session before you procede.

1. To avoid possible headaches when publishing podspecs, validation can be performed first.
    1. Make sure you're using Xcode 15.4 in the command line: `sudo xcode-select -s Path/to/Xcode15.4`.
    1. Run the following:
    ```bash
    bundle exec pod lib lint Workflow.podspec ViewEnvironment.podspec ViewEnvironmentUI.podspec WorkflowTesting.podspec WorkflowReactiveSwift.podspec WorkflowUI.podspec WorkflowRxSwift.podspec WorkflowReactiveSwiftTesting.podspec WorkflowRxSwiftTesting.podspec WorkflowSwiftUIExperimental.podspec WorkflowCombine.podspec WorkflowCombineTesting.podspec WorkflowConcurrency.podspec WorkflowConcurrencyTesting.podspec
    ```

1. Once validation passes on all pods, you can publish to CocoaPods.
    ```bash
    bundle exec pod trunk push Workflow.podspec --synchronous
    bundle exec pod trunk push WorkflowTesting.podspec  --synchronous
    bundle exec pod trunk push WorkflowReactiveSwift.podspec --synchronous
    bundle exec pod trunk push ViewEnvironment.podspec --synchronous
    bundle exec pod trunk push ViewEnvironmentUI.podspec --synchronous
    bundle exec pod trunk push WorkflowUI.podspec --synchronous
    bundle exec pod trunk push WorkflowRxSwift.podspec --synchronous
    bundle exec pod trunk push WorkflowReactiveSwiftTesting.podspec --synchronous
    bundle exec pod trunk push WorkflowRxSwiftTesting.podspec --synchronous
    bundle exec pod trunk push WorkflowSwiftUIExperimental.podspec --synchronous
    bundle exec pod trunk push WorkflowCombine.podspec --synchronous
    bundle exec pod trunk push WorkflowCombineTesting.podspec --synchronous
    bundle exec pod trunk push WorkflowConcurrency.podspec --synchronous
    bundle exec pod trunk push WorkflowConcurrencyTesting.podspec --synchronous
    ```

1. [Square specific] To make the new version available internally, update the [CocoaPods spec repo](https://go/cocoapod-specs).
