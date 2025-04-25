#if swift(>=5.9)
import Observation

/// Defines and implements conformance of the Observable protocol.
@attached(extension, conformances: Observable, ObservableState)
@attached(
    member,
    names: named(_$id),
    named(_$observationRegistrar),
    named(_$workflowRegistrar),
    named(_$willModify)
)
@attached(memberAttribute)
public macro ObservableState() =
    #externalMacro(module: "WorkflowSwiftUIMacros", type: "ObservableStateMacro")

@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(_))
public macro ObservationStateTracked() =
    #externalMacro(module: "WorkflowSwiftUIMacros", type: "ObservationStateTrackedMacro")

@attached(accessor, names: named(willSet))
public macro ObservationStateIgnored() =
    #externalMacro(module: "WorkflowSwiftUIMacros", type: "ObservationStateIgnoredMacro")

#endif
