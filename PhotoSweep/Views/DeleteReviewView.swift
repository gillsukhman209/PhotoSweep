import Photos
import StoreKit
import SwiftUI

struct DeleteReviewView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("PhotoSweep.hasRequestedReviewAfterFirstDelete") private var hasRequestedReviewAfterFirstDelete = false
    @State private var showDeleteConfirmation = false
    private let deleteColor = Color(red: 1.0, green: 0.32, blue: 0.36)

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : Color(uiColor: .systemGroupedBackground)
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 0.07, green: 0.08, blue: 0.10)
    }

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.62) : Color(red: 0.36, green: 0.38, blue: 0.44)
    }

    private let columns = [
        GridItem(.adaptive(minimum: 104), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if library.queuedDeleteAssets.isEmpty {
                    ContentUnavailableView(
                        "Nothing Marked",
                        systemImage: "checkmark.circle",
                        description: Text("Swipe left on photos to mark them for deletion.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(library.deleteCount) marked photo\(library.deleteCount == 1 ? "" : "s")")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(primaryText)

                            Text("These are not deleted yet. Remove anything you want to keep, then delete the rest.")
                                .font(.subheadline)
                                .foregroundStyle(secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(library.queuedDeleteAssets, id: \.localIdentifier) { asset in
                                deleteTile(asset)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(backgroundColor)
            .navigationTitle("Review Deletes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !library.queuedDeleteAssets.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete \(library.deleteCount) Photo\(library.deleteCount == 1 ? "" : "s")", systemImage: "trash.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(library.isDeleting)
                    }
                    .padding(16)
                    .background(.regularMaterial)
                }
            }
            .confirmationDialog(
                "Delete marked photos?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(library.deleteCount) Item\(library.deleteCount == 1 ? "" : "s")", role: .destructive) {
                    Task {
                        let didDelete = await library.deleteQueuedAssets()
                        if didDelete && !hasRequestedReviewAfterFirstDelete {
                            hasRequestedReviewAfterFirstDelete = true
                            requestReview()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("CleanRoll cannot bypass the iOS confirmation. You can still recover deleted items from Recently Deleted for 30 days.")
            }
        }
    }

    private func deleteTile(_ asset: PHAsset) -> some View {
        ZStack(alignment: .topTrailing) {
            AssetImageView(asset: asset, contentMode: .fill, quality: .thumbnail)
                .frame(height: 124)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                library.removeFromDeleteQueue(asset)
            } label: {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color(red: 0.08, green: 0.56, blue: 0.36), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel("Keep this photo")
        }
    }
}
