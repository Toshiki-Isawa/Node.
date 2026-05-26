import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var planService: PlanService
    @Environment(\.dismiss) private var dismiss

    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showPrivacyPolicy = false

    var body: some View {
        ScrollView {
            VStack(spacing: NodeSpacing.sp5) {
                topBar
                if ReleaseConfig.cloudSyncEnabled {
                    currentPlanSection
                    cloudSection
                } else {
                    localOnlyNoticeSection
                }
                localSection
                if ReleaseConfig.cloudSyncEnabled {
                    syncSection
                }
                if ReleaseConfig.subscriptionsEnabled {
                    plansSection
                }
                actionsSection
                legalSection
                if ReleaseConfig.cloudSyncEnabled {
                    accountSection
                }
                versionFooter
            }
            .padding(.horizontal, NodeSpacing.sp4)
            .padding(.bottom, NodeSpacing.sp10)
        }
        .background(NodeColor.graphite)
        .task { await viewModel.reload() }
        .confirmationDialog(
            "ログアウトしますか？",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("ログアウト", role: .destructive) {
                Task { await viewModel.signOut() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("端末内のデータは残ります。再度サインインするとクラウド同期を再開できます。")
        }
        .confirmationDialog(
            "アカウントを削除しますか？",
            isPresented: $showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(deleteAccountMessage)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            if let url = LegalConfig.effectivePrivacyPolicyURL {
                PrivacyPolicyWebView(url: url)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(NodeColor.fog)
            }
            Spacer()
            Text("設定")
                .font(NodeFont.text(NodeFont.title3, weight: .medium))
                .foregroundStyle(NodeColor.bone)
            Spacer()
            if viewModel.isRefreshing {
                ProgressView()
                    .tint(NodeColor.moss)
                    .scaleEffect(0.8)
            } else {
                Color.clear.frame(width: 20, height: 20)
            }
        }
        .padding(.top, NodeSpacing.sp2)
    }

    private var currentPlanSection: some View {
        SettingsCard(title: "現在のプラン") {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: NodeSpacing.sp1) {
                    Text(viewModel.plan.displayName)
                        .font(NodeFont.text(NodeFont.title3, weight: .medium))
                        .foregroundStyle(NodeColor.bone)
                    Text(viewModel.plan.tagline)
                        .font(NodeFont.text(NodeFont.caption))
                        .foregroundStyle(NodeColor.fog)
                    Text(storageLimitLabel)
                        .font(NodeFont.mono(NodeFont.caption))
                        .foregroundStyle(NodeColor.mossSoft)
                }
                Spacer()
                planBadge(for: viewModel.plan)
            }

            if viewModel.plan.isPaid {
                Button {
                    Task { await viewModel.manageSubscriptions() }
                } label: {
                    Text("サブスクリプションを管理")
                        .font(NodeFont.text(12, weight: .medium))
                        .foregroundStyle(NodeColor.fog)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var deleteAccountMessage: String {
        if viewModel.plan.isPaid {
            return "クラウド上のデータは完全に削除されます。有料プランは App Store で別途解約してください。端末内のデータは残ります。"
        }
        return "クラウド上のデータは完全に削除されます。端末内のデータは残ります。"
    }

    private var storageLimitLabel: String {
        "クラウド容量 \(StorageFormat.bytes(viewModel.plan.storageLimitBytes))"
    }

    private var localOnlyNoticeSection: some View {
        SettingsCard(title: "端末内保存") {
            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                Text("観測記録はこの iPhone に保存されます。")
                    .font(NodeFont.text(NodeFont.callout))
                    .foregroundStyle(NodeColor.bone)
                Text("アプリを削除したり機種変更をすると、データを引き継げません。クラウドバックアップは今後の有料プランで提供予定です。")
                    .font(NodeFont.text(12))
                    .foregroundStyle(NodeColor.fog)
            }
        }
    }

    @ViewBuilder
    private var cloudSection: some View {
        SettingsCard(title: "クラウド Archive") {
            if planService.storageUsage == nil {
                Text("サインインするとクラウド同期が有効になります")
                    .font(NodeFont.text(NodeFont.callout))
                    .foregroundStyle(NodeColor.fog)
            } else if let usage = planService.storageUsage {
                VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
                    VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                        ProgressView(value: usage.usedRatio)
                            .tint(usage.isAtLimit ? NodeColor.syncPaused : NodeColor.moss)
                        HStack {
                            Text(StorageFormat.bytes(usage.usedBytes))
                                .font(NodeFont.mono(NodeFont.caption))
                                .foregroundStyle(NodeColor.bone)
                            Text("/")
                                .foregroundStyle(NodeColor.fog)
                            Text(StorageFormat.bytes(usage.limitBytes))
                                .font(NodeFont.mono(NodeFont.caption))
                                .foregroundStyle(NodeColor.fog)
                            Spacer()
                            Text(StorageFormat.percent(usage.usedRatio))
                                .font(NodeFont.mono(NodeFont.caption))
                                .foregroundStyle(usage.isAtLimit ? NodeColor.syncPaused : NodeColor.mossSoft)
                        }
                    }

                    SettingsMetricRow(
                        label: "残り容量",
                        value: StorageFormat.bytes(usage.remainingBytes),
                        valueColor: usage.isAtLimit ? NodeColor.syncPaused : NodeColor.bone
                    )

                    SettingsMetricRow(
                        label: "保存品質",
                        value: usage.plan.allowsOriginalSync ? "Original" : "圧縮版"
                    )

                    if viewModel.isCloudSyncPaused {
                        HStack(spacing: NodeSpacing.sp2) {
                            SyncDot(state: .syncPausedStorageLimit, size: 6)
                            Text("容量上限のため新規同期が停止しています")
                                .font(NodeFont.text(12))
                                .foregroundStyle(NodeColor.syncPaused)
                        }
                    }
                }
            }
        }
    }

    private var localSection: some View {
        SettingsCard(title: "ローカルストレージ") {
            VStack(spacing: NodeSpacing.sp2) {
                SettingsMetricRow(
                    label: "原画",
                    value: StorageFormat.bytes(viewModel.localBreakdown.originalsBytes)
                )
                SettingsMetricRow(
                    label: "サムネイル",
                    value: StorageFormat.bytes(viewModel.localBreakdown.thumbnailsBytes)
                )
                SettingsMetricRow(
                    label: "キャッシュ",
                    value: StorageFormat.bytes(viewModel.localBreakdown.cacheBytes)
                )
                SettingsMetricRow(
                    label: "データベース",
                    value: StorageFormat.bytes(viewModel.localBreakdown.databaseBytes)
                )
                Divider().overlay(NodeColor.hairline)
                SettingsMetricRow(
                    label: "合計",
                    value: StorageFormat.bytes(viewModel.localBreakdown.totalBytes),
                    valueColor: NodeColor.bone,
                    isEmphasized: true
                )
            }
        }
    }

    private var syncSection: some View {
        SettingsCard(title: "同期状態") {
            VStack(spacing: NodeSpacing.sp2) {
                SettingsMetricRow(
                    label: "同期済み",
                    value: "\(viewModel.syncBreakdown.synced) 件",
                    accessory: SyncDot(state: .synced, size: 6)
                )
                SettingsMetricRow(
                    label: "ローカルのみ",
                    value: "\(viewModel.syncBreakdown.localOnly) 件",
                    accessory: SyncDot(state: .localOnly, size: 6)
                )
                SettingsMetricRow(
                    label: "同期中",
                    value: "\(viewModel.syncBreakdown.syncing) 件",
                    accessory: SyncDot(state: .syncing, size: 6)
                )
                SettingsMetricRow(
                    label: "同期失敗",
                    value: "\(viewModel.syncBreakdown.failed) 件",
                    accessory: SyncDot(state: .failed, size: 6)
                )
                SettingsMetricRow(
                    label: "容量上限で停止",
                    value: "\(viewModel.syncBreakdown.syncPausedStorageLimit) 件",
                    accessory: SyncDot(state: .syncPausedStorageLimit, size: 6)
                )
                if viewModel.syncBreakdown.pending > 0 {
                    Divider().overlay(NodeColor.hairline)
                    SettingsMetricRow(
                        label: "同期待ち",
                        value: "\(viewModel.syncBreakdown.pending) 件",
                        valueColor: NodeColor.olive,
                        isEmphasized: true
                    )
                }
            }
        }
    }

    private var plansSection: some View {
        VStack(spacing: NodeSpacing.sp3) {
            if viewModel.plan == .seed {
                upgradePlanCard(
                    plan: .archive,
                    price: viewModel.archivePriceLabel,
                    features: [
                        "Original クラウド同期",
                        "50GB Archive",
                        "広告なし Export · 4K",
                        "完全復元"
                    ],
                    actionTitle: archiveButtonTitle,
                    action: { Task { await viewModel.purchaseArchive() } }
                )
            }

            if viewModel.plan != .conservatory {
                upgradePlanCard(
                    plan: .conservatory,
                    price: viewModel.conservatoryPriceLabel,
                    features: [
                        "Archive の全機能",
                        "500GB Archive",
                        "高解像度タイムラプス Export",
                        "RAW 保持（将来）"
                    ],
                    actionTitle: conservatoryButtonTitle,
                    action: { Task { await viewModel.purchaseConservatory() } }
                )
            }

            if let message = viewModel.purchaseMessage {
                Text(message)
                    .font(NodeFont.text(12))
                    .foregroundStyle(NodeColor.mossSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var archiveButtonTitle: String {
        if viewModel.isPurchasing { return "処理中…" }
        if let price = viewModel.archivePriceLabel {
            return "Archive にアップグレード · \(price)"
        }
        return "Archive にアップグレード"
    }

    private var conservatoryButtonTitle: String {
        if viewModel.isPurchasing { return "処理中…" }
        if let price = viewModel.conservatoryPriceLabel {
            return "Conservatory にアップグレード · \(price)"
        }
        return "Conservatory にアップグレード"
    }

    private var actionsSection: some View {
        VStack(spacing: NodeSpacing.sp3) {
            if ReleaseConfig.cloudSyncEnabled, viewModel.syncBreakdown.pending > 0 {
                NodeSecondaryButton("同期を再試行", systemImage: "arrow.triangle.2.circlepath") {
                    viewModel.retrySync()
                }
            }

            if ReleaseConfig.subscriptionsEnabled, viewModel.plan == .seed {
                Button {
                    Task { await viewModel.restoreSubscriptions() }
                } label: {
                    Text("購入を復元")
                        .font(NodeFont.text(12, weight: .medium))
                        .foregroundStyle(NodeColor.fog)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isPurchasing)
            }

            Button {
                Task { await viewModel.reload() }
            } label: {
                HStack(spacing: NodeSpacing.sp2) {
                    Image(systemName: "arrow.clockwise")
                    Text("使用量を更新")
                }
                .font(NodeFont.text(NodeFont.callout, weight: .medium))
                .foregroundStyle(NodeColor.fog)
            }
            .buttonStyle(.plain)
        }
    }

    private var versionFooter: some View {
        Text(AppInfo.versionLabel)
            .font(NodeFont.mono(11))
            .foregroundStyle(NodeColor.mist)
            .frame(maxWidth: .infinity)
            .padding(.top, NodeSpacing.sp2)
    }

    private var legalSection: some View {
        SettingsCard(title: "法的情報") {
            Button {
                showPrivacyPolicy = true
            } label: {
                HStack(spacing: NodeSpacing.sp3) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(NodeColor.bone)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: NodeSpacing.sp1) {
                        Text("プライバシーポリシー")
                            .font(NodeFont.text(NodeFont.callout, weight: .medium))
                            .foregroundStyle(NodeColor.bone)
                        Text("個人情報の取り扱いについて")
                            .font(NodeFont.text(12))
                            .foregroundStyle(NodeColor.fog)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NodeColor.mist)
                }
                .padding(.vertical, NodeSpacing.sp1)
            }
            .buttonStyle(.plain)
            .disabled(LegalConfig.effectivePrivacyPolicyURL == nil)
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        if viewModel.isAuthenticated {
            SettingsCard(title: "アカウント") {
                VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
                    if viewModel.plan.isPaid {
                        accountActionRow(
                            title: "プランを解約",
                            subtitle: "App Store のサブスクリプション管理画面を開きます",
                            systemImage: "creditcard",
                            action: { Task { await viewModel.manageSubscriptions() } }
                        )
                    }

                    accountActionRow(
                        title: "ログアウト",
                        subtitle: "この端末からサインアウトします",
                        systemImage: "rectangle.portrait.and.arrow.right",
                        action: { showLogoutConfirmation = true }
                    )

                    accountActionRow(
                        title: "アカウントを削除",
                        subtitle: "クラウド上のデータを完全に削除します",
                        systemImage: "person.crop.circle.badge.minus",
                        titleColor: NodeColor.syncFail,
                        action: { showDeleteAccountConfirmation = true }
                    )

                    if let message = viewModel.accountActionMessage {
                        Text(message)
                            .font(NodeFont.text(12))
                            .foregroundStyle(NodeColor.syncFail)
                    }
                }
            }
        }
    }

    private func accountActionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        titleColor: Color = NodeColor.bone,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: NodeSpacing.sp3) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(titleColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: NodeSpacing.sp1) {
                    Text(title)
                        .font(NodeFont.text(NodeFont.callout, weight: .medium))
                        .foregroundStyle(titleColor)
                    Text(subtitle)
                        .font(NodeFont.text(12))
                        .foregroundStyle(NodeColor.fog)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NodeColor.mist)
            }
            .padding(.vertical, NodeSpacing.sp1)
        }
        .buttonStyle(.plain)
    }

    private func upgradePlanCard(
        plan: UserPlan,
        price: String?,
        features: [String],
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        SettingsCard(title: plan.displayName) {
            VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
                Text(plan.tagline)
                    .font(NodeFont.text(NodeFont.callout))
                    .foregroundStyle(NodeColor.paper)

                if let price {
                    MetaLabel(text: price, color: NodeColor.mossSoft, size: 9)
                }

                VStack(alignment: .leading, spacing: NodeSpacing.sp1) {
                    ForEach(features, id: \.self) { feature in
                        planFeature(feature)
                    }
                }

                if viewModel.isCloudSyncPaused, plan != .seed {
                    Text("容量上限を解消し、同期待ちの Observation をクラウドへ保存できます")
                        .font(NodeFont.text(12))
                        .foregroundStyle(NodeColor.syncPaused)
                }

                NodePrimaryButton(actionTitle, action: action)
                    .disabled(viewModel.isPurchasing)
            }
        }
    }

    private func planBadge(for plan: UserPlan) -> some View {
        Text(plan.displayName.uppercased())
            .font(NodeFont.mono(9))
            .tracking(0.6)
            .foregroundStyle(plan.isPaid ? NodeColor.graphite : NodeColor.mossSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(plan.isPaid ? NodeColor.moss : NodeColor.moss.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(NodeColor.moss.opacity(plan.isPaid ? 0 : 0.35), lineWidth: 1)
            )
    }

    private func planFeature(_ text: String) -> some View {
        HStack(spacing: NodeSpacing.sp2) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NodeColor.mossSoft)
            Text(text)
                .font(NodeFont.text(12))
                .foregroundStyle(NodeColor.fog)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            MetaLabel(text: title, size: 9)
            content
        }
        .padding(NodeSpacing.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: NodeRadius.lg)
                .fill(NodeColor.bark)
                .overlay(
                    RoundedRectangle(cornerRadius: NodeRadius.lg)
                        .stroke(NodeColor.hairline, lineWidth: 1)
                )
        )
    }
}

private struct SettingsMetricRow: View {
    let label: String
    let value: String
    var valueColor: Color = NodeColor.fog
    var isEmphasized: Bool = false
    var accessory: AnyView?

    init(
        label: String,
        value: String,
        valueColor: Color = NodeColor.fog,
        isEmphasized: Bool = false
    ) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.isEmphasized = isEmphasized
        self.accessory = nil
    }

    init<Accessory: View>(
        label: String,
        value: String,
        valueColor: Color = NodeColor.fog,
        isEmphasized: Bool = false,
        accessory: Accessory
    ) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.isEmphasized = isEmphasized
        self.accessory = AnyView(accessory)
    }

    var body: some View {
        HStack(spacing: NodeSpacing.sp2) {
            if let accessory {
                accessory
            }
            Text(label)
                .font(NodeFont.text(isEmphasized ? NodeFont.callout : NodeFont.caption))
                .foregroundStyle(NodeColor.paper)
            Spacer()
            Text(value)
                .font(NodeFont.mono(isEmphasized ? NodeFont.callout : NodeFont.caption))
                .foregroundStyle(valueColor)
        }
    }
}