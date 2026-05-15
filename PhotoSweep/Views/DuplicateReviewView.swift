import Photos
import SwiftUI

struct DuplicateReviewView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss

    private let keepColor = Color(red: 0.18, green: 0.78, blue: 0.49)
    private let deleteColor = Color(red: 1.0, green: 0.32, blue: 0.36)

    var body: some View {
        NavigationStack {
            Group {
                if library.isScanningDuplicates && library.duplicateGroups.isEmpty {
                    scanningView
                } else if library.duplicateGroups.isEmpty {
                    emptyView
                } else {
                    groupsView
                }
            }
            .background(Color.black)
            .navigationTitle("Duplicates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !library.duplicateGroups.isEmpty {
                        Button("Delete Copies") {
                            library.markAllDuplicateExtrasForDeletion()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(deleteColor)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var scanningView: some View {
        VStack(spacing: 18) {
            Spacer()

            ProgressView(value: library.duplicateScanProgress)
                .tint(keepColor)
                .frame(width: 220)

            Text("Finding duplicates")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text("Results will appear as soon as PhotoSweep finds each matching set.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Label("Keep Swiping", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(keepColor)
            .padding(.top, 8)

            Spacer()
        }
        .padding(24)
    }

    private var emptyView: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "square.on.square")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(keepColor)

            Text("Find duplicate photos")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("For every duplicate set, you keep one photo and send the extra copies to Review Deletes.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)

            Button {
                library.startDuplicateScan()
                dismiss()
            } label: {
                Label("Start Background Scan", systemImage: "sparkle.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(keepColor)
            .padding(.top, 8)

            Text("You can keep swiping while PhotoSweep scans.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))

            Spacer()
        }
        .padding(24)
    }

    private var groupsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(library.duplicateGroups.count) duplicate set\(library.duplicateGroups.count == 1 ? "" : "s")")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Keep one. Delete the extra copies. Nothing is deleted until Review Deletes.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                if library.isScanningDuplicates {
                    scanningResultsBanner
                }

                ForEach(library.duplicateGroups) { group in
                    duplicateGroupCard(group)
                }
            }
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                library.markAllDuplicateExtrasForDeletion()
            } label: {
                Label("Delete All Extra Copies", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(deleteColor)
            .padding(16)
            .background(.black.opacity(0.86))
        }
    }

    private var scanningResultsBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Still scanning")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(Int(library.duplicateScanProgress * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.68))
            }

            ProgressView(value: library.duplicateScanProgress)
                .tint(keepColor)
        }
        .padding(14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func duplicateGroupCard(_ group: DuplicateGroup) -> some View {
        let isQueued = group.duplicates.allSatisfy { asset in
            library.decisions[asset.localIdentifier] == .delete
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("\(group.assets.count) copies found")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    library.markDuplicateExtrasForDeletion(in: group)
                } label: {
                    Text(isQueued ? "Ready" : "Delete copies")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isQueued ? keepColor : deleteColor)
                }
                .disabled(isQueued)
            }

            HStack(spacing: 10) {
                duplicateTile(group.keeper, label: "Keep this", color: keepColor)
                    .frame(maxWidth: .infinity)

                ForEach(group.duplicates.prefix(2), id: \.localIdentifier) { asset in
                    duplicateTile(asset, label: "Delete copy", color: deleteColor)
                        .frame(maxWidth: .infinity)
                }
            }

            if group.duplicates.count > 2 {
                Text("+\(group.duplicates.count - 2) more duplicate\(group.duplicates.count - 2 == 1 ? "" : "s") will be deleted")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    private func duplicateTile(_ asset: PHAsset, label: String, color: Color) -> some View {
        ZStack(alignment: .topLeading) {
            AssetImageView(asset: asset, contentMode: .fill, quality: .thumbnail)
                .frame(height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(label)
                .font(.caption.weight(.black))
                .foregroundStyle(label == "Keep this" ? .black : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(color, in: Capsule())
                .padding(7)
        }
    }
}
