import Photos
import SwiftUI

struct DateJumpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedDate = Date()

    private let keepColor = Color(red: 0.18, green: 0.78, blue: 0.49)

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : Color(uiColor: .systemGroupedBackground)
    }

    private var cardColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.07) : Color.white
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 0.07, green: 0.08, blue: 0.10)
    }

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.52) : Color(red: 0.36, green: 0.38, blue: 0.44)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    datePickerSection
                    monthSection
                }
                .padding(18)
            }
            .background(backgroundColor)
            .navigationTitle("Jump to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedDate = defaultSelectedDate
            }
        }
    }

    @ViewBuilder
    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick a day")
                .font(.headline.weight(.bold))
                .foregroundStyle(primaryText)

            if let range = library.dateJumpRange {
                DatePicker(
                    "Review date",
                    selection: boundedSelection(in: range),
                    in: range,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(keepColor)
                .padding(8)
                .background(cardColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button {
                    library.jumpToDate(clamped(selectedDate, to: range))
                    dismiss()
                } label: {
                    Label("Jump to \(clamped(selectedDate, to: range).formatted(.dateTime.month(.abbreviated).day().year()))", systemImage: "arrow.down.forward.circle.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(keepColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                emptyState
            }
        }
    }

    @ViewBuilder
    private var monthSection: some View {
        let months = library.reviewMonths

        if !months.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Months")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(primaryText)

                LazyVStack(spacing: 10) {
                    ForEach(months) { month in
                        Button {
                            library.jumpToMonth(month)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(keepColor)
                                    .frame(width: 38, height: 38)
                                    .background(keepColor.opacity(0.14), in: Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(month.title)
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(primaryText)

                                    Text(month.subtitle)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(secondaryText)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(secondaryText.opacity(0.72))
                            }
                            .padding(14)
                            .background(cardColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Dates Yet", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("Load your library or pick another filter before jumping by date.")
        }
        .foregroundStyle(primaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var defaultSelectedDate: Date {
        if let currentDate = library.currentAsset?.creationDate {
            return currentDate
        }

        if let latestDate = library.dateJumpRange?.upperBound {
            return latestDate
        }

        return Date()
    }

    private func boundedSelection(in range: ClosedRange<Date>) -> Binding<Date> {
        Binding {
            clamped(selectedDate, to: range)
        } set: { newDate in
            selectedDate = clamped(newDate, to: range)
        }
    }

    private func clamped(_ date: Date, to range: ClosedRange<Date>) -> Date {
        min(max(date, range.lowerBound), range.upperBound)
    }
}

#Preview {
    DateJumpView()
        .environmentObject(PhotoLibraryStore())
}
