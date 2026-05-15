import Photos
import SwiftUI

struct DeleteReviewView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    private let deleteColor = Color(red: 1.0, green: 0.32, blue: 0.36)
    private let inkColor = Color.white

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
                                .foregroundStyle(inkColor)

                            Text("These are not deleted yet. Remove anything you want to keep, then ask iOS to delete the rest.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.62))
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
            .background(Color.black)
            .navigationTitle("Review Deletes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        if library.isDeleting {
                            ProgressView()
                        } else {
                            Text("Delete")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(library.queuedDeleteAssets.isEmpty || library.isDeleting)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !library.queuedDeleteAssets.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("iOS will show one final confirmation. Deleted photos move to Recently Deleted first.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.64))

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Ask iOS to Delete \(library.deleteCount)", systemImage: "checkmark.shield.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(library.isDeleting)
                    }
                    .padding(16)
                    .background(.black.opacity(0.82))
                }
            }
            .confirmationDialog(
                "Delete marked photos?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(library.deleteCount) Item\(library.deleteCount == 1 ? "" : "s")", role: .destructive) {
                    Task {
                        await library.deleteQueuedAssets()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("PhotoSweep cannot bypass the iOS confirmation. You can still recover deleted items from Recently Deleted for 30 days.")
            }
        }
        .preferredColorScheme(.dark)
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
