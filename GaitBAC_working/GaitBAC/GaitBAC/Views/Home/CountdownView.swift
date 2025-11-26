import SwiftUI

struct CountdownView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    let meta: SessionMeta

    @State private var counter = 3
    @State private var goDate = Date()
    @State private var showRecording = false
    @State private var timer: Timer?
    @State private var hasStarted = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Get ready…").font(.headline)
                Text("\(max(0, counter))")
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("Place the phone (\(meta.position.rawValue)). Stay still until GO.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                Button("Cancel", role: .cancel) {
                    stopTimer()
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    stopTimer()
                    dismiss()
                } label: { Image(systemName: "xmark") }
            }
        }
        .onAppear {
            // Prepare once, then start countdown once
            if !hasStarted {
                hasStarted = true
                app.recorder.prepare(
                    targetHz: meta.sampling_hz_target,
                    durationSec: 0, // unlimited; recorder enforces 6-min cap internally
                    prerollSec: 0,
                    beeps: app.settings.beeps,
                    haptics: false
                )
                if app.settings.beeps { AudioManager.activateSession() }
                startCountdown()
            }
        }
        .onDisappear {
            stopTimer()
            AudioManager.deactivateSession()
        }
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(meta: meta, goDate: goDate).environmentObject(app)
        }
    }

    private func startCountdown() {
        stopTimer()
        // Fire immediately: show "3" first frame, then tick 2→1→0→GO
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if counter > 0 {
                if app.settings.beeps { AudioManager.beepShort() }
                counter -= 1
            } else {
                if app.settings.beeps { AudioManager.beepLongGo() }
                goDate = Date()
                app.recorder.startRecording(withGoAt: goDate)
                t.invalidate()
                showRecording = true
            }
        }
        if let tm = timer {
            RunLoop.main.add(tm, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
