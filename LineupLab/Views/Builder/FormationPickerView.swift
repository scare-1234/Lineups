import SwiftUI

/// Grid of formations, each with a mini-pitch preview.
struct FormationPickerView: View {
    let selected: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(FormationParser.supported) { formation in
                        FormationTile(
                            formation: formation,
                            isSelected: formation.name == selected
                        ) {
                            Haptics.impact(.light)
                            onSelect(formation.name)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .background(Theme.Palette.background)
            .navigationTitle(L10n.Builder.chooseFormation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
            }
        }
    }
}

struct FormationTile: View {
    let formation: Formation
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                FormationMiniPitch(formation: formation)
                Text(formation.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.primaryText)
            }
            .padding(10)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                    .strokeBorder(isSelected ? Theme.Palette.accent : Theme.Palette.separator, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(formation.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Compact horizontal formation switcher used at the top of the builder.
struct FormationStrip: View {
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FormationParser.supportedNames, id: \.self) { name in
                    FilterChip(title: name, isSelected: name == selected) {
                        onSelect(name)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview("Formations") {
    FormationPickerView(selected: "4-3-3") { _ in }
}
