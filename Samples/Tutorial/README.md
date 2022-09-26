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

The tutorial uses [CocoaPods](https://guides.cocoapods.org/using/index.html) for dependency management. To get set up, run the following:

```sh
$ cd Samples/Tutorial
$ bundle install
...
Bundle complete!
$ bundle exec pod install
Analyzing dependencies
Downloading dependencies
Generating Pods project
Integrating client project
Pod installation complete!
```

Then open `Tutorial.xcworkspace` in Xcode.

# Tutorial Steps

- [Tutorial 1](Tutorial1.md) - Single view backed by a workflow
- [Tutorial 2](Tutorial2.md) - Multiple views and navigation
- [Tutorial 3](Tutorial3.md) - State throughout a tree of workflows
- [Tutorial 4](Tutorial4.md) - Refactoring
- [Tutorial 5](Tutorial5.md) - Testing
