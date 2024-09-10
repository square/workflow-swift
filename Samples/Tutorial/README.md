# Tutorial

## Overview

Oh hi! Looks like you want build some software with Workflows! It's a bit different from traditional iOS development, so let's go through building a simple little TODO app to get the basics down.

## Layout

The project has both a starting point, as well as an example of the completed tutorial.

Nearly all of the code is in the `Frameworks` directory.

To help with the setup, we have created a few helpers:
- `TutorialViews`: A set of 3 views for the 3 screens we will be building, `Welcome`, `TodoList`, and `TodoEdit`.
- `TutorialBase`: This is the starting point to build out the tutorial. It contains view controllers that host the views from `TutorialViews` to see how they display.
    - Additionally, there is a `TutorialHostingViewController` that the AppDelegate sets as the root view controller. This will be our launching point for all of our workflows.
- `TutorialFinal`: This is an example of the completed tutorial - could be used as a reference if you get stuck.

## Getting started

The tutorial uses [Tuist](https://tuist.io/) for project configuration. Follow the main README instructions for getting set up with Tuist first, and then run:

```
$ cd Samples/Tutorial
$ tuist install
Resolving and fetching plugins.
Plugins resolved and fetched successfully.
Resolving and fetching dependencies.
...
$ tuist generate
Loading and constructing the graph
It might take a while if the cache is empty
Using cache binaries for the following targets: 
Generating workspace Tutorial.xcworkspace
Generating project Workflow
Generating project Tutorial
Generating project swift-case-paths
Generating project Development
Generating project xctest-dynamic-overlay
Generating project swift-identified-collections
Generating project ReactiveSwift
Generating project swift-collections
Generating project swift-perception
Generating project iOSSnapshotTestCase
Generating project RxSwift
Generating project swift-syntax
Project generated.
```

The `Tutorial.xcworkspace` workspace will open in Xcode automatically.

# Tutorial Steps

- [Tutorial 1](Tutorial1.md) - Single view backed by a workflow
- [Tutorial 2](Tutorial2.md) - Multiple views and navigation
- [Tutorial 3](Tutorial3.md) - State throughout a tree of workflows
- [Tutorial 4](Tutorial4.md) - Refactoring
- [Tutorial 5](Tutorial5.md) - Testing
