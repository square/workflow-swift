# Workflow v1.0β Migration Guide

## Removed APIs

### SignalWorker

`SignalWorker` was deprecated in Workflow v1.0α and has been removed in the beta. See details in the alpha migration guide, [below](#signalworker-reactiveswiftsignal).

### Run `Worker`

`context.awaitResult` was deprecated in Workflow v1.0α and has been removed in the beta. See details in the alpha migration guide, [below](#run-worker).

### Child `Workflow`s

`Workflow.rendered(with:key:)` was deprecated in Workflow v1.0α and has been removed in the beta. See details in the alpha migration guide, [below](#render-child-workflow).
`RenderContext.render(workflow:key:outputMap:)` has been made `internal` instead of `public`. Child `Workflow`s should be rendered via `ChildWorkflow().rendered(in: context)` instead.

### Testing APIs

All of the deprecated APIs covered in [Testing](#testing) below have been removed in the beta:
* `RenderTester.render(file:expectedState:expectedOutput:expectedWorkers:expectedWorkflows:expectedSideEffects:assertions:)`
* `RenderTester.render(file:line:with:assertions:)`
* `RenderTester.assert(state:)`
* `RenderExpectations`
* `ExpectedOutput`
* `ExpectedWorker`
* `ExpectedState`
* `ExpectedSideEffect`
* `ExpectedWorkflow`
* `WorkflowActionTester.send(action:outputAssertions:)`
* `WorkflowActionTester.assertState(_:)`

---

# Workflow v1.0α Migration Guide

Nothing fundamental about how you use **Workflow** has changed, though you’ll notice some of the APIs have been renamed and using `Worker` requires an additional import.

## Workers
In v1.0α, `SideEffect`, a more fundamental primitive to execute async work is introduced. This enables `Workers` to be rewritten as a specialized type of a `Workflow` itself. 

`Worker` moved into a new module, `WorkflowReactiveSwift`. Add `import WorkflowReactiveSwift` to use `Worker`.

### Keyed
An important consequence of this change is that `Worker`s are now keyed (on `WorkerType` + provided `key`). Hence, we cannot `run` multiple workers, of the same type, using the same key.

```swift
// Before:
// This would have worked since the `Worker`s being executed were not keyed.
awaitResult(Worker(url: "abc.com"))
awaitResult(Worker(url: "xyz.com"))

// After upgrading to v1.0, this would fail since both workers are of the same type and have not been provided a key

// Now:
Worker(url: "abc.com")
    .running(in: context, key: "abc")
Worker(url: "xyz.com")
    .running(in: context, key: "xyz")

// Provide a `key` while running multiple `Worker`s of the same type.
```

### SignalWorker (ReactiveSwift.Signal)
`SignalWorker` has been deprecated, instead, `Signal`/`SignalProducer` now conform to `AnyWorkflowConvertible`.

```swift
// Before:
context.awaitResult(for: SignalWorker(key: "key", signal: signal))

// After:
signal.running(in: context, key: "key")
```

## API
In preparation for a v1.0, we focused on making the Workflow APIs consistent (both within iOS and across Android and iOS). As such, several APIs have been deprecated in favor of the new ones.

### Run `Worker`:
```swift
// Before
context.awaitResult(for: MyWorker())

// After
MyWorker().running(in: context)
```

### Render Child Workflow

```swift
// Before
ChildWorkflow().rendered(with: context)

// After
ChildWorkflow().rendered(in: context)
```

## Testing
A new chainable RenderTester API:

```swift
// Before
NameLoadingWorkflow()
    .renderTester(initialState: .init(state: .loading, token: "user-token"))
    .render(
        with: RenderExpectations(
            expectedOutput: ExpectedOutput(output: .complete),
            expectedState: ExpectedState(state: expectedState),
            expectedWorkers: [
                ExpectedWorker(
                    worker: LoadingWorker(token: "user-token"),
                    output: .success("Ben Cochran")
                ),
            ]
        ),
        assertions: { rendering in
            XCTAssertEqual(rendering.title, "Loading")
        }
    )

// After
NameLoadingWorkflow()
    .renderTester(initialState: .init(state: .loading, token: "user-token"))
    .expect(
        worker: LoadingWorker(token: "user-token"),
        producingOutput: .success("Ben Cochran")
    )
    .render { rendering in 
        XCTAssertEqual(rendering.title, "Loading")
    }
    .verify(output: .complete)
```

#### Actions

```swift
// Before:
Action
    .tester(withState: initialState)
    .send(action: .action) { output in
        XCTAssertNil(output, 1)
    }

// After:
Action
    .tester(withState: initialState)
    .send(action: .action)
    .verifyOutput { output in
        XCTAssertNil(output, 1)
    }
```

### `expect` methods come in the following shapes:

* **Workflows**:
    * `expectWorkflow(workflowType: WorkflowType.Type, key: String, producingRendering: WorkflowType.Rendering, producingOutput: WorkflowType.Output?, assertions: ((WorkflowType) -> Void)?)`
* **Workers**
    * `expect(worker: WorkerType, producingOutput: WorkerType.Output?)`
* **Side effects**
    * `expectSideEffect(key: AnyHashable, producingAction: ActionType?)`

### `verify` methods come in the following:

* **Actions**
    * `verifyAction(assertions: (Action) -> Void)`
    * `verify(action: Action)` (when Equatable)
    * `verifyNoAction()`
* **Output**
    * `verifyOutput(assertions: (Output) -> Void)`
    * `verify(output: Output)` (when Equatable)
    * `verifyNoOutput()`
* **Resulting state**
    * `verifyState(assertions: (State) -> Void)`
    * `verify(state: State)` (when Equatable)
