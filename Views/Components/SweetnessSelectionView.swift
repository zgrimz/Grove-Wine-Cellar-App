import SwiftUI
import Foundation

struct SweetnessSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSweetness: Set<WineSweetness>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(WineSweetness.allCases, id: \.self) { sweetness in
                    Button(action: {
                        if selectedSweetness.contains(sweetness) {
                            selectedSweetness.remove(sweetness)
                        } else {
                            selectedSweetness.insert(sweetness)
                        }
                    }) {
                        HStack {
                            Text(sweetness.rawValue)
                            Spacer()
                            if selectedSweetness.contains(sweetness) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Sweetness Levels")
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}