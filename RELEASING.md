# Releasing workflow

## Production Releases

Workflow is now vended exclusively via Swift Package Manager.

Create the release on GitHub:
   1. Go to the [Releases](https://github.com/square/workflow-swift/releases) and `Draft a new release`.
   1. `Choose a tag` and create a tag for the new version. ex: `v1.0.0`.
   1. `Generate release notes`.
   1. Ensure the `Title` corresponds to the version we're publishing and the generated `Release Notes` are accurate.
   1. Hit `Publish release`.

[Square specific] To make the new version available internally, [bump the version](https://go/spm-bump-dependency) through SPM.
