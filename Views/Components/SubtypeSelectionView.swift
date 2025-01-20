import SwiftUI

struct SubtypeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSubtypes: Set<WineSubType>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(WineSubType.allCases, id: \.self) { subtype in
                    Button(action: {
                        if selectedSubtypes.contains(subtype) {
                            selectedSubtypes.remove(subtype)
                        } else {
                            selectedSubtypes.insert(subtype)
                        }
                    }) {
                        HStack {
                            Text(subtype.rawValue)
                            Spacer()
                            if selectedSubtypes.contains(subtype) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Wine Subtypes")
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}
