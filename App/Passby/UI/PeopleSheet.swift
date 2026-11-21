import PassbyCore
import SwiftUI

/// Everyone you have passed, most recent first.
struct PeopleSheet: View {
    @Environment(AppModel.self) private var model
    let onSelect: (UUID) -> Void
    let onClose: () -> Void

    private var people: [Encounter] {
        model.state.encounters.sorted { $0.lastMet > $1.lastMet }
    }

    var body: some View {
        BottomSheet(title: title, onClose: onClose) {
            if people.isEmpty {
                Text("Nobody yet. Walk past someone who has Passby and they will show up here.")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.soft)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(people) { person in
                            Button { onSelect(person.id) } label: { row(person) }
                                .buttonStyle(.plain)
                            Divider().overlay(Theme.line)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var title: String {
        switch people.count {
        case 0: "People you passed"
        case 1: "1 person you passed"
        default: "\(people.count) people you passed"
        }
    }

    private func row(_ person: Encounter) -> some View {
        HStack(spacing: 12) {
            CharacterView(look: person.profile.look, crop: .head)
                .frame(width: 44, height: 44)
                .background(Theme.fill, in: Circle())
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(person.profile.name)
                    .font(Theme.font(15.5, .bold))
                    .lineLimit(1)
                Text(person.waiting ? "Waiting to meet you" : person.timesLine)
                    .font(Theme.font(12.5))
                    .foregroundStyle(person.waiting ? Theme.greenDark : Theme.soft)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: 0xB9C2CA))
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}
