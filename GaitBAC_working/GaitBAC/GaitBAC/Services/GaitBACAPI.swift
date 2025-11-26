//  GaitBACAPI.swift
//  GaitBAC

import Foundation

struct LiveImuSamplePayload: Codable {
    let t: Double
    let ax: Double
    let ay: Double
    let az: Double
    let gx: Double?
    let gy: Double?
    let gz: Double?

    init(from s: SensorSample) {
        t = s.t
        ax = s.ax
        ay = s.ay
        az = s.az
        gx = s.gx
        gy = s.gy
        gz = s.gz
    }
}

struct PredictSegmentPayload: Codable {
    let segment_index: Int
    let meta: [String:String]
    let samples: [LiveImuSamplePayload]
}

struct PredictRequestPayload: Codable {
    let segments: [PredictSegmentPayload]
}

struct PredictSegmentResult: Codable {
    let segment_index: Int
    let prob_positive: Double
    let over_threshold: Bool
}

struct PredictResponsePayload: Codable {
    let segments: [PredictSegmentResult]
}

final class GaitBACAPI {
    static let shared = GaitBACAPI()

    /// À adapter avec l'adresse IP de ton laptop
    /// Exemple : "http://192.168.0.42:8000"
    var baseURL = URL(string: "http://192.168.0.42:8000")!

    private init() {}

    // MARK: - /predict

    func sendEarlyPrediction(meta: SessionMeta,
                             segments: [[SensorSample]]) async throws -> PredictResponsePayload {
        let url = baseURL.appendingPathComponent("predict")

        let metaDict: [String:String] = [
            "participant_id": meta.participant_id,
            "session_id": meta.session_id,
            "position": meta.carry_position ?? "",
            "phone_model": meta.phone_model,
            "ios_version": meta.ios_version
        ]

        var segPayloads: [PredictSegmentPayload] = []
        for (idx, seg) in segments.enumerated() {
            let sPayloads = seg.map { LiveImuSamplePayload(from: $0) }
            let p = PredictSegmentPayload(
                segment_index: idx,
                meta: metaDict,
                samples: sPayloads
            )
            segPayloads.append(p)
        }

        let reqPayload = PredictRequestPayload(segments: segPayloads)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(reqPayload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "GaitBACAPI", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP error for /predict"])
        }

        let decoded = try JSONDecoder().decode(PredictResponsePayload.self, from: data)
        return decoded
    }

    // MARK: - /archive

    func archiveSessionCSV(url: URL) async throws {
        let endpoint = baseURL.appendingPathComponent("archive")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        let filename = url.lastPathComponent
        let fileData = try Data(contentsOf: url)

        var body = Data()
        func append(_ string: String) {
            body.append(Data(string.utf8))
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: text/csv\r\n\r\n")
        body.append(fileData)
        append("\r\n--\(boundary)--\r\n")

        request.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "GaitBACAPI", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP error for /archive"])
        }
    }
}
