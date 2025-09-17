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

#if DEBUG
import IssueReporting
#endif

public struct WorkflowUpdateDebugInfo: Codable, Equatable {
    public var workflowType: String
    public var kind: Kind

    init(workflowType: String, kind: Kind) {
        self.workflowType = workflowType
        self.kind = kind
    }
}

extension WorkflowUpdateDebugInfo {
    public indirect enum Kind: Equatable {
        case didUpdate(source: Source)
        case childDidUpdate(WorkflowUpdateDebugInfo)
    }
}

extension WorkflowUpdateDebugInfo.Kind: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case source
        case childUpdate
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .didUpdate(let source):
            try container.encode("didUpdate", forKey: .type)
            try container.encode(source, forKey: .source)
        case .childDidUpdate(let info):
            try container.encode("childDidUpdate", forKey: .type)
            try container.encode(info, forKey: .childUpdate)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        struct MalformedDataError: Error {}

        let typeString = try container.decode(String.self, forKey: .type)

        switch typeString {
        case "didUpdate":
            let source = try container.decode(WorkflowUpdateDebugInfo.Source.self, forKey: .source)
            self = .didUpdate(source: source)
        case "childDidUpdate":
            let childUpdate = try container.decode(WorkflowUpdateDebugInfo.self, forKey: .childUpdate)
            self = .childDidUpdate(childUpdate)
        default:
            throw MalformedDataError()
        }
    }
}

extension WorkflowUpdateDebugInfo {
    public indirect enum Source: Equatable {
        case external
        case worker
        case sideEffect
        case subtree(WorkflowUpdateDebugInfo)
    }
}

extension WorkflowUpdateDebugInfo.Source: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case debugInfo
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .external:
            try container.encode("external", forKey: .type)
        case .worker:
            try container.encode("worker", forKey: .type)
        case .subtree(let debugInfo):
            try container.encode("subtree", forKey: .type)
            try container.encode(debugInfo, forKey: .debugInfo)
        case .sideEffect:
            try container.encode("side-effect", forKey: .type)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        struct MalformedDataError: Error {}

        let typeString = try container.decode(String.self, forKey: .type)

        switch typeString {
        case "external":
            self = .external
        case "worker":
            self = .worker
        case "subtree":
            let debugInfo = try container.decode(WorkflowUpdateDebugInfo.self, forKey: .debugInfo)
            self = .subtree(debugInfo)
        case "side-effect":
            self = .sideEffect
        default:
            throw MalformedDataError()
        }
    }
}

public struct WorkflowHierarchyDebugSnapshot: Codable, Equatable {
    public var workflowType: String
    public var stateDescription: String
    public var children: [Child]

    init(workflowType: String, stateDescription: String, children: [Child] = []) {
        self.workflowType = workflowType
        self.stateDescription = stateDescription
        self.children = children
    }
}

extension WorkflowHierarchyDebugSnapshot {
    public struct Child: Codable, Equatable {
        public var key: String
        public var snapshot: WorkflowHierarchyDebugSnapshot

        init(key: String, snapshot: WorkflowHierarchyDebugSnapshot) {
            self.key = key
            self.snapshot = snapshot
        }
    }
}

// MARK: - Compatibility

/// These extensions are utilities to support conditionally emitting debug info only when a
/// `debugger` is set.
extension WorkflowUpdateDebugInfo? {
    var unwrappedOrErrorDefault: WorkflowUpdateDebugInfo {
        self ?? .unexpectedlyMissing
    }
}

extension WorkflowUpdateDebugInfo {
    fileprivate static let unexpectedlyMissing = {
        assertionFailure("Creation of actual WorkflowUpdateDebugInfo failed unexpectedly")
        return WorkflowUpdateDebugInfo(
            workflowType: "BUG IN WORKFLOW",
            kind: .didUpdate(source: .external)
        )
    }()
}

// MARK: - Runtime Debugging Utilities

#if DEBUG
/// Debug facility that checks if an instance of a reference type may have 'escaped' from a function.
/// - Parameters:
///   - object: The instance to test.
///   - message: The message to log if not uniquely referenced. The ObjectIdentifier of the instance will be supplied as an argument.
///
/// If the instance is **not** known to be uniquely referenced it will:
///   - Trigger a test failure if running in a testing context.
///   - Cause an assertion failure otherwise.
func diagnoseEscapedReference(
    to object: consuming some AnyObject,
    _ message: (ObjectIdentifier) -> String
) {
    var maybeUniqueReference = consume object
    if !isKnownUniquelyReferenced(&maybeUniqueReference) {
        if let _ = TestContext.current {
            reportIssue(message(ObjectIdentifier(maybeUniqueReference)))
        } else {
            assertionFailure(message(ObjectIdentifier(maybeUniqueReference)))
        }
    }
    _ = consume maybeUniqueReference
}
#endif
