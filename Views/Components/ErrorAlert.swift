import SwiftUI

extension View {
    /// An alert shown while `message` is non-nil; dismissing it clears the message.
    func errorAlert(_ title: String = "Something Went Wrong", message: Binding<String?>) -> some View {
        alert(title, isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
