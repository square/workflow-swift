This sample project utilizes the WorkflowCombine library to demonstrate its usage in a `Workflow`. It is a simple app with a label that updates the current date & time every second.

# Usage

The api design is identical to that of the current `WorkflowReactiveSwift` library, so to migrate your `Worker`s to use the `WorkflowCombine` library, all you should have to do is to switch the library import statement, as well 


### Notes

This library does **not** remove the usage of the `ReactiveSwift` library from the `Workflow` library. Currently the `Workflow` implementation is tightly coupled with `ReactiveSwift`, and this library is only limited to the `Worker`. Therefore, when utilizing both the existing `Workflow` and the new `Combine` backed `Worker` , you will need to utilize both the `ReactiveSwift` and `Combine` libraries.