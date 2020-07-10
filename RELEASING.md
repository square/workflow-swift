# Releasing workflow

## Production Releases

---

***Before you begin:*** Please make sure you are set up with 
[`pod trunk`](https://guides.cocoapods.org/making/getting-setup-with-trunk.html) and your CocoaPods
account is a contributor to both the Workflow and WorkflowUI pods. If you need to be added as a
contributor, please [open a ticket requesting access](https://github.com/square/workflow-swift/issues/new),
and assign it to @bencochran, @aquageek or @dhavalshreyas.

---

1. Merge an update of [the change log](CHANGELOG.md) with changes since the last release.

1. If there has been a **Breaking Change**, since last release, update `VERSION` and bump up `MAJOR`.

1. Make sure you're on the `main` branch (or fix branch, e.g. `v0.1-fixes`).

1. Create a commit and tag the commit with the version number:
   ```bash
   git commit -am "Releasing v0.1.0."
   git tag v0.1.0
   ```

1. Push your commits and tag:
   ```
   git push origin main
   # or git push origin fix-branch
   git push origin v0.1.0
   ```

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
    ```

1. Bump the version: Update `VERSION` to the new version, e.g. `0.2.0`.

1. Commit the new snapshot version:
   ```
   git commit -am "Finish releasing v0.1.0."
   ```

1. Push your commits and tag:
   ```
   git push origin main
   # or git push origin fix-branch
   git push origin v0.1.0
   ```

1. Create the release on GitHub:
   1. Go to the [Releases](https://github.com/square/workflow-swift/releases) page for the GitHub
      project.
   1. Click "Draft a new release".
   1. Enter the tag name you just pushed.
   1. Title the release with the same name as the tag.
   1. Copy & paste the changelog entry for this release into the description.
   1. If this is a pre-release version, check the pre-release box.
   1. Hit "Publish release".

1. If this was a fix release, merge changes to the main branch:
   ```bash
   git checkout main
   git pull
   git merge --no-ff v0.1-fixes
   # Resolve conflicts. Accept main's versions of gradle.properties and podspecs.
   git push origin main
   ```