# Releasing workflow

## Production Releases

---

***Before you begin:*** *Please make sure you are set up with 
[`pod trunk`](https://guides.cocoapods.org/making/getting-setup-with-trunk.html) and your CocoaPods
account is a contributor to both the Workflow and WorkflowUI pods. If you need to be added as a
contributor, please [open a ticket requesting access](https://github.com/square/workflow-swift/issues/new),
and assign it to @bencochran or @aquageek.*

---
1. Merge an update of [the change log](CHANGELOG.md) with the changes since the last release.

1. Make sure you're on the `trunk` branch (or fix branch, e.g. `v0.1-fixes`).

1. Create a commit and tag the commit with the version number:
   ```bash
   git commit -am "Releasing v0.1.0."
   git tag v0.1.0
   ```

1. Publish to CocoaPods:
    ```bash
    bundle exec pod trunk push Workflow.podspec
    bundle exec pod trunk push WorkflowTesting.podspec
    bundle exec pod trunk push WorkflowUI.podspec
    ```

1. Bump the version
   - **Swift:** Update `s.version` in `*.podspec` to the new version, e.g. `0.2.0`.

1. Commit the new snapshot version:
   ```
   git commit -am "Finish releasing v0.1.0."
   ```

1. Push your commits and tag:
   ```
   git push origin trunk
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

1. If this was a fix release, merge changes to the trunk branch:
   ```bash
   git checkout trunk
   git pull
   git merge --no-ff v0.1-fixes
   # Resolve conflicts. Accept trunk's versions of gradle.properties and podspecs.
   git push origin trunk
   ```

1. Publish the website. See https://github.com/square/workflow/blob/trunk/RELEASING.md.

### Validating Markdown

Since all of our high-level documentation is written in Markdown, we run a linter in CI to ensure
we use consistent formatting. Lint errors will fail your PR builds, so to run locally, install
[markdownlint](https://github.com/markdownlint/markdownlint):

```bash
gem install mdl
```

Run the linter using the `lint_docs.sh`:

```bash
./lint_docs.sh
```

Rules can be configured by editing `.markdownlint.rb`.
