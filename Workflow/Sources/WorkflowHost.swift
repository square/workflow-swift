/*
 * Copyright 2020 Square Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import ReactiveSwift

/// Defines a type that receives debug information about a running workflow hierarchy.
public protocol WorkflowDebugger {
    /// Called once when the workflow hierarchy initializes.
    ///
    /// - Parameter snapshot: Debug information about the workflow hierarchy.
    func didEnterInitialState(snapshot: WorkflowHierarchyDebugSnapshot)

    /// Called when an update occurs anywhere within the workflow hierarchy.
    ///
    /// - Parameter snapshot: Debug information about the workflow hierarchy *after* the update.
    /// - Parameter updateInfo: Information about the update.
    func didUpdate(snapshot: WorkflowHierarchyDebugSnapshot, updateInfo: WorkflowUpdateDebugInfo)
}

/// Manages an active workflow hierarchy.
public final class WorkflowHost<WorkflowType: Workflow> {
    private let (outputEvent, outputEventObserver) = Signal<WorkflowType.Output, Never>.pipe()

    // @testable
    let rootNode: WorkflowNode<WorkflowType>

    private let mutableRendering: MutableProperty<WorkflowType.Rendering>

    /// Represents the `Rendering` produced by the root workflow in the hierarchy. New `Rendering` values are produced
    /// as state transitions occur within the hierarchy.
    public let rendering: Property<WorkflowType.Rendering>

    /// Context object to pass down to descendant nodes in the tree.
    let context: HostContext

    private var debugger: WorkflowDebugger? {
        context.debugger
    }

    /// Initializes a new host with the given workflow at the root.
    ///
    /// - Parameter workflow: The root workflow in the hierarchy
    /// - Parameter observers: An optional array of `WorkflowObservers` that will allow runtime introspection for this `WorkflowHost`
    /// - Parameter debugger: An optional debugger. If provided, the host will notify the debugger of updates
    ///                       to the workflow hierarchy as state transitions occur.
    public init(
        workflow: WorkflowType,
        observers: [WorkflowObserver] = [],
        debugger: WorkflowDebugger? = nil
    ) {
        let observer = WorkflowObservation
            .sharedObserversInterceptor
            .workflowObservers(for: observers)
            .chained()

        self.context = HostContext(
            observer: observer,
            debugger: debugger
        )

        self.rootNode = WorkflowNode(
            workflow: workflow,
            hostContext: context,
            parentSession: nil
        )

        self.mutableRendering = MutableProperty(rootNode.render())
        self.rendering = Property(mutableRendering)
        rootNode.enableEvents()

        debugger?.didEnterInitialState(snapshot: rootNode.makeDebugSnapshot())

        rootNode.onOutput = { [weak self] output in
            self?.handle(output: output)
        }
    }

    /// Update the input for the workflow. Will cause a render pass.
    public func update(workflow: WorkflowType) {
        context.invalidateTree()
        rootNode.update(workflow: workflow)

        // Treat the update as an "output" from the workflow originating from an external event to force a render pass.
        let output = WorkflowNode<WorkflowType>.Output(
            outputEvent: nil,
            debugInfo: context.ifDebuggerEnabled {
                WorkflowUpdateDebugInfo(
                    workflowType: "\(WorkflowType.self)",
                    kind: .didUpdate(source: .external)
                )
            }
        )
        handle(output: output)
    }

    private func handle(output: WorkflowNode<WorkflowType>.Output) {
        let newRendering = rootNode.render()
        context.markTreeValid()

        mutableRendering.value = newRendering

        if let outputEvent = output.outputEvent {
            outputEventObserver.send(value: outputEvent)
        }

        debugger?.didUpdate(
            snapshot: rootNode.makeDebugSnapshot(),
            updateInfo: output.debugInfo.unwrappedOrErrorDefault
        )

        rootNode.enableEvents()
    }

    /// A signal containing output events emitted by the root workflow in the hierarchy.
    public var output: Signal<WorkflowType.Output, Never> {
        outputEvent
    }
}

// MARK: - HostContext

/// A context object to expose certain root-level information to each node
/// in the Workflow tree.
final class HostContext {
    let observer: WorkflowObserver?
    let debugger: WorkflowDebugger?

    private var isEntireTreeInvalid = true
    private var invalidatedNodes: Set<WorkflowSession.Identifier> = []

    fileprivate func invalidateTree() { isEntireTreeInvalid = true }
    fileprivate func markTreeValid() {
        isEntireTreeInvalid = false
        invalidatedNodes.removeAll(keepingCapacity: true)
    }

    func invalidateNodesForSession(_ session: WorkflowSession) {
        var currentSession: WorkflowSession? = session
        while let nextSession = currentSession {
            defer { currentSession = currentSession?.parent }
            invalidatedNodes.insert(nextSession.sessionID)
        }
    }

    func invalidateNodes(from node: WorkflowNode<some Workflow>) {
        invalidateNodesForSession(node.session)
    }

    func isNodeValid(_ nodeID: WorkflowSession.Identifier) -> Bool {
        if isEntireTreeInvalid { return false }
        return !invalidatedNodes.contains(nodeID)
    }

    init(
        observer: WorkflowObserver?,
        debugger: WorkflowDebugger?
    ) {
        self.observer = observer
        self.debugger = debugger
    }
}

extension HostContext {
    func ifDebuggerEnabled<T>(
        _ perform: () -> T
    ) -> T? {
        debugger != nil ? perform() : nil
    }
}

// MARK: - API experiments

import Observation

@available(iOS 17.0, *)
@available(macOS 14.0, *)
@dynamicMemberLookup
struct ManagedAccessor<T> {
    @Observable
    final class Storage {
        var val: T

        init(val: T) {
            self.val = val
        }
    }

    private let _storage: Storage

    init(_ val: T) {
        self._storage = Storage(val: val)
    }

    subscript<V>(dynamicMember keyPath: WritableKeyPath<T, V>) -> V {
        get { self._storage.val[keyPath: keyPath] }
        mutating set { self._storage.val[keyPath: keyPath] = newValue }
    }
}

@dynamicMemberLookup
struct ManagedGetter<T> {
    let val: T

    subscript<V>(dynamicMember keyPath: KeyPath<T, V>) -> V {
        val[keyPath: keyPath]
    }
}

@available(iOS 17.0, *)
@available(macOS 14.0, *)
protocol ManagedWorkflow: Workflow {
    associatedtype Props = Self

    static func render(
        state: ManagedAccessor<State>,
        props: ManagedGetter<Props>,
        context: RenderContext<Self>
    ) -> Rendering
}

@available(iOS 17.0, *)
@available(macOS 14.0, *)
extension ManagedWorkflow {
    func render(state: State, context: RenderContext<Self>) -> Rendering {
        fatalError("do not implement")
    }
}

@available(iOS 17.0, *)
@available(macOS 14.0, *)
struct MyCoolWF: ManagedWorkflow {
    static func render(
        state: ManagedAccessor<State>,
        props: ManagedGetter<MyCoolWF>,
        context: RenderContext<MyCoolWF>
    ) -> Int {
        let s = state.p1
        return s + 2
    }

    func makeInitialState() -> State {
        State(p1: 27)
    }

    struct State {
        var p1 = 0
    }

    typealias Rendering = Int
}

// MARK: - more experiments

func ggg() {
    let g = ManagedReadonly<String>(value: "hello")
}

private final class Storage<Value: ~Copyable> {
    var value: Value

    init(_ value: consuming Value) {
        self.value = value
    }
}

@dynamicMemberLookup
struct ManagedReadonly<Value: ~Copyable>: ~Copyable {
    private let storage: Storage<Value>

    init(value: consuming Value) {
        self.storage = Storage(value)
    }

    subscript<Property>(dynamicMember keyPath: KeyPath<Value, Property>) -> Property {
        storage.value[keyPath: keyPath]
    }
}

// extension ManagedReadonly where Value: Equatable {
//    static func ==(lhs: borrowing Self, rhs: borrowing Self) -> Bool {
//        lhs.value == rhs.value
//    }
// }

@dynamicMemberLookup
struct ManagedReadwrite<Value: ~Copyable>: ~Copyable {
    private let storage: Storage<Value>

    init(_ value: consuming Value) {
        self.storage = Storage(value)
    }

    subscript<Property>(
        dynamicMember keyPath: WritableKeyPath<Value, Property>
    ) -> Property {
        get { storage.value[keyPath: keyPath] }
        nonmutating set { storage.value[keyPath: keyPath] = newValue }
    }
}

protocol PropsWF: Workflow {
    associatedtype Props = Self

    func render2(
        state: borrowing ManagedReadonly<State>,
        self: borrowing ManagedReadonly<Props>,
        context: RenderContext<Self> // TODO: ctx should also enforce noescape
    ) -> Rendering
}

extension PropsWF {
    func render(state: State, context: RenderContext<Self>) -> Rendering {
        fatalError()
    }
}

func esc(_ it: @escaping () -> Void) {}

protocol WFAction2: WorkflowAction where WorkflowType: PropsWF {
    func apply2(
        to state: borrowing ManagedReadwrite<WorkflowType.State>,
        props: borrowing ManagedReadonly<WorkflowType.Props>
    ) -> WorkflowType.Output?
}

extension WFAction2 {
    func apply(toState state: inout WorkflowType.State) -> WorkflowType.Output? {
        fatalError("should never be called")
    }
}

enum MyAction: WFAction2 {
    typealias WorkflowType = MPWF

    case one
    case two

    func apply2(
        to state: borrowing ManagedReadwrite<MPWF.State>,
        props: borrowing ManagedReadonly<MPWF.Props>
    ) -> Never? {
        switch self {
        case .one:
            state.state1 = 1 + props.prop1
        case .two:
            state.state2 = "two" + " " + props.prop2
        }

//        esc {
//            _ = state
//            _ = props
//        }

        return nil
    }
}

final class SomeRefType {
    var prop = ""
}

struct MPWF: PropsWF {
    struct State {
        var state1 = 0
        var state2 = "bye"
        var refType: SomeRefType?
    }

    class Ref<T: ~Copyable> {
        var ref: T

        init(ref: consuming T) {
            self.ref = ref
        }
    }

    struct Rendering {
        var val = ""
        let ref: Ref<ManagedReadonly<State>?> = .init(ref: nil)
//        var escapingStuff: any Any = (Int?.none as Any)
    }

    struct Props {
        var prop1 = 0
        var prop2 = "hi"
    }

    func render2(
        state: borrowing ManagedReadonly<State>,
        self: borrowing ManagedReadonly<Props>,
        context: RenderContext<MPWF>
    ) -> Rendering {
        var r = Rendering(val: "\(self.prop1) + \(self.prop2)")
//        r.escapingStuff = state
//        r.ref.ref = consume state
        return r
    }

    func makeInitialState() -> State { State() }
}
