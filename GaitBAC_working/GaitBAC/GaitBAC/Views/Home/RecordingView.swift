//
//  RecordingView.swift
//  GaitBAC
//

import SwiftUI

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState

    let meta: SessionMeta
    let goDate: Date

    @State private var isStopping = false
    @State private var showSummary = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Recording…").font(.title.bold())

            // Live elapsed time from MotionRecorder
            Text(elapsedString(app.recorder.elapsed))
                .monospacedDigit()
                .font(.system(size: 48, weight: .heavy, design: .rounded))

            HStack(spacing: 18) {
                LabeledValue(title: "Target Hz", value: "\(meta.sampling_hz_target)")
                LabeledValue(title: "Measured Hz", value: String(format: "%.2f", app.recorder.measuredHz))
            }

            if app.recorder.avgAccelNorm > 0 {
                LabeledValue(title: "Accel (avg)", value: String(format: "%.2f", app.recorder.avgAccelNorm))
            }
            if app.recorder.estCadenceSpm > 0 {
                LabeledValue(title: "Cadence (spm)", value: String(format: "%.0f", app.recorder.estCadenceSpm))
            }

            Spacer()

            Button {
                stopNow()
            } label: {
                Text(isStopping ? "Stopping…" : "Stop")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isStopping)
        }
        .padding()
        .background(Color(.systemBackground)) // avoid any “black screen” artifacts
        .onReceive(app.recorder.$state) { state in
            if state == .finished {
                showSummary = true
            }
        }
        .fullScreenCover(isPresented: $showSummary) {
            SummaryView(meta: buildFinalMeta(), onDone: {
                showSummary = false
                dismiss()            // return to Home after summary
            })
            .environmentObject(app)
        }
    }

    private func stopNow() {
        guard !isStopping else { return }
        isStopping = true
        app.recorder.stopRecording()
        // When state flips to .finished, onReceive will present the summary
    }

    private func elapsedString(_ t: Double) -> String {
        let s = max(0, Int(t.rounded(.down)))
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }

    private func buildFinalMeta() -> SessionMeta {
        var m = meta
        m.sampling_hz_measured = app.recorder.measuredHz
        m.duration_recorded_s = app.recorder.elapsed
        return m
    }
}
