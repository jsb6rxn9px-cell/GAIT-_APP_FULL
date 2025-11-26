//
//  SummaryView.swift
//  GaitBAC
//

import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    let meta: SessionMeta
    let onDone: () -> Void

    @State private var exportURL: URL?
    @State private var quality: QualitySummary?
    @State private var showShare = false
    @State private var rejectReason = "user_choice"

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Avertissement si la durée est trop courte
                if app.recorder.elapsed < 20 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Durée insuffisante (<20 s)")
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.yellow.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Info de qualité (comme avant)
                if let q = quality {
                    Text(
                        "Qualité: \(q.score) — \(String(format: "%.2f", q.measuredHz)) Hz, drop \(String(format: "%.1f", q.droppedPct))%"
                    )
                } else {
                    Text("Prêt à enregistrer le fichier et partager…")
                }

                // 🔍 Résultats de la prédiction rapide BAC (si disponibles)
                if let pred = app.earlyPrediction, !pred.segments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prédiction rapide BAC")
                            .font(.headline)

                        ForEach(pred.segments, id: \.segment_index) { seg in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Segment \(seg.segment_index + 1)")
                                        .font(.subheadline)
                                        .bold()
                                    Spacer()
                                    Text(String(format: "p = %.3f", seg.prob_positive))
                                        .font(.subheadline)
                                }

                                Text(seg.over_threshold ? "Dépassement du seuil" : "Sous le seuil")
                                    .font(.subheadline)
                                    .foregroundStyle(seg.over_threshold ? .red : .green)
                            }

                            if seg.segment_index != pred.segments.last?.segment_index {
                                Divider()
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Spacer()

                HStack {
                    // Enregistrer & Exporter (comme avant, + upload /archive)
                    Button("Enregistrer & Exporter") {
                        var m = meta
                        if app.recorder.elapsed < 20 {
                            m.quality_flags["short"] = "true"
                        }
                        if let (url, q) = app.recorder.export(meta: m, settings: app.settings) {
                            exportURL = url
                            quality = q
                            app.loadSidecars()

                            // Auto-increment participant ID après un save réussi
                            app.settings.lastParticipantID = app.settings.nextParticipantID()
                            showShare = true

                            // ✅ Upload silencieux du même CSV vers /archive
                            Task {
                                do {
                                    try await GaitBACAPI.shared.archiveSessionCSV(url: url)
                                    print("Archive upload OK")
                                } catch {
                                    print("Archive upload failed:", error)
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    // Rejeter l'essai
                    Button("Rejeter") {
                        AnalyticsLogger.shared.log(
                            "test_discarded",
                            meta: ["reason": rejectReason],
                            settings: app.settings
                        )
                        app.resetToConsent()
                        dismiss()
                        onDone()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding()
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                        onDone()
                    }
                }
            }
            .sheet(isPresented: $showShare, onDismiss: {
                dismiss()
                onDone()
            }) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                } else {
                    Text("Nothing to share")
                }
            }
        }
    }
}
