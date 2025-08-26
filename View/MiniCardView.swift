import SwiftUI

struct MiniCardView: View {
    let symbol: String
    let price: Double?   // nil = fetching

    var body: some View {
        HStack(spacing: 8) {
            Text(symbol.uppercased())
                .font(.footnote.weight(.semibold))

            Spacer(minLength: 6)

            if let p = price {
                Text(p, format: .currency(code: "USD"))
                    .font(.footnote.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else {
                // компактное состояние загрузки
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
        .frame(height: 36)                  // низкий форм-фактор
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
