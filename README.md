# Workflow for Swift

![Swift CI](https://github.com/square/workflow-swift/workflows/Swift%20CI/badge.svg)
[![GitHub license](https://img.shields.io/badge/license-Apache%20License%202.0-blue.svg?style=flat)](https://www.apache.org/licenses/LICENSE-2.0)

A unidirectional data flow library for Swift and [Kotlin](https://github.com/square/workflow-kotlin), emphasizing:

* Strong support for state-machine driven UI and navigation.
* Composition and scaling.
* Effortless separation of business and UI concerns.

## Using Workflows in your project

### Swift Package Manager

[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-orange.svg)](#swift-package-manager)

If you are developing your own package, be sure that Workflow is included in `dependencies`
in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/square/workflow-swift", from: "3.11.0")
]
```

In Xcode 11+, add Workflow directly as a dependency to your project with
`File` > `Swift Packages` > `Add Package Dependency...`. Provide the git URL when prompted: `git@github.com:square/workflow-swift.git`.

## Resources

* [API Reference](https://square.github.io/workflow-swift/documentation/)
* [Documentation](https://square.github.io/workflow/)

## Local Development

This project uses [Mise](https://mise.jdx.dev/) and [Tuist](https://tuist.io/) to generate a project for local development. Follow the steps below for the recommended setup for zsh.

```sh
# install mise
brew install mise
# add mise activation line to your zshrc
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
# load mise into your shell
source ~/.zshrc
# install dependencies
mise install

# only necessary for first setup or after changing dependencies
tuist install --path Samples
# generates and opens the Xcode project
tuist generate --path Samples
```

## Releasing and Deploying

See [RELEASING.md](RELEASING.md).

## License

<pre>
Copyright 2019 Square Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
</pre>
