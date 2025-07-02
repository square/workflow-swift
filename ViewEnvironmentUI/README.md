# ViewEnvironmentUI

`ViewEnvironmentUI` provides some fundamental types to build UI:

- A means to propagate a `ViewEnvironment` through a hierarchy of object nodes, and an implementation of propagation through `UIViewController`s and `UIView`s.
- The `ViewDescription` type, a declarative way to represent a view controller.
- The `Screen` protocol, to create your own types that can produce a `ViewDescription` from a `ViewEnvironment`.
