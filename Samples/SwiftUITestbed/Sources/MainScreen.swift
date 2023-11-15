/*
 * Copyright 2023 Square Inc.
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

import MarketUI
import MarketWorkflowUI
import ViewEnvironment
import Workflow
import WorkflowSwiftUIExperimental
import WorkflowUI

struct MainViewModel {
    @WorkflowBinding var title: String

    let didTapPushScreen: () -> Void
    let didTapPresentScreen: () -> Void

    let didTapClose: (() -> Void)?
}


extension MainViewModel: SwiftUIScreen {
    func makeView() -> some View {
        MainView(model: self)
    }
}

struct RootView: View {
    @StateObject
    var rootObject: RootObject

    var body: some View {
        ChildView(title: $rootObject.title)
    }
}

struct ChildView: View {

    init(object, each keyPath)

    @Binding
    var title: String

    @StateObject var childObject: ChildObject

    init(title: Binding<String>) {
        _childObject = ObservedObject(initialValue: ChildObject(title: title))
        childObject.title = title
    }

    var body: some View {
        Group {
            TextField("blah", text: $title)
        }
//        .onChange(of: title, initial: true) {
//            childObject.title = title
//        }
        .onChange(of: childObject.title) {
            title = childObject.title
        }
    }

//    init(rootObject: RootObject) {
//        _childObject = ObservedObject(initialValue: ChildObject(title: ))
//    }
}

extension ObservableObject {

    func binding<Value>(_ keyPath: WritableKeyPath<Self, Value>) -> ObservableBinding<Value> {
        fatalError()
    }
}

private final class WorkflowHostObservedObject: ObservableObject {

    @Published
    var isAllCaps: Bool = false {
        didSet {
            guard isAllCaps != oldValue else { return }
            title = isAllCaps ? title.uppercased() : title.lowercased()
        }
    }

    @Published
    var isAllCapsModificationEnabled: Bool = false

    @Published
    var title: String {
        didSet {
            guard title != oldValue else { return }
            isAllCaps = title.isAllCaps

            titleBinding.wrappedValue = title
        }
    }

    var titleBinding: Binding<String>


    init(title: Binding<String>) {
        Task {
            for await value in title {
                self.title = value
            }
        }
//        self.title = title
    }
}

private extension String {
    var isAllCaps: Bool {
        allSatisfy { character in
            character.isUppercase || !character.isCased
        }
    }
}

struct MainView: View {
    let model: MainViewModel

    enum Field: Hashable {
        case title
    }
    @FocusState var focusedField: Field?

    @StateObject
    private var host: WorkflowHostObservedObject

    @Environment(\.viewEnvironment.marketStylesheet) private var styles: MarketStylesheet
    @Environment(\.viewEnvironment.marketContext) private var context: MarketContext

    init(model: MainViewModel ) {
        self.model = model
        _host = StateObject(wrappedValue: WorkflowHostObservedObject(title: model.title))
    }

    var body: some View {
        ScrollView { VStack {
            Text("Title")
                .font(Font(styles.headers.inlineSection20.heading.text.font))

            TextField(
                "Text",
                text: model.$title
            )
            .focused($focusedField, equals: .title)
            .onAppear { focusedField = .title }

            ToggleRow(
                style: context.stylesheets.testbed.toggleRow,
                label: "All Caps",
                isEnabled: model.allCapsToggleIsEnabled,
                isOn: model.$allCapsToggleIsOn
            )

            Spacer(minLength: styles.spacings.spacing50)

            Text("Navigation")
                .font(Font(styles.headers.inlineSection20.heading.text.font))

            Button(
                "Push Screen",
                action: model.didTapPushScreen
            )

            Button(
                "Present Screen",
                action: model.didTapPresentScreen
            )

            Button(
                "Resign Focus",
                action: { focusedField = nil }
            )

        } }
    }
}

extension MainViewModel: MarketBackStackContentScreen {
    func backStackItem(in environment: ViewEnvironment) -> MarketUI.MarketNavigationItem {
        MarketNavigationItem(
            title: .text(.init(regular: title)),
            backButton: didTapClose.map { .close(onTap: $0) } ?? .automatic()
        )
    }

    var backStackIdentifier: AnyHashable? { nil }
}

#if DEBUG

import SwiftUI

struct MainScreen_Preview: PreviewProvider {
    @State static var title = "New item"
    @State static var allCapsToggleIsOn = false

    static var previews: some View {
        MainViewModel(
            title: WorkflowBinding($title),
            allCapsToggleIsOn: WorkflowBinding($allCapsToggleIsOn),
            allCapsToggleIsEnabled: true,
            didTapPushScreen: {},
            didTapPresentScreen: {},
            didTapClose: {}
        )
        .asMarketBackStack()
        .marketPreview()
    }
}

#endif
