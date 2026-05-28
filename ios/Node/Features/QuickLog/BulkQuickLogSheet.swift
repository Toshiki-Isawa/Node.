import SwiftUI

struct BulkQuickLogSheet: View {
    @ObservedObject var viewModel: BulkQuickLogViewModel
    var onObserveAfterSave: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var isPlantListExpanded = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NodeSpacing.sp5) {
                    careTypeSection
                    dateTimeSection
                    memoField
                    plantSelectionSection
                }
                .padding(.horizontal, NodeSpacing.sp5)
                .padding(.top, NodeSpacing.sp2)
                .padding(.bottom, NodeSpacing.sp4)
            }
            .background(NodeColor.charcoal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(NodeColor.fog)
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        MetaLabel(text: "一括クイックログ", size: 9)
                        Text("\(viewModel.selectedCount)件選択")
                            .font(NodeFont.text(NodeFont.caption, weight: .medium))
                            .foregroundStyle(NodeColor.bone)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionButtons
            }
            .onAppear {
                isPlantListExpanded = !viewModel.shouldCollapsePlantListByDefault
            }
            .onChange(of: viewModel.selectedCount) { _, count in
                if count == 0 {
                    isPlantListExpanded = true
                }
            }
        }
    }

    private var plantSelectionSection: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            HStack(alignment: .firstTextBaseline) {
                MetaLabel(text: "植物", size: 9)
                Spacer()
                if viewModel.selectedCount > BulkQuickLogViewModel.plantListCollapseThreshold {
                    Button(isPlantListExpanded ? "閉じる" : "変更") {
                        withAnimation(NodeMotion.quietAnimation) {
                            isPlantListExpanded.toggle()
                        }
                    }
                    .font(NodeFont.text(12, weight: .medium))
                    .foregroundStyle(NodeColor.mossSoft)
                }
            }

            if isPlantListExpanded {
                expandedPlantSelection
            } else {
                collapsedPlantSummary
            }
        }
    }

    private var collapsedPlantSummary: some View {
        Button {
            withAnimation(NodeMotion.quietAnimation) {
                isPlantListExpanded = true
            }
        } label: {
            HStack(spacing: NodeSpacing.sp3) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.selectedCount)件選択中")
                        .font(NodeFont.text(NodeFont.callout, weight: .medium))
                        .foregroundStyle(NodeColor.bone)
                    Text(viewModel.selectedPlantSummaryText)
                        .font(NodeFont.text(NodeFont.caption))
                        .foregroundStyle(NodeColor.fog)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NodeColor.mist)
            }
            .padding(NodeSpacing.sp3)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .fill(NodeColor.bark.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .stroke(NodeColor.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var expandedPlantSelection: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NodeSpacing.sp2) {
                    filterChip("すべて", isSelected: viewModel.selectedCount == viewModel.plants.count && !viewModel.plants.isEmpty) {
                        viewModel.selectAllPlants()
                    }
                    filterChip("水やり待ち", isSelected: false) {
                        viewModel.selectPlantsNeedingWater()
                    }
                    filterChip("解除", isSelected: false) {
                        viewModel.clearPlantSelection()
                    }
                }
            }

            if viewModel.plants.isEmpty {
                Text("植物がまだありません。")
                    .font(NodeFont.text(NodeFont.caption))
                    .foregroundStyle(NodeColor.fog)
            } else {
                VStack(spacing: NodeSpacing.sp2) {
                    ForEach(viewModel.plants, id: \.id) { plant in
                        plantRow(plant)
                    }
                }
            }
        }
    }

    private func filterChip(_ title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
        NodeChip(title: title, isSelected: isSelected, action: action)
    }

    private func plantRow(_ plant: Plant) -> some View {
        let isSelected = viewModel.isPlantSelected(plant)

        return Button {
            viewModel.togglePlant(plant)
        } label: {
            HStack(spacing: NodeSpacing.sp3) {
                ZStack {
                    RoundedRectangle(cornerRadius: NodeRadius.sm)
                        .fill(NodeColor.bark)
                        .frame(width: 40, height: 40)
                    Image(systemName: isSelected ? "checkmark" : "leaf")
                        .font(.system(size: isSelected ? 14 : 16, weight: .medium))
                        .foregroundStyle(isSelected ? NodeColor.moss : NodeColor.fog)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: NodeRadius.sm)
                        .stroke(isSelected ? NodeColor.moss : NodeColor.hairline, lineWidth: isSelected ? 2 : 1)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(plant.name)
                        .font(NodeFont.text(NodeFont.callout, weight: .medium))
                        .foregroundStyle(NodeColor.bone)
                    if !plant.species.isEmpty {
                        Text(plant.species)
                            .font(NodeFont.text(NodeFont.caption))
                            .italic()
                            .foregroundStyle(NodeColor.fog)
                    }
                }

                Spacer()

                if let label = plant.wateringStatusLabel {
                    HStack(spacing: 3) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9))
                        Text(label)
                            .font(NodeFont.mono(9))
                    }
                    .foregroundStyle(NodeColor.mossSoft)
                }
            }
            .padding(NodeSpacing.sp3)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .fill(isSelected ? NodeColor.moss.opacity(0.1) : NodeColor.bark.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .stroke(isSelected ? NodeColor.moss.opacity(0.35) : NodeColor.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var careTypeSection: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            MetaLabel(text: "ケア", size: 9)
            VStack(spacing: NodeSpacing.sp2) {
                logRow([.water, .fertilize, .tonic])
                logRow([.repot, .light])
            }
        }
    }

    private var memoField: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaLabel(text: viewModel.selectedTypes.isEmpty ? "メモ" : "補足 · 任意", size: 9)
            TextField(
                viewModel.selectedTypes.isEmpty ? "状態や観察を記録…" : "—",
                text: $viewModel.memo
            )
            .font(NodeFont.text(NodeFont.body))
            .foregroundStyle(NodeColor.bone)
            .padding(.horizontal, NodeSpacing.sp3)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .fill(NodeColor.bark)
                    .overlay(RoundedRectangle(cornerRadius: NodeRadius.lg).stroke(NodeColor.hairline, lineWidth: 1))
            )
        }
    }

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                MetaLabel(text: "日時", size: 9)
                Spacer()
                if viewModel.isRecordingInPast {
                    Button("今に戻す") {
                        viewModel.resetToNow()
                    }
                    .font(NodeFont.text(12, weight: .medium))
                    .foregroundStyle(NodeColor.mossSoft)
                }
            }

            HStack(spacing: NodeSpacing.sp2) {
                DatePicker(
                    "",
                    selection: $viewModel.recordedAt,
                    in: viewModel.recordedAtRange,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(NodeColor.moss)
                .colorScheme(.dark)

                if viewModel.isRecordingInPast {
                    MetaLabel(text: "過去", color: NodeColor.olive, size: 9)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, NodeSpacing.sp3)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .fill(NodeColor.bark)
                    .overlay(RoundedRectangle(cornerRadius: NodeRadius.lg).stroke(NodeColor.hairline, lineWidth: 1))
            )
        }
    }

    private var actionButtons: some View {
        VStack(spacing: NodeSpacing.sp2) {
            NodePrimaryButton(recordButtonTitle) {
                save(andObserve: false)
            }
            .disabled(!viewModel.canSave)
            .opacity(viewModel.canSave ? 1 : 0.45)

            if onObserveAfterSave != nil {
                NodeSecondaryButton("記録して観測", systemImage: "camera") {
                    save(andObserve: true)
                }
                .disabled(!viewModel.canSave)
                .opacity(viewModel.canSave ? 1 : 0.45)
            }
        }
        .padding(.horizontal, NodeSpacing.sp5)
        .padding(.top, NodeSpacing.sp3)
        .background(
            NodeColor.charcoal
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(NodeColor.hairline)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var recordButtonTitle: LocalizedStringKey {
        let count = viewModel.selectedCount
        let time = viewModel.recordedAt.nodeTime()
        if viewModel.isRecordingInPast {
            let date = viewModel.recordedAt.nodeMonthDay()
            return "\(count)件に記録 · \(date) \(time)"
        }
        return "\(count)件に記録 · \(time)"
    }

    private func logRow(_ types: [GrowthLogType]) -> some View {
        HStack(spacing: NodeSpacing.sp2) {
            ForEach(types) { type in
                QuickLogTypeCell(
                    type: type,
                    isSelected: viewModel.isSelected(type)
                ) {
                    viewModel.toggleType(type)
                }
            }
        }
    }

    private func save(andObserve: Bool) {
        do {
            try viewModel.save()
            dismiss()
            if andObserve {
                DispatchQueue.main.async {
                    onObserveAfterSave?()
                }
            }
        } catch {
            // 保存失敗時はシートを開いたままにする
        }
    }
}
