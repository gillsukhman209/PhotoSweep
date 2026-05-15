import Photos
import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @StateObject private var tiltController = TiltDecisionController()
    @AppStorage("PhotoSweep.hasCompletedOnboarding.v2") private var hasCompletedOnboarding = false
    @AppStorage("PhotoSweep.tiltToSwipeEnabled") private var tiltToSwipeEnabled = false
    @State private var showingDeleteReview = false
    @State private var showingDuplicateReview = false
    @State private var showingDateJump = false
    @State private var showingSettings = false
    @State private var tiltFeedback: TiltDirection?

    private let keepColor = Color(red: 0.18, green: 0.78, blue: 0.49)
    private let deleteColor = Color(red: 1.0, green: 0.32, blue: 0.36)
    private let inkColor = Color.white

    var body: some View {
        NavigationStack {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                } else {
                    switch library.accessState {
                    case .unknown, .notDetermined:
                        permissionView
                    case .denied, .restricted:
                        blockedView
                    case .authorized, .limited:
                        reviewView
                    }
                }
            }
            .navigationTitle("PhotoSweep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if library.accessState.canReadAndWrite {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            library.undo()
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(library.history.isEmpty)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingDeleteReview = true
                        } label: {
                            Label("Review \(library.deleteCount)", systemImage: "rectangle.stack.badge.minus")
                        }
                        .disabled(library.deleteCount == 0)
                    }
                }
            }
            .sheet(isPresented: $showingDeleteReview) {
                DeleteReviewView()
                    .environmentObject(library)
            }
            .sheet(isPresented: $showingDuplicateReview) {
                DuplicateReviewView()
                    .environmentObject(library)
            }
            .sheet(isPresented: $showingDateJump) {
                DateJumpView()
                    .environmentObject(library)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    tiltToSwipeEnabled: $tiltToSwipeEnabled,
                    hasCompletedOnboarding: $hasCompletedOnboarding
                )
                    .preferredColorScheme(.dark)
            }
            .task {
                guard hasCompletedOnboarding else { return }
                library.refreshAuthorization()
                if library.accessState.canReadAndWrite && library.assets.isEmpty {
                    await library.loadAssets(resetSession: true)
                }
            }
            .onChange(of: hasCompletedOnboarding) {
                guard hasCompletedOnboarding else { return }
                library.refreshAuthorization()
                if library.accessState.canReadAndWrite && library.assets.isEmpty {
                    Task {
                        await library.loadAssets(resetSession: true)
                    }
                }
            }
            .alert("PhotoSweep", isPresented: Binding(
                get: { library.message != nil },
                set: { if !$0 { library.message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(library.message ?? "")
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var permissionView: some View {
        VStack(spacing: 26) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 104, height: 104)
                .background(
                    LinearGradient(
                        colors: [keepColor, Color(red: 0.13, green: 0.38, blue: 0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .shadow(color: keepColor.opacity(0.20), radius: 20, x: 0, y: 12)

            VStack(spacing: 12) {
                Text("Allow Photo Access")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("PhotoSweep needs your library to find clutter and show photos for review.")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.86)
            }

            Label("Photos stay on your iPhone", systemImage: "lock.shield.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(keepColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(keepColor.opacity(0.13), in: Capsule())

            Button {
                library.requestAccess()
            } label: {
                Text("Allow Photos")
                    .font(.headline.weight(.black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(keepColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var blockedView: some View {
        ContentUnavailableView {
            Label("Photos Access Needed", systemImage: "lock")
        } description: {
            Text("Enable read and write Photos access in Settings to review and delete library items.")
        } actions: {
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var reviewView: some View {
        VStack(spacing: 0) {
            topControls
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 8)

            progressLine
                .padding(.horizontal, 18)

            if library.isLoading {
                Spacer()
                ProgressView("Loading library...")
                    .controlSize(.large)
                Spacer()
            } else if library.assets.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "photo",
                    description: Text("Try another filter or allow full library access.")
                )
            } else if let asset = library.currentAsset {
                VStack(spacing: 0) {
                    tiltHint

                    SwipeCardView(
                        asset: asset,
                        onKeep: library.keepCurrent,
                        onDelete: library.queueDeleteCurrent
                    )
                    .id(asset.localIdentifier)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    swipeActionButtons
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)

                    quickSkipRail
                }
            } else {
                completionView
            }
        }
        .background(Color.black)
        .onAppear {
            updateTiltMonitoring()
            preheatUpcomingImages()
        }
        .onDisappear {
            tiltController.stop()
        }
        .onChange(of: tiltMonitoringAllowed) {
            updateTiltMonitoring()
        }
        .onChange(of: library.currentAsset?.localIdentifier) {
            updateTiltMonitoring()
            preheatUpcomingImages()
        }
        .onChange(of: library.assets.count) {
            preheatUpcomingImages()
        }
        .onChange(of: tiltToSwipeEnabled) {
            updateTiltMonitoring()
        }
        .onChange(of: showingSettings) {
            updateTiltMonitoring()
        }
        .onChange(of: showingDateJump) {
            updateTiltMonitoring()
        }
    }

    private var topControls: some View {
        HStack(spacing: 10) {
            topIconButton(
                systemImage: "arrow.uturn.backward",
                tint: .white,
                isEnabled: !library.history.isEmpty,
                accessibilityLabel: "Undo"
            ) {
                library.undo()
            }

            filterMenu

            Spacer()

            Text(positionText)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .accessibilityLabel("Review progress \(positionText)")

            Spacer()

            topIconButton(
                systemImage: "square.on.square",
                tint: .white,
                badge: duplicateBadge,
                progress: library.isScanningDuplicates ? library.duplicateScanProgress : nil,
                accessibilityLabel: "Find duplicates"
            ) {
                showingDuplicateReview = true
            }

            if library.deleteCount > 0 {
                topIconButton(
                    systemImage: "trash",
                    tint: deleteColor,
                    badge: deleteBadge,
                    accessibilityLabel: "Review marked photos"
                ) {
                    showingDeleteReview = true
                }
            }
        }
        .frame(height: 54)
    }

    private var filterMenu: some View {
        Menu {
            ForEach(CleanupFilter.allCases) { filter in
                Button {
                    library.changeFilter(to: filter)
                } label: {
                    Label(filter.title, systemImage: filter.icon)
                }
            }

            Divider()

            Button {
                showingDateJump = true
            } label: {
                Label("Jump to Date", systemImage: "calendar")
            }

            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: library.filter.icon)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 52, height: 52)
                    .foregroundStyle(.white)
                    .background(controlFill, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    }

                if library.filter != .photos {
                    Circle()
                        .fill(keepColor)
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle().stroke(.black, lineWidth: 2)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter photos")
    }

    private var progressLine: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))

                Capsule()
                    .fill(keepColor)
                    .frame(width: proxy.size.width * library.progress)
            }
        }
        .frame(height: 3)
    }

    @ViewBuilder
    private var tiltHint: some View {
        if tiltController.isActive {
            HStack(spacing: 10) {
                tiltHintItem(
                    title: "Left delete",
                    systemImage: "arrow.left",
                    color: deleteColor,
                    isActive: tiltFeedback == .left
                )

                Spacer(minLength: 6)

                Image(systemName: "iphone")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.46))

                Spacer(minLength: 6)

                tiltHintItem(
                    title: "Right keep",
                    systemImage: "arrow.right",
                    color: keepColor,
                    isActive: tiltFeedback == .right
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: tiltFeedback)
        }
    }

    @ViewBuilder
    private var quickSkipRail: some View {
        let upcoming = library.upcomingAssets(limit: 15)

        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Label("Keep ahead", systemImage: "forward.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)

                    Text("tap a preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.48))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(upcoming.enumerated()), id: \.element.localIdentifier) { offset, asset in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                library.keepUntil(asset)
                            } label: {
                                QuickSkipThumbnail(asset: asset, step: offset + 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Jump ahead \(offset + 1) photo\(offset == 0 ? "" : "s")")
                            .accessibilityHint("Keeps the photos before this preview and jumps to it.")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 2)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(Color.black)
        }
    }

    private var swipeActionButtons: some View {
        HStack(spacing: 12) {
            swipeActionButton(
                title: "Delete",
                systemImage: "hand.thumbsdown.fill",
                color: deleteColor
            ) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                library.queueDeleteCurrent()
            }
            .accessibilityHint("Marks this photo for deletion.")

            swipeActionButton(
                title: "Keep",
                systemImage: "hand.thumbsup.fill",
                color: keepColor
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                library.keepCurrent()
            }
            .accessibilityHint("Keeps this photo and moves to the next one.")
        }
    }

    private var positionText: String {
        guard !library.assets.isEmpty else { return "0 / 0" }
        let current = min(library.currentIndex + 1, library.assets.count)
        return "\(compactNumber(current)) / \(compactNumber(library.assets.count))"
    }

    private var duplicateBadge: String? {
        library.duplicateGroups.isEmpty ? nil : compactNumber(library.duplicateGroups.count)
    }

    private var deleteBadge: String? {
        library.deleteCount == 0 ? nil : compactNumber(library.deleteCount)
    }

    private var controlFill: Color {
        Color(red: 0.09, green: 0.10, blue: 0.12)
    }

    private var tiltMonitoringAllowed: Bool {
        tiltToSwipeEnabled &&
            library.accessState.canReadAndWrite &&
            !library.isLoading &&
            library.currentAsset != nil &&
            !showingDeleteReview &&
            !showingDuplicateReview &&
            !showingDateJump &&
            !showingSettings
    }

    private func updateTiltMonitoring() {
        guard tiltMonitoringAllowed else {
            tiltController.stop()
            return
        }

        tiltController.start { direction in
            guard tiltMonitoringAllowed else { return }

            switch direction {
            case .left:
                library.queueDeleteCurrent()
            case .right:
                library.keepCurrent()
            }

            showTiltFeedback(direction)
        }
    }

    private func showTiltFeedback(_ direction: TiltDirection) {
        tiltFeedback = direction
        UIImpactFeedbackGenerator(style: direction == .left ? .medium : .light).impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if tiltFeedback == direction {
                tiltFeedback = nil
            }
        }
    }

    private func preheatUpcomingImages() {
        guard !library.isLoading else { return }

        var fullSizeAssets: [PHAsset] = []
        if let currentAsset = library.currentAsset {
            fullSizeAssets.append(currentAsset)
        }
        fullSizeAssets.append(contentsOf: library.upcomingAssets(limit: 2))

        PhotoImagePipeline.preheat(
            assets: fullSizeAssets,
            displaySize: CGSize(width: 900, height: 1_300),
            contentMode: .fit,
            quality: .full
        )

        PhotoImagePipeline.preheat(
            assets: library.upcomingAssets(limit: 30),
            displaySize: CGSize(width: 180, height: 220),
            contentMode: .fill,
            quality: .thumbnail
        )
    }

    private func compactNumber(_ value: Int) -> String {
        if value >= 10_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return value.formatted()
    }

    private func topIconButton(
        systemImage: String,
        tint: Color,
        badge: String? = nil,
        progress: Double? = nil,
        isEnabled: Bool = true,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 52, height: 52)
                    .foregroundStyle(isEnabled ? tint : Color.white.opacity(0.22))
                    .background(controlFill.opacity(isEnabled ? 1 : 0.56), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(isEnabled ? 0.10 : 0.04), lineWidth: 1)
                    }

                if let progress {
                    Circle()
                        .trim(from: 0, to: max(0.04, min(progress, 1)))
                        .stroke(keepColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 52, height: 52)
                }

                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(deleteColor, in: Capsule())
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private func tiltHintItem(
        title: String,
        systemImage: String,
        color: Color,
        isActive: Bool
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.black))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .foregroundStyle(isActive ? .black : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? color : Color.white.opacity(0.07), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(isActive ? 0 : 0.22), lineWidth: 1)
            }
            .scaleEffect(isActive ? 1.06 : 1)
    }

    private func swipeActionButton(
        title: String,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(.headline, design: .rounded).weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.84)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(color.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(color.opacity(0.38), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var completionView: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: library.deleteCount == 0 ? "checkmark.circle" : "trash.circle")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(library.deleteCount == 0 ? .green : .red)

            Text("Review complete")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("\(library.deleteCount) item\(library.deleteCount == 1 ? "" : "s") marked for deletion. Review them before iOS asks for final confirmation.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.64))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button {
                showingDeleteReview = true
            } label: {
                Label("Review Marked Photos", systemImage: "rectangle.stack.badge.minus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(library.deleteCount == 0)
            .padding(.horizontal, 24)

            Button("Start Over") {
                library.restartSession()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PhotoLibraryStore())
}

private struct QuickSkipThumbnail: View {
    let asset: PHAsset
    let step: Int

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AssetImageView(asset: asset, contentMode: .fill, quality: .thumbnail)
                .frame(width: 58, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

            Text("+\(step)")
                .font(.caption2.weight(.black))
                .monospacedDigit()
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white, in: Capsule())
                .padding(4)
        }
        .frame(width: 58, height: 68)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var tiltToSwipeEnabled: Bool
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $tiltToSwipeEnabled) {
                        Label("Tilt to Swipe", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .tint(Color(red: 0.18, green: 0.78, blue: 0.49))

                    Text("Off by default. Tilt left marks delete. Tilt right keeps.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        hasCompletedOnboarding = false
                        dismiss()
                    } label: {
                        Label("Restart Onboarding", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Use this while testing the onboarding flow.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
