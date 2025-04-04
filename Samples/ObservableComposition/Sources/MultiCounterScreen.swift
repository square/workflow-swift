import Foundation
import Perception
import SwiftUI
import ViewEnvironment
import Workflow
import WorkflowSwiftUI

struct MultiCounterScreen: ObservableScreen {
    let model: MultiCounterModel

    static func makeView(store: Store<MultiCounterModel>) -> some View {
        MultiCounterView(store: store)
    }
}
