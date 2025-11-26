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

    // On ne veut appeler /predict qu'une seule fois par essai
    @State private var earlyPredictionDone = false

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
        // 🔁 Surveille le temps écoulé pour déclencher la prédiction rapide
        .onChange(of: app.recorder.elapsed) { newElapsed in
            maybeSendEarlyPrediction(elapsed: newElapsed)
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

    // MARK: - Live segmentation pour early predict

    /// Découpe les samples en deux segments de 20 s, en ignorant les 2 premières secondes.
    /// On part du temps t des SensorSample (déjà dans recorder.samples).
    private func firstTwoSegments(from samples: [SensorSample],
                                  window: TimeInterval = 20.0,
                                  ignoreFirst: TimeInterval = 2.0) -> [[SensorSample]] {
        guard let first = samples.first, let last = samples.last else {
            return []
        }

        let totalDuration = last.t - first.t
        let needed = ignoreFirst + 2 * window
        guard totalDuration >= needed else {
            return []
        }

        // On suppose que t est croissant, on prend 2 fenêtres consécutives
        let start1 = first.t + ignoreFirst
        let end1   = start1 + window
        let start2 = end1
        let end2   = start2 + window

        let seg1 = samples.filter { $0.t >= start1 && $0.t < end1 }
        let seg2 = samples.filter { $0.t >= start2 && $0.t < end2 }

        if seg1.isEmpty || seg2.isEmpty {
            return []
        }
        return [seg1, seg2]
    }

    /// Déclenche l'envoi des 2 premiers segments à /predict quand on a assez de données.
    private func maybeSendEarlyPrediction(elapsed: Double) {
        // Déjà fait une fois pour cet essai ? On ne refait rien.
        if earlyPredictionDone { return }

        // On attend qu'il y ait au moins ~42 s de données pour être safe :
        // 2 s ignorées + 2 x 20 s.
        guard elapsed >= 42.0 else { return }

        let samples = app.recorder.samples
        let segments = firstTwoSegments(from: samples)

        guard segments.count == 2 else {
            return
        }

        Task {
            do {
                let resp = try await GaitBACAPI.shared.sendEarlyPrediction(
                    meta: buildFinalMeta(),
                    segments: segments
                )

                // ⚠️ Mise à jour de l'état global sur le main thread
                await MainActor.run {
                    app.earlyPrediction = resp
                    earlyPredictionDone = true
                }

                print("Early prediction success:", resp.segments)
            } catch {
                print("Early prediction failed:", error)
            }
        }
    }
}
