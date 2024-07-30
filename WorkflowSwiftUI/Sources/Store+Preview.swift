#if DEBUG

import Foundation
import Workflow

/// Dummy context for creating no-op sinks and models for static previews of observable screens.
public struct StaticStorePreviewContext {
    fileprivate init() {}

    public func makeSink<Action>(of actionType: Action.Type) -> Sink<Action> {
        Sink { _ in }
    }

    public func makeStateAccessor<State>(state: State) -> StateAccessor<State> {
        StateAccessor(
            state: state,
            sendValue: { _ in }
        )
    }

    public func makeActionModel<State, Action>(
        state: State
    ) -> ActionModel<State, Action> {
        ActionModel(
            accessor: makeStateAccessor(state: state),
            sendAction: makeSink(of: Action.self).send
        )
    }
}

extension Store {
    /// Generates a static store for previews.
    ///
    /// Previews generated with this method are static and do not update state. To generate a
    /// stateful preview, instantiate a workflow and use one of the
    /// ``Workflow/Workflow/workflowPreview(customizeEnvironment:)`` methods.
    ///
    /// - Parameter makeModel: A closure to create the store's model. The provided `context` param
    ///  is a convenience to generate dummy sinks and state accessors.
    /// - Returns: A store for previews.
    public static func preview(
        makeModel: (StaticStorePreviewContext) -> Model
    ) -> Store {
        let context = StaticStorePreviewContext()
        let model = makeModel(context)
        let (store, _) = make(model: model)
        return store
    }
    
    /// Generates a static store for previews.
    ///
    /// Previews generated with this method are static and do not update state. To generate a
    /// stateful preview, instantiate a workflow and use one of the
    /// ``Workflow/Workflow/workflowPreview(customizeEnvironment:)`` methods.
    ///
    /// - Parameter state: The state of the view.
    /// - Returns: A store for previews.
    public static func preview<State, Action>(
        state: State
    ) -> Store<ActionModel<State, Action>> where Model == ActionModel<State, Action> {
        preview { context in
            context.makeActionModel(state: state)
        }
    }
    
    /// Generates a static store for previews.
    ///
    /// Previews generated with this method are static and do not update state. To generate a
    /// stateful preview, instantiate a workflow and use one of the
    /// ``Workflow/Workflow/workflowPreview(customizeEnvironment:)`` methods.
    ///
    /// - Parameter state: The state of the view.
    /// - Returns: A store for previews.
    public static func preview<State>(
        state: State
    ) -> Store<StateAccessor<State>> where Model == StateAccessor<State> {
        preview { context in
            context.makeStateAccessor(state: state)
        }
    }
}

#endif
