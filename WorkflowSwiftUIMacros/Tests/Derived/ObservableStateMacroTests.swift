// Derived from
// https://github.com/pointfreeco/swift-composable-architecture/blob/1.12.1/Tests/ComposableArchitectureMacrosTests/ObservableStateMacroTests.swift

// If running this test in Xcode, set the run destination to "My Mac", or you'll get:
// > No such module 'WorkflowSwiftUIMacros'
// See https://forums.swift.org/t/xcode-15-beta-no-such-module-error-with-swiftpm-and-macro/65486

/*
 import MacroTesting
 import WorkflowSwiftUIMacros
 import XCTest

 final class ObservableStateMacroTests: XCTestCase {
     override func invokeTest() {
         withMacroTesting(
             // isRecording: true,
             macros: [
                 ObservableStateMacro.self,
                 ObservationStateIgnoredMacro.self,
                 ObservationStateTrackedMacro.self,
             ]
         ) {
             super.invokeTest()
         }
     }

     func testAvailability() {
         assertMacro {
             """
             @ObservableState
             @available(iOS 18, *)
             struct State {
                 var count = 0
             }
             """
         } expansion: {
             #"""
             @available(iOS 18, *)
             struct State {
                 var count {
                     @storageRestrictions(initializes: _count)
                     init(initialValue) {
                         _count = initialValue
                     }
                     get {
                         _$observationRegistrar.access(self, keyPath: \.count)
                         return _count
                     }
                     set {
                         _$observationRegistrar.mutate(self, keyPath: \.count, &_count, newValue, _$isIdentityEqual)
                     }
                     _modify {
                       let oldValue = _$observationRegistrar.willModify(self, keyPath: \.count, &_count)
                       defer {
                         _$observationRegistrar.didModify(self, keyPath: \.count, &_count, oldValue, _$isIdentityEqual)
                       }
                       yield &_count
                     }
                 }

                 var _$observationRegistrar = WorkflowSwiftUI.ObservationStateRegistrar()

                 public var _$id: WorkflowSwiftUI.ObservableStateID {
                     _$observationRegistrar.id
                 }

                 public mutating func _$willModify() {
                     _$observationRegistrar._$willModify()
                 }
             }
             """#
         }
     }

     func testObservableState() throws {
         assertMacro {
             #"""
             @ObservableState
             struct State {
                 var count = 0
             }
             """#
         } expansion: {
             #"""
             struct State {
                 var count {
                     @storageRestrictions(initializes: _count)
                     init(initialValue) {
                         _count = initialValue
                     }
                     get {
                         _$observationRegistrar.access(self, keyPath: \.count)
                         return _count
                     }
                     set {
                         _$observationRegistrar.mutate(self, keyPath: \.count, &_count, newValue, _$isIdentityEqual)
                     }
                     _modify {
                       let oldValue = _$observationRegistrar.willModify(self, keyPath: \.count, &_count)
                       defer {
                         _$observationRegistrar.didModify(self, keyPath: \.count, &_count, oldValue, _$isIdentityEqual)
                       }
                       yield &_count
                     }
                 }

                 var _$observationRegistrar = WorkflowSwiftUI.ObservationStateRegistrar()

                 public var _$id: WorkflowSwiftUI.ObservableStateID {
                     _$observationRegistrar.id
                 }

                 public mutating func _$willModify() {
                     _$observationRegistrar._$willModify()
                 }
             }
             """#
         }
     }

     func testObservableState_AccessControl() throws {
         assertMacro {
             #"""
             @ObservableState
             public struct State {
                 var count = 0
             }
             """#
         } expansion: {
             #"""
             public struct State {
                 var count {
                     @storageRestrictions(initializes: _count)
                     init(initialValue) {
                         _count = initialValue
                     }
                     get {
                         _$observationRegistrar.access(self, keyPath: \.count)
                         return _count
                     }
                     set {
                         _$observationRegistrar.mutate(self, keyPath: \.count, &_count, newValue, _$isIdentityEqual)
                     }
                     _modify {
                       let oldValue = _$observationRegistrar.willModify(self, keyPath: \.count, &_count)
                       defer {
                         _$observationRegistrar.didModify(self, keyPath: \.count, &_count, oldValue, _$isIdentityEqual)
                       }
                       yield &_count
                     }
                 }

                 var _$observationRegistrar = WorkflowSwiftUI.ObservationStateRegistrar()

                 public var _$id: WorkflowSwiftUI.ObservableStateID {
                     _$observationRegistrar.id
                 }

                 public mutating func _$willModify() {
                     _$observationRegistrar._$willModify()
                 }
             }
             """#
         }
         assertMacro {
             #"""
             @ObservableState
             package struct State {
                 var count = 0
             }
             """#
         } expansion: {
             #"""
             package struct State {
                 var count {
                     @storageRestrictions(initializes: _count)
                     init(initialValue) {
                         _count = initialValue
                     }
                     get {
                         _$observationRegistrar.access(self, keyPath: \.count)
                         return _count
                     }
                     set {
                         _$observationRegistrar.mutate(self, keyPath: \.count, &_count, newValue, _$isIdentityEqual)
                     }
                     _modify {
                       let oldValue = _$observationRegistrar.willModify(self, keyPath: \.count, &_count)
                       defer {
                         _$observationRegistrar.didModify(self, keyPath: \.count, &_count, oldValue, _$isIdentityEqual)
                       }
                       yield &_count
                     }
                 }

                 var _$observationRegistrar = WorkflowSwiftUI.ObservationStateRegistrar()

                 public var _$id: WorkflowSwiftUI.ObservableStateID {
                     _$observationRegistrar.id
                 }

                 public mutating func _$willModify() {
                     _$observationRegistrar._$willModify()
                 }
             }
             """#
         }
     }

     func testObservableStateIgnored() throws {
         assertMacro {
             #"""
             @ObservableState
             struct State {
                 @ObservationStateIgnored
                 var count = 0
             }
             """#
         } expansion: {
             """
             struct State {
                 var count = 0

                 var _$observationRegistrar = WorkflowSwiftUI.ObservationStateRegistrar()

                 public var _$id: WorkflowSwiftUI.ObservableStateID {
                     _$observationRegistrar.id
                 }

                 public mutating func _$willModify() {
                     _$observationRegistrar._$willModify()
                 }
             }
             """
         }
     }

     func testObservableState_Enum() {
         assertMacro {
             """
             @ObservableState
             enum Path {
                 case feature1(Feature1.State)
                 case feature2(Feature2.State)
             }
             """
         } expansion: {
             """
             enum Path {
                 case feature1(Feature1.State)
                 case feature2(Feature2.State)

                 public var _$id: WorkflowSwiftUI.ObservableStateID {
                     switch self {
                     case let .feature1(state):
                         return ._$id(for: state)._$tag(0)
                     case let .feature2(state):
                         return ._$id(for: state)._$tag(1)
                     }
                 }

                 public mutating func _$willModify() {
                     switch self {
                     case var .feature1(state):
                         WorkflowSwiftUI._$willModify(&state)
                         self = .feature1(state)
                     case var .feature2(state):
                         WorkflowSwiftUI._$willModify(&state)
                         self = .feature2(state)
                     }
                 }
             }
             """
         }
     }

     func testObservableState_Enum_Label() {
         assertMacro {
             """
             @ObservableState
             enum Path {
                 case feature1(state: String)
             }
             """
         } expansion: {
             """
             enum Path {
                 case feature1(state: String)

                 public var _$id: WorkflowSwiftUI.ObservableStateID {
                     switch self {
                     case let .feature1(state):
                         return ._$id(for: state)._$tag(0)
                     }
                 }

                 public mutating func _$willModify() {
                     switch self {
                     case var .feature1(state):
                         WorkflowSwiftUI._$willModify(&state)
                         self = .feature1(state: state)
                     }
                 }
             }
             """
         }
     }

     func testObservableState_Enum_AccessControl() {
         assertMacro {
             """
             @ObservableState
             public enum Path {
                 case feature1(Feature1.State)
                 case feature2(Feature2.State)
             }
             """
         } expansion: {
             """
             public enum Path {
                 case feature1(Feature1.State)
                 case feature2(Feature2.State)

                 public var _$id: WorkflowSwiftUI.ObservableStateID {
                     switch self {
                     case let .feature1(state):
                         return ._$id(for: state)._$tag(0)
                     case let .feature2(state):
                         return ._$id(for: state)._$tag(1)
                     }
                 }

                 public mutating func _$willModify() {
                     switch self {
                     case var .feature1(state):
                         WorkflowSwiftUI._$willModify(&state)
                         self = .feature1(state)
                     case var .feature2(state):
                         WorkflowSwiftUI._$willModify(&state)
                         self = .feature2(state)
                     }
                 }
             }
             """
         }
         assertMacro {
             """
             @ObservableState
             package enum Path {
                 case feature1(Feature1.State)
                 case feature2(Feature2.State)
             }
             """
         } expansion: {
             """
             package enum Path {
                 case feature1(Feature1.State)
                 case feature2(Feature2.State)

                 public var _$id: WorkflowSwiftUI.ObservableStateID {
                     switch self {
                     case let .feature1(state):
                         return ._$id(for: state)._$tag(0)
                     case let .feature2(state):
                         return ._$id(for: state)._$tag(1)
                     }
                 }

                 public mutating func _$willModify() {
                     switch self {
                     case var .feature1(state):
                         WorkflowSwiftUI._$willModify(&state)
                         self = .feature1(state)
                     case var .feature2(state):
                         WorkflowSwiftUI._$willModify(&state)
                         self = .feature2(state)
                     }
                 }
             }
             """
         }
     }

     func testObservableState_Enum_AccessControl_WrappedByExtension() {
         assertMacro {
             """
             public extension Feature {
                 @ObservableState
                 enum Path {
                     case feature1(Feature1.State)
                     case feature2(Feature2.State)
                 }
             }
             """
         } expansion: {
             """
             public extension Feature {
                 enum Path {
                     case feature1(Feature1.State)
                     case feature2(Feature2.State)

                     public var _$id: WorkflowSwiftUI.ObservableStateID {
                         switch self {
                         case let .feature1(state):
                             return ._$id(for: state)._$tag(0)
                         case let .feature2(state):
                             return ._$id(for: state)._$tag(1)
                         }
                     }

                     public mutating func _$willModify() {
                         switch self {
                         case var .feature1(state):
                             WorkflowSwiftUI._$willModify(&state)
                             self = .feature1(state)
                         case var .feature2(state):
                             WorkflowSwiftUI._$willModify(&state)
                             self = .feature2(state)
                         }
                     }
                 }
             }
             """
         }
         assertMacro {
             """
             public extension Feature {
                 @ObservableState
                 package enum Path {
                     case feature1(Feature1.State)
                     case feature2(Feature2.State)
                 }
             }
             """
         } expansion: {
             """
             public extension Feature {
                 package enum Path {
                     case feature1(Feature1.State)
                     case feature2(Feature2.State)

                     public var _$id: WorkflowSwiftUI.ObservableStateID {
                         switch self {
                         case let .feature1(state):
                             return ._$id(for: state)._$tag(0)
                         case let .feature2(state):
                             return ._$id(for: state)._$tag(1)
                         }
                     }

                     public mutating func _$willModify() {
                         switch self {
                         case var .feature1(state):
                             WorkflowSwiftUI._$willModify(&state)
                             self = .feature1(state)
                         case var .feature2(state):
                             WorkflowSwiftUI._$willModify(&state)
                             self = .feature2(state)
                         }
                     }
                 }
             }
             """
         }
     }

     func testObservableState_Enum_NonObservableCase() {
         assertMacro {
             """
             @ObservableState
             public enum Path {
                 case foo(Int)
             }
             """
         } expansion: {
             """
             public enum Path {
                 case foo(Int)

                 public var _$id: WorkflowSwiftUI.ObservableStateID {
                     switch self {
                     case let .foo(state):
                         return ._$id(for: state)._$tag(0)
                     }
                 }

                 public mutating func _$willModify() {
                     switch self {
                     case var .foo(state):
                         WorkflowSwiftUI._$willModify(&state)
                         self = .foo(state)
                     }
                 }
             }
             """
         }
     }

     func testObservableState_Enum_MultipleAssociatedValues() {
         assertMacro {
             """
             @ObservableState
             public enum Path {
                 case foo(Int, String)
             }
             """
         } expansion: {
             """
             public enum Path {
                 case foo(Int, String)

                 public var _$id: WorkflowSwiftUI.ObservableStateID {
                     switch self {
                     case .foo:
                         return ObservableStateID()._$tag(0)
                     }
                 }

                 public mutating func _$willModify() {
                     switch self {
                     case .foo:
                         break
                     }
                 }
             }
             """
         }
     }

     func testObservableState_Class() {
         assertMacro {
             """
             @ObservableState
             public class Model {
             }
             """
         } diagnostics: {
             """
             @ObservableState
             ┬───────────────
             ╰─ 🛑 '@ObservableState' cannot be applied to class type 'Model'
             public class Model {
             }
             """
         }
     }

     func testObservableState_Actor() {
         assertMacro {
             """
             @ObservableState
             public actor Model {
             }
             """
         } diagnostics: {
             """
             @ObservableState
             ┬───────────────
             ╰─ 🛑 '@ObservableState' cannot be applied to actor type 'Model'
             public actor Model {
             }
             """
         }
     }

     func testObservableState_Enum_IfConfig() {
         assertMacro {
             """
             @ObservableState
             public enum State {
                 case child(ChildFeature.State)
                 #if os(macOS)
                     case mac(MacFeature.State)
                 #elseif os(tvOS)
                     case tv(TVFeature.State)
                 #endif

                 #if DEBUG
                     #if INNER
                         case inner(InnerFeature.State)
                     #endif
                 #endif
             }
             """
         } expansion: {
             """
             public enum State {
                 case child(ChildFeature.State)
                 #if os(macOS)
                     case mac(MacFeature.State)
                 #elseif os(tvOS)
                     case tv(TVFeature.State)
                 #endif

                 #if DEBUG
                     #if INNER
                         case inner(InnerFeature.State)
                     #endif
                 #endif

                 public var _$id: WorkflowSwiftUI.ObservableStateID {
                     switch self {
                     case let .child(state):
                         return ._$id(for: state)._$tag(0)
                     #if os(macOS)
                     case let .mac(state):
                         return ._$id(for: state)._$tag(1)
                     #elseif os(tvOS)
                     case let .tv(state):
                         return ._$id(for: state)._$tag(2)
                     #endif

                     #if DEBUG
                     #if INNER
                     case let .inner(state):
                         return ._$id(for: state)._$tag(3)
                     #endif
                     #endif

                     }
                 }

                 public mutating func _$willModify() {
                     switch self {
                     case var .child(state):
                         WorkflowSwiftUI._$willModify(&state)
                         self = .child(state)
                     #if os(macOS)
                     case var .mac(state):
                         WorkflowSwiftUI._$willModify(&state)
                         self = .mac(state)
                     #elseif os(tvOS)
                     case var .tv(state):
                         WorkflowSwiftUI._$willModify(&state)
                         self = .tv(state)
                     #endif

                     #if DEBUG
                     #if INNER
                     case var .inner(state):
                         WorkflowSwiftUI._$willModify(&state)
                         self = .inner(state)
                     #endif
                     #endif

                     }
                 }
             }
             """
         }
     }
 }
 */
