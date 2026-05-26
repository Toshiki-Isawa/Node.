import SwiftUI

struct WateringIntervalSection: View {
    @Binding var intervalDays: Int?
    var footerHint: String? = nil

    @State private var usesCustomInput = false
    @State private var customDaysText = ""

    private var isCustomValue: Bool {
        guard let intervalDays else { return false }
        return !WateringInterval.isPreset(intervalDays)
    }

    private var isCustomSelected: Bool {
        usesCustomInput || isCustomValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            HStack {
                MetaLabel(text: "水やり頻度", size: 9)
                Spacer()
                MetaLabel(text: "任意", color: NodeColor.fossil, size: 9)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NodeSpacing.sp2) {
                    NodeChip(title: "設定しない", isSelected: intervalDays == nil && !isCustomSelected) {
                        selectNone()
                    }
                    NodeChip(title: "自由入力", isSelected: isCustomSelected) {
                        selectCustom()
                    }
                    ForEach(WateringInterval.allCases) { interval in
                        NodeChip(
                            title: interval.label,
                            isSelected: intervalDays == interval.rawValue && !isCustomSelected
                        ) {
                            selectPreset(interval.rawValue)
                        }
                    }
                }
            }

            if isCustomSelected {
                customInputRow
            }

            if let footerHint {
                MetaLabel(text: footerHint, color: NodeColor.fog, size: 9)
            }
        }
        .onAppear { syncLocalState() }
    }

    private var customInputRow: some View {
        HStack(spacing: NodeSpacing.sp2) {
            TextField("例: 10", text: $customDaysText)
                .font(NodeFont.text(NodeFont.body))
                .foregroundStyle(NodeColor.bone)
                .keyboardType(.numberPad)
                .onChange(of: customDaysText) { _, newValue in
                    applyCustomInput(newValue)
                }
            Text("日")
                .font(NodeFont.text(NodeFont.body))
                .foregroundStyle(NodeColor.fog)
        }
        .padding(NodeSpacing.sp3)
        .background(
            RoundedRectangle(cornerRadius: NodeRadius.lg)
                .fill(NodeColor.bark)
                .overlay(
                    RoundedRectangle(cornerRadius: NodeRadius.lg)
                        .stroke(NodeColor.hairline, lineWidth: 1)
                )
        )
    }

    private func selectNone() {
        usesCustomInput = false
        customDaysText = ""
        intervalDays = nil
    }

    private func selectPreset(_ days: Int) {
        usesCustomInput = false
        customDaysText = ""
        intervalDays = days
    }

    private func selectCustom() {
        usesCustomInput = true
        if let days = intervalDays, !WateringInterval.isPreset(days) {
            customDaysText = "\(days)"
        } else {
            customDaysText = ""
            intervalDays = nil
        }
    }

    private func syncLocalState() {
        if let days = intervalDays, !WateringInterval.isPreset(days) {
            usesCustomInput = true
            customDaysText = "\(days)"
        } else {
            usesCustomInput = false
            customDaysText = ""
        }
    }

    private func applyCustomInput(_ text: String) {
        let digits = text.filter(\.isNumber)
        if digits != text {
            customDaysText = digits
            return
        }
        guard usesCustomInput else { return }
        if let days = Int(digits), days > 0 {
            intervalDays = days
        } else {
            intervalDays = nil
        }
    }
}
