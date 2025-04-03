import SwiftUI

struct SimpleCounterView: View {
    @Binding
    var count: Int

    var body: some View {
        let _ = print("SimpleCounterView.body")
        HStack {
            Button {
                count -= 1
            } label: {
                Image(systemName: "minus")
            }

            Text("\(count)")
                .monospacedDigit()

            Button {
                count += 1
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}
