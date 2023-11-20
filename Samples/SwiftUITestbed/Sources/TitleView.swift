//
//  TitleView.swift
//  Development-SwiftUITestbed
//
//  Created by Tom Brow on 11/16/23.
//

import SwiftUI
import Workflow
import WorkflowSwiftUI

struct TitleWorkflow: Workflow {
    @WorkflowBinding
    var title: String

    struct State {
        @WorkflowBinding
        var title: String

        var allCapsToggleIsOn: Bool

        var allCapsToggleIsEnabled: Bool {
            title.isEmpty == false
        }

        mutating func update(title: WorkflowBinding<String>) {
            _title = title
        }
    }

    struct Rendering {
        @WorkflowBinding
        var title: String

        @WorkflowBinding
        var allCapsToggleIsOn: Bool

        let allCapsToggleIsEnabled: Bool
    }

    typealias Output = Never

    enum Action: WorkflowAction {
        typealias WorkflowType = TitleWorkflow

        case setAllCaps(isOn: Bool)
        case setTitle(String)

        func apply(toState state: inout State) -> Output? {
            switch self {
            case .setAllCaps(let isOn):
                state.allCapsToggleIsOn = isOn
                state.title = isOn ? state.title.uppercased() : state.title.lowercased()

            case .setTitle(let title):
                state.title = title
                state.allCapsToggleIsOn = title.isAllCaps
            }
            return nil
        }
    }

    func makeInitialState() -> State {
        .init(
            title: _title,
            allCapsToggleIsOn: title.isAllCaps
        )
    }

    func workflowDidChange(from previousWorkflow: TitleWorkflow, state: inout State) {
        state.update(title: _title)
        state.allCapsToggleIsOn = title.isAllCaps
    }

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        .init(
            title: context.makeBinding(
                get: \.title,
                set: Action.setTitle
            ),
            allCapsToggleIsOn: context.makeBinding(
                get: \.allCapsToggleIsOn,
                set: Action.setAllCaps(isOn:)
            ),
            allCapsToggleIsEnabled: state.allCapsToggleIsEnabled
        )
    }
}

private extension String {
    var isAllCaps: Bool {
        allSatisfy { character in
            character.isUppercase || !character.isCased
        }
    }
}

struct TitleView: View {
    @Binding
    var title: String

    enum Field: Hashable {
        case title
    }

    @FocusState var focusedField: Field?

    @Environment(\.viewEnvironment.stylesheets.testbed)
    private var styles: TestbedStylesheet

    var body: some View {
        _ = Self._printChanges()
        WorkflowView(workflow: TitleWorkflow(title: WorkflowBinding($title))) { model in
            VStack {
                TextField(
                    "Text",
                    text: model.$title
                )
                .focused($focusedField, equals: .title)
                .onAppear { focusedField = .title }

                ToggleRow(
                    style: styles.toggleRow,
                    label: "All Caps",
                    isEnabled: model.allCapsToggleIsEnabled,
                    isOn: model.$allCapsToggleIsOn
                )

                Button(
                    "Resign Focus",
                    action: { focusedField = nil }
                )
            }
        }
    }
}
