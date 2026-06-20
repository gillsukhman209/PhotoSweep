import Photos
import SwiftUI
import UIKit

private enum MainTutorialStep: Equatable {
    case swipe
    case deleteReview
    case filter
    case calendar
    case duplicates

    var title: String {
        switch self {
        case .swipe:
            return "Mark one photo"
        case .deleteReview:
            return "Deletes need one last step"
        case .filter:
            return "Choose what to review"
        case .calendar:
            return "Jump to any date"
        case .duplicates:
            return "Find duplicates"
        }
    }

    var subtitle: String {
        switch self {
        case .swipe:
            return "Swipe left or tap Delete to mark a photo. Nothing is deleted yet."
        case .deleteReview:
            return "The trash button opens Review Deletes. Photos are only removed after you tap Delete there."
        case .filter:
            return "Use Filter to switch between photos, videos, screenshots, and other cleanup views."
        case .calendar:
            return "Use Calendar when you want to jump back to a specific month or trip."
        case .duplicates:
            return "Tap the stacked-squares button to review duplicate photos and keep the best one."
        }
    }

    var buttonTitle: String {
        switch self {
        case .swipe:
            return ""
        case .deleteReview, .filter, .calendar:
            return "Next"
        case .duplicates:
            return "Got it"
        }
    }

    var systemImage: String {
        switch self {
        case .swipe:
            return "hand.draw.fill"
        case .deleteReview:
            return "trash.fill"
        case .filter:
            return "line.3.horizontal.decrease"
        case .calendar:
            return "calendar"
        case .duplicates:
            return "rectangle.on.rectangle.angled"
        }
    }

    var tint: Color {
        switch self {
        case .swipe:
            return Color(red: 1.0, green: 0.32, blue: 0.36)
        case .filter, .calendar, .duplicates:
            return Color(red: 0.18, green: 0.78, blue: 0.49)
        case .deleteReview:
            return Color(red: 1.0, green: 0.32, blue: 0.36)
        }
    }

    var spotlightCornerRadius: CGFloat {
        switch self {
        case .swipe:
            return 0
        case .deleteReview, .filter, .calendar, .duplicates:
            return 32
        }
    }

    var arrowImageName: String {
        switch self {
        case .swipe:
            return "arrow.left"
        case .filter:
            return "arrow.up.left"
        case .calendar:
            return "arrow.up"
        case .duplicates:
            return "arrow.up"
        case .deleteReview:
            return "arrow.up.right"
        }
    }

    func spotlightFrame(in size: CGSize) -> CGRect {
        switch self {
        case .swipe:
            return .zero
        case .filter:
            return CGRect(
                x: 14,
                y: 8,
                width: 58,
                height: 58
            )
        case .calendar:
            return CGRect(
                x: max(18, size.width - 230),
                y: 10,
                width: 58,
                height: 58
            )
        case .duplicates:
            return CGRect(
                x: max(18, size.width - 174),
                y: 10,
                width: 58,
                height: 58
            )
        case .deleteReview:
            return CGRect(
                x: max(18, size.width - 68),
                y: 10,
                width: 58,
                height: 58
            )
        }
    }

    func arrowPosition(in size: CGSize) -> CGPoint {
        switch self {
        case .swipe:
            return CGPoint(x: size.width / 2, y: max(120, size.height * 0.26))
        case .filter:
            return CGPoint(x: 74, y: 88)
        case .calendar:
            return CGPoint(x: max(82, size.width - 201), y: 88)
        case .duplicates:
            return CGPoint(x: max(82, size.width - 145), y: 88)
        case .deleteReview:
            return CGPoint(x: max(80, size.width - 66), y: 88)
        }
    }

    func cardPosition(in size: CGSize) -> CGPoint {
        switch self {
        case .swipe:
            return CGPoint(x: size.width / 2, y: min(size.height - 150, max(170, size.height * 0.24)))
        case .deleteReview, .filter, .calendar, .duplicates:
            return CGPoint(x: size.width / 2, y: min(size.height - 130, 190))
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var tiltController = TiltDecisionController()
    @AppStorage("PhotoSweep.hasCompletedOnboarding.v2") private var hasCompletedOnboarding = false
    @AppStorage("PhotoSweep.hasSeenMainTutorial.v1") private var hasSeenMainTutorial = false
    @AppStorage("PhotoSweep.tiltToSwipeEnabled") private var tiltToSwipeEnabled = false
    @AppStorage("PhotoSweep.dailySwipeCount") private var freeSwipeCountUsed = 0
    @State private var showingDeleteReview = false
    @State private var showingDuplicateReview = false
    @State private var showingDateJump = false
    @State private var showingSettings = false
    @State private var tiltFeedback: TiltDirection?
    @State private var isPresentingSwipePaywall = false
    @State private var tutorialStep: MainTutorialStep?

    private let keepColor = Color(red: 0.18, green: 0.78, blue: 0.49)
    private let deleteColor = Color(red: 1.0, green: 0.32, blue: 0.36)
    private var appBackground: Color {
        colorScheme == .dark ? .black : Color(uiColor: .systemGroupedBackground)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.075) : Color.white
    }

    private var controlFill: Color {
        colorScheme == .dark ? Color(red: 0.09, green: 0.10, blue: 0.12) : Color.white
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 0.07, green: 0.08, blue: 0.10)
    }

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.68) : Color(red: 0.34, green: 0.36, blue: 0.42)
    }

    private var controlIconColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.08, green: 0.09, blue: 0.11)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView {
                        hasCompletedOnboarding = true
                        AnalyticsService.track("onboarding_finished")
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
            .navigationTitle("CleanRoll")
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
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    tiltToSwipeEnabled: $tiltToSwipeEnabled,
                    hasCompletedOnboarding: $hasCompletedOnboarding,
                    onShowPro: {
                        AnalyticsService.track("settings_pro_tapped")
                        SuperwallBootstrap.presentPaywall(placement: "photo_sweep", source: "settings")
                    }
                )
                .environmentObject(library)
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
            .alert("CleanRoll", isPresented: Binding(
                get: { library.message != nil },
                set: { if !$0 { library.message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(library.message ?? "")
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var permissionView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 16)

            VStack(spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(keepColor)
                    .frame(width: 76, height: 76)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(keepColor.opacity(0.28), lineWidth: 1)
                    }

                VStack(spacing: 10) {
                    Text("Private Photo Access")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)

                    Text("CleanRoll needs access so you can swipe through your photos. Everything stays on this iPhone.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.82)
                }

                VStack(spacing: 10) {
                    permissionTrustRow("On-device review", "iphone")
                    permissionTrustRow("No uploads", "icloud.slash")
                    permissionTrustRow("You confirm deletes", "checkmark.shield")
                }
            }
            .padding(20)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06), lineWidth: 1)
            }

            Button {
                AnalyticsService.track("photos_permission_requested")
                library.requestAccess()
            } label: {
                Text("Continue")
                    .font(.headline.weight(.black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(.black)
            .buttonStyle(.plain)
            .background(keepColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer(minLength: 16)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: colorScheme == .dark ? [
                    Color(red: 0.055, green: 0.09, blue: 0.10),
                    Color(red: 0.05, green: 0.07, blue: 0.13)
                ] : [
                    Color(red: 0.94, green: 0.99, blue: 0.97),
                    Color(red: 0.97, green: 0.98, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
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

    private func permissionTrustRow(_ title: String, _ systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.black))
                .foregroundStyle(keepColor)
                .frame(width: 28, height: 28)
                .background(keepColor.opacity(0.13), in: Circle())

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(primaryText.opacity(0.86))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(colorScheme == .dark ? Color.black.opacity(0.18) : Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        canUndo: !library.history.isEmpty,
                        onUndo: library.undo,
                        onKeep: { performSwipeDecision(decision: .keep, source: "card_swipe", library.keepCurrent) },
                        onDelete: { performSwipeDecision(decision: .delete, source: "card_swipe", library.queueDeleteCurrent) }
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
        .background(appBackground)
        .blur(radius: tutorialStep == nil ? 0 : 2.5)
        .onAppear {
            updateTiltMonitoring()
            preheatUpcomingImages()
            startMainTutorialIfNeeded()
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
            startMainTutorialIfNeeded()
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
        .overlay {
            if let tutorialStep, !showingDeleteReview, !showingDuplicateReview, !showingDateJump, !showingSettings {
                tutorialOverlay(for: tutorialStep)
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.24), value: tutorialStep)
    }

    private var topControls: some View {
        HStack(spacing: 8) {
            filterMenu

            Spacer(minLength: 0)

            Text(positionText)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .accessibilityLabel("Review progress \(positionText)")

            Spacer(minLength: 0)

            topIconButton(
                systemImage: "calendar",
                tint: controlIconColor,
                accessibilityLabel: "Jump to date"
            ) {
                AnalyticsService.track("date_jump_opened")
                showingDateJump = true
            }

            topIconButton(
                systemImage: "rectangle.on.rectangle.angled",
                tint: controlIconColor,
                badge: duplicateBadge,
                progress: library.isScanningDuplicates ? library.duplicateScanProgress : nil,
                accessibilityLabel: "Duplicates"
            ) {
                AnalyticsService.track("duplicates_opened", properties: [
                    "duplicate_group_count": library.duplicateGroups.count,
                    "is_scanning": library.isScanningDuplicates
                ])
                showingDuplicateReview = true
            }

            topIconButton(
                systemImage: "gearshape.fill",
                tint: controlIconColor,
                accessibilityLabel: "Settings"
            ) {
                AnalyticsService.track("settings_opened")
                showingSettings = true
            }

            if library.deleteCount > 0 {
                topIconButton(
                    systemImage: "trash",
                    tint: deleteColor,
                    badge: deleteBadge,
                    accessibilityLabel: "Review marked photos"
                ) {
                    AnalyticsService.track("delete_review_opened", properties: [
                        "queued_delete_count": library.deleteCount
                    ])
                    showingDeleteReview = true
                }
            }
        }
        .frame(height: 50)
    }

    private var filterMenu: some View {
        Menu {
            ForEach(CleanupFilter.allCases) { filter in
                Button {
                    AnalyticsService.track("filter_selected", properties: [
                        "filter": filter.rawValue,
                        "previous_filter": library.filter.rawValue
                    ])
                    library.changeFilter(to: filter)
                } label: {
                    Label(filter.title, systemImage: filter.icon)
                }
            }

        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(controlIconColor)
                    .background(controlFill, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08), lineWidth: 1)
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
                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10))

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
                    Label("Skip ahead", systemImage: "forward.fill")
                        .font(.caption.weight(.black))
                    .foregroundStyle(primaryText)

                    Text("tap a preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryText.opacity(0.82))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(upcoming.enumerated()), id: \.element.localIdentifier) { offset, asset in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                performSwipeDecision(count: offset + 1, decision: .keep, source: "quick_skip") {
                                    library.keepUntil(asset)
                                }
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
            .background(appBackground)
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
                performSwipeDecision(decision: .delete, source: "button", library.queueDeleteCurrent)
            }
            .accessibilityHint("Marks this photo for deletion.")

            swipeActionButton(
                title: "Keep",
                systemImage: "hand.thumbsup.fill",
                color: keepColor
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                performSwipeDecision(decision: .keep, source: "button", library.keepCurrent)
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
            DispatchQueue.main.async {
                guard tiltMonitoringAllowed else { return }

                switch direction {
                case .left:
                    performSwipeDecision(decision: .delete, source: "tilt", library.queueDeleteCurrent)
                case .right:
                    performSwipeDecision(decision: .keep, source: "tilt", library.keepCurrent)
                }

                showTiltFeedback(direction)
            }
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

    private func performSwipeDecision(
        count: Int = 1,
        decision reviewDecision: ReviewDecision,
        source: String,
        _ action: @escaping () -> Void
    ) {
        let decision = {
            guard count > 0 else { return }
            let runSwipeAction = {
                action()
                advanceTutorialAfterSwipeIfNeeded(reviewDecision)
            }

            #if DEBUG
            debugPaywallLog("DEBUG build: bypassing paywall and free swipe limit")
            runSwipeAction()
            trackSwipeDecision(reviewDecision, source: source, count: count, gated: false, proUser: false)
            return
            #endif

            let hasProAccess = SuperwallBootstrap.hasProAccess
            debugPaywallLog(
                "swipe decision source=\(source) decision=\(reviewDecision.rawValue) requestedCount=\(count) freeSwipeCountUsed=\(freeSwipeCountUsed) hasProAccess=\(hasProAccess)"
            )

            if hasProAccess {
                debugPaywallLog("allowing swipe because Pro access is active")
                runSwipeAction()
                trackSwipeDecision(reviewDecision, source: source, count: count, gated: false, proUser: true)
                return
            }

            if LifetimeSwipeGate.canUseFreeSwipes(usedCount: freeSwipeCountUsed, requestedCount: count) {
                debugPaywallLog("allowing lifetime free swipe; count \(freeSwipeCountUsed) -> \(freeSwipeCountUsed + count)")
                freeSwipeCountUsed += count
                runSwipeAction()
                trackSwipeDecision(reviewDecision, source: source, count: count, gated: false, proUser: false)
                return
            }

            guard !isPresentingSwipePaywall else {
                debugPaywallLog("blocked paywall request because a paywall is already being presented")
                return
            }
            isPresentingSwipePaywall = true
            debugPaywallLog("free limit reached; requesting Superwall placement=photo_sweep")
            AnalyticsService.track("free_swipe_limit_reached", properties: [
                "free_swipes_used": freeSwipeCountUsed,
                "requested_swipe_count": count,
                "free_swipe_limit": LifetimeSwipeGate.freeSwipeLimit,
                "free_limit_type": "lifetime",
                "source": source,
                "decision": reviewDecision.rawValue
            ])

            SuperwallBootstrap.requireProAccess(
                placement: "photo_sweep",
                params: [
                    "free_swipes_used": freeSwipeCountUsed,
                    "requested_swipe_count": count,
                    "free_swipe_limit": LifetimeSwipeGate.freeSwipeLimit,
                    "free_limit_type": "lifetime"
                ],
                onComplete: {
                    debugPaywallLog("Superwall paywall flow completed; clearing isPresentingSwipePaywall")
                    isPresentingSwipePaywall = false
                }
            ) {
                debugPaywallLog("Superwall unlocked swipe action after purchase/restore")
                runSwipeAction()
                trackSwipeDecision(reviewDecision, source: source, count: count, gated: true, proUser: true)
            }
        }

        if Thread.isMainThread {
            decision()
        } else {
            DispatchQueue.main.async {
                decision()
            }
        }
    }

    private func trackSwipeDecision(
        _ decision: ReviewDecision,
        source: String,
        count: Int,
        gated: Bool,
        proUser: Bool
    ) {
        AnalyticsService.track("photo_swiped_\(decision.rawValue)", properties: [
            "decision": decision.rawValue,
            "source": source,
            "swipe_count": count,
            "filter": library.filter.rawValue,
            "free_swipes_used": freeSwipeCountUsed,
            "free_swipe_limit": LifetimeSwipeGate.freeSwipeLimit,
            "free_limit_type": "lifetime",
            "was_paywall_gated": gated,
            "pro_user": proUser
        ])
    }

    private func startMainTutorialIfNeeded() {
        guard !hasSeenMainTutorial,
              tutorialStep == nil,
              library.accessState.canReadAndWrite,
              !library.isLoading,
              library.currentAsset != nil else {
            return
        }

        tutorialStep = .swipe
        AnalyticsService.track("main_tutorial_started")
    }

    private func advanceTutorialAfterSwipeIfNeeded(_ decision: ReviewDecision) {
        guard tutorialStep == .swipe, decision == .delete else { return }
        tutorialStep = .deleteReview
        AnalyticsService.track("main_tutorial_delete_marked")
    }

    private func advanceTutorial() {
        switch tutorialStep {
        case .swipe:
            break
        case .deleteReview:
            tutorialStep = .filter
        case .filter:
            tutorialStep = .calendar
        case .calendar:
            tutorialStep = .duplicates
        case .duplicates:
            completeTutorial()
        case nil:
            break
        }
    }

    private func completeTutorial() {
        hasSeenMainTutorial = true
        tutorialStep = nil
        AnalyticsService.track("main_tutorial_completed")
    }

    private func tutorialOverlay(for step: MainTutorialStep) -> some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.56)
                    .ignoresSafeArea()

                if step != .swipe {
                    tutorialSpotlight(for: step, in: proxy.size)

                    tutorialArrow(for: step, in: proxy.size)
                }

                tutorialCard(for: step)
                    .frame(maxWidth: min(proxy.size.width - 32, 380))
                    .position(step.cardPosition(in: proxy.size))
            }
            .allowsHitTesting(step != .swipe)
        }
    }

    private func tutorialSpotlight(for step: MainTutorialStep, in size: CGSize) -> some View {
        let frame = step.spotlightFrame(in: size)

        return RoundedRectangle(cornerRadius: step.spotlightCornerRadius, style: .continuous)
            .stroke(step.tint, lineWidth: 4)
            .background(
                RoundedRectangle(cornerRadius: step.spotlightCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .shadow(color: step.tint.opacity(0.55), radius: 18, x: 0, y: 0)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .accessibilityHidden(true)
    }

    private func tutorialArrow(for step: MainTutorialStep, in size: CGSize) -> some View {
        Image(systemName: step.arrowImageName)
            .font(.system(size: 34, weight: .black))
            .foregroundStyle(step.tint)
            .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 4)
            .position(step.arrowPosition(in: size))
            .accessibilityHidden(true)
    }

    private func tutorialCard(for step: MainTutorialStep) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: step.systemImage)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(step.tint)
                    .frame(width: 38, height: 38)
                    .background(step.tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(step.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if step == .swipe {
                Text("Swipe left to continue")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(step.tint)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                HStack(spacing: 10) {
                    Button("Skip") {
                        completeTutorial()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.54))

                    Spacer(minLength: 0)

                    Button {
                        advanceTutorial()
                    } label: {
                        Text(step.buttonTitle)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .frame(height: 40)
                            .background(step.tint, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.38), radius: 22, x: 0, y: 12)
    }

    private func debugPaywallLog(_ message: String) {
        #if DEBUG
        print("PhotoSweepPaywall \(message)")
        #endif
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
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(isEnabled ? tint : secondaryText.opacity(0.45))
                    .background(controlFill.opacity(isEnabled ? 1 : 0.56), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(colorScheme == .dark ? Color.white.opacity(isEnabled ? 0.10 : 0.04) : Color.black.opacity(isEnabled ? 0.08 : 0.03), lineWidth: 1)
                    }

                if let progress {
                    Circle()
                        .trim(from: 0, to: max(0.04, min(progress, 1)))
                        .stroke(keepColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 48, height: 48)
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
            .background(isActive ? color : (colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.045)), in: Capsule())
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
                .foregroundStyle(primaryText)
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
                .foregroundStyle(secondaryText)
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
    @EnvironmentObject private var library: PhotoLibraryStore
    @Binding var tiltToSwipeEnabled: Bool
    @Binding var hasCompletedOnboarding: Bool
    let onShowPro: () -> Void
    @State private var isRestoringPurchases = false
    @State private var isResettingPhotos = false
    @State private var restoreAlert: RestoreAlert?

    var body: some View {
        NavigationStack {
            Form {
                #if !DEBUG
                Section {
                    Button {
                        onShowPro()
                    } label: {
                        Label("CleanRoll Pro", systemImage: "crown.fill")
                    }

                    Text("Unlock unlimited swipes and duplicate cleanup with a one-time Pro upgrade.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        restorePurchases()
                    } label: {
                        HStack {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")

                            if isRestoringPurchases {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRestoringPurchases)
                } header: {
                    Text("Pro")
                } footer: {
                    Text("Tap CleanRoll Pro to view upgrade options or Restore Purchases if you already bought Lifetime Pro.")
                }
                #endif

                Section {
                    Toggle(isOn: $tiltToSwipeEnabled) {
                        Label("Tilt to Swipe", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .tint(Color(red: 0.18, green: 0.78, blue: 0.49))

                    Text("Off by default. Tilt left marks delete. Tilt right keeps.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                #if DEBUG
                Section {
                    Button(role: .destructive) {
                        resetPhotosForDebug()
                    } label: {
                        HStack {
                            Label("Bring Back All Photos", systemImage: "arrow.counterclockwise.circle.fill")

                            if isResettingPhotos {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isResettingPhotos)

                    Button {
                        hasCompletedOnboarding = false
                        dismiss()
                    } label: {
                        Label("Restart Onboarding", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("Debug")
                } footer: {
                    Text("Bring Back All Photos clears local swipe history and reloads the library. It does not restore photos already deleted from iOS Photos.")
                }
                #endif

                Section {
                    Link(destination: LegalLinks.privacyPolicy) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }

                    Link(destination: LegalLinks.termsOfUse) {
                        Label("Terms of Use", systemImage: "doc.text.fill")
                    }
                } header: {
                    Text("Legal")
                } footer: {
                    Text("Purchases use Apple's Standard End User License Agreement.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert(item: $restoreAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func restorePurchases() {
        guard !isRestoringPurchases else { return }

        isRestoringPurchases = true
        Task {
            let outcome = await SuperwallBootstrap.restorePurchases()
            await MainActor.run {
                isRestoringPurchases = false

                switch outcome {
                case .restoredProAccess:
                    restoreAlert = RestoreAlert(
                        title: "Purchases Restored",
                        message: "Your Lifetime Pro access has been restored."
                    )
                case .noPurchaseFound:
                    restoreAlert = RestoreAlert(
                        title: "No Purchase Found",
                        message: "We could not find a previous Lifetime Pro purchase for this Apple ID."
                    )
                case .failed(let message):
                    restoreAlert = RestoreAlert(
                        title: "Restore Failed",
                        message: message
                    )
                }
            }
        }
    }

    #if DEBUG
    private func resetPhotosForDebug() {
        guard !isResettingPhotos else { return }

        isResettingPhotos = true
        Task {
            await library.resetAllReviewStateForDebug()
            await MainActor.run {
                isResettingPhotos = false
                dismiss()
            }
        }
    }
    #endif

    private struct RestoreAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
}
