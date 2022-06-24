# AsyncWorker

Demonstrates how to create a `WorkflowConcurrency` async `Worker`.

This is an example of how you would create a closure based network request from within the async function of a `WorkflowConcurrency` `Worker`.

`AsyncWorkerWorkflow.swift` contains the `Worker` implementation.

This sample uses a local swift package reference for Workflow so that the Development.podspec doesn't have to have it's iOS deployment target increased to iOS 13+.
