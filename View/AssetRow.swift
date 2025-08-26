import SwiftUI

struct AssetRow: View {
    let symbol: String
    let totalAmount: Double
    let totalInvested: Double
    let price: Double?

    var body: some View {
        let value = (price ?? 0) * totalAmount
        let profit = value - totalInvested
        let percent = totalInvested == 0 ? 0 : profit / totalInvested * 100

        HStack(spacing: 12) {
            // Иконка слева
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple.opacity(0.15), .blue.opacity(0.15)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: iconName(for: symbol))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 36, height: 36)

            // Название и количество
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol.uppercased())
                    .font(.subheadline.weight(.semibold))
                Text("\(totalAmount, specifier: "%.4f") \(symbol.uppercased())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            // Суммы справа + чип прибыли
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(totalInvested, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if price != nil {
                    Text("$\(value, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundStyle(.primary)
                } else {
                    Text("Fetching…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProfitChip(profit: profit, percent: percent)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func iconName(for symbol: String) -> String {
        switch symbol.uppercased() {
        case "BTC": return "bitcoinsign.circle.fill"
        case "ETH": return "e.circle.fill"
        case "SOL": return "sun.max.circle.fill"
        case "TON": return "paperplane.circle.fill"
        case "LINK": return "link.circle.fill"
        case "SUI": return "drop.circle.fill"
        case "XRP": return "x.circle.fill"
        default:     return "circle.fill"
        }
    }
}

struct ProfitChip: View {
    let profit: Double
    let percent: Double

    var body: some View {
        let isPos = profit > 0
        let text = String(
            format: "%@$%.2f (%@%.1f%%)",
            isPos ? "+" : "", abs(profit),
            isPos ? "+" : "", abs(percent)
        )

        Text(text)
            .font(.caption2.monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isPos ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isPos ? .green.opacity(0.35) : .red.opacity(0.35), lineWidth: 0.8)
            )
            .foregroundStyle(isPos ? .green : .red)
    }
}
