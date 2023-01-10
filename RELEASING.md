# Releasing workflow

## Production Releases

---

***Before you begin:*** Please make sure you are set up with 
[`bundle exec pod trunk`](https://guides.cocoapods.org/making/getting-setup-with-trunk.html) and your CocoaPods
account is a contributor for all pods. If you need to be added as a
contributor, please [open a ticket requesting access](https://github.com/square/workflow-swift/issues/new).

For Squares, membership is managed through the `Workflow Swift Owners` registry group. Please request access to that group through Registry. Once you have access, you can register a session with `bundle exec pod trunk` using the group e-mail alias `workflow-swift-owners@squareup.com`.

`bundle exec pod trunk register workflow-swift-owners@squareup.com 'Workflow Swift Owners' --description='Your computer description'`

---

> ⚠️ [Optional] To avoid possible headaches when publishing podspecs, validation can be performed before updating the Workflow version number(s). To do this, run the following in the root directory of this repo:
> ```bash
> bundle exec pod lib lint Workflow.podspec WorkflowTesting.podspec WorkflowReactiveSwift.podspec WorkflowUI.podspec WorkflowRxSwift.podspec WorkflowReactiveSwiftTesting.podspec WorkflowRxSwiftTesting.podspec WorkflowSwiftUI.podspec WorkflowCombine.podspec WorkflowCombineTesting.podspec
> ```
And then run a similar command to check the `WorkflowConcurrency*` libraries. These specs will fail default validation as their version differs from the git tag used, so run the command with the `--allow-warnings` option, and check that only that warning is produced.
> ```bash
> bundle exec pod lib lint WorkflowConcurrency.podspec WorkflowConcurrencyTesting.podspec --allow-warnings
> ```

1. Update `VERSION` file based on [`semver`](https://semver.org/).

1. Create a PR with the version change and merge to `main`.

1. Create the release on GitHub:
   1. Go to the [Releases](https://github.com/square/workflow-swift/releases).
   1. `Choose a tag` and create a tag with the `VERSION`. ex: `v1.0.0`
   1. `Auto-generate release notes`
   1. Ensure the `Title` corresponds to the `VERSION` we're publishing and the generated `Release Notes` are accurate.
   1. Hit "Publish release".

1. Publish to CocoaPods:
    ```bash
    bundle exec pod trunk push Workflow.podspec --synchronous
    bundle exec pod trunk push WorkflowTesting.podspec  --synchronous
    bundle exec pod trunk push WorkflowReactiveSwift.podspec --synchronous
    bundle exec pod trunk push WorkflowUI.podspec --synchronous
    bundle exec pod trunk push WorkflowRxSwift.podspec --synchronous
    bundle exec pod trunk push WorkflowReactiveSwiftTesting.podspec --synchronous
    bundle exec pod trunk push WorkflowRxSwiftTesting.podspec --synchronous
    bundle exec pod trunk push WorkflowSwiftUI.podspec --synchronous
    bundle exec pod trunk push WorkflowCombine.podspec --synchronous
    bundle exec pod trunk push WorkflowCombineTesting.podspec --synchronous

    # Note: If the following fail due to a validation warning about their version number not matching the git tag, it is safe to ignore, and publish anyway by adding the `--allow-warnings` option to the command.
    bundle exec pod trunk push WorkflowConcurrency.podspec --synchronous
    bundle exec pod trunk push WorkflowConcurrencyTesting.podspec --synchronous
    ```

1. [Square specific] To make the new version available internally, update the [CocoaPods spec repo](https://go/cocoapod-specs).
