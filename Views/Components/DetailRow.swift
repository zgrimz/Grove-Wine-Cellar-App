struct DetailRow: View {
    let label: String
    let value: String?
    
    var body: some View {
        if let value = value {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
        }
    }
}
