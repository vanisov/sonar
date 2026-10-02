import SwiftUI

func page(@ViewBuilder _ content: () -> some View) -> some View {
    ScrollView {
        VStack(spacing: 14) { content() }.padding(20)
    }
}

let percentAxis: (Double) -> String = { Fmt.percent($0) }

let two = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

let three = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

/// Temperatures ride on 0–100% usage axes: 110 °C maps to the top.
let tempScale = 100.0 / 110.0

func pressureColor(_ pressure: String) -> Color { pressure == "Critical" ? .red : pressure == "Warning" ? .orange : .green }

func keyValue(_ key: String, _ value: String, dot: Color? = nil) -> some View {
    VStack(spacing: 0) {
        HStack {
            if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .padding(.vertical, 6)
        Divider()
    }
}
