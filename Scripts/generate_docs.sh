#!/usr/bin/env bash

set -euo pipefail

BUILD_PATH=docs_build
MERGED_PATH=generated_docs
REPO_NAME=workflow-swift

xcodebuild docbuild \
    -scheme Documentation \
    -derivedDataPath "$BUILD_PATH" \
    -workspace Samples/WorkflowDevelopment.xcworkspace \
    -destination generic/platform=iOS \
    DOCC_HOSTING_BASE_PATH="$REPO_NAME" \
    | xcpretty

find_archive() {
    find "$BUILD_PATH" -type d -name "$1.doccarchive" -print -quit
}

xcrun docc merge \
    $(find_archive ViewEnvironment) \
    $(find_archive ViewEnvironmentUI) \
    $(find_archive Workflow) \
    $(find_archive WorkflowSwiftUI) \
    $(find_archive WorkflowTesting) \
    $(find_archive WorkflowUI) \
    --output-path "$MERGED_PATH" \
    --synthesized-landing-page-name "$REPO_NAME"
