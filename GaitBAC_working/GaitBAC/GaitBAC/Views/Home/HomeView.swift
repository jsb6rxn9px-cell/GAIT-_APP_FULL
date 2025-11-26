import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState

    // Participant
    @State private var participantID: String = ""
    @State private var sexStr: String = ""
    @State private var ageYears: Int? = nil
    @State private var heightIn: Int? = nil
    @State private var weightLb: Int? = nil

    // Session setup
    @State private var position: PhonePosition = .pocketRight
    @State private var condition: Condition = .unknown
    @State private var orientationStr: String = "portrait"

    // BAC (optional)
    @State private var bacStr: String = ""
    @State private var bacMethod: BACMethod = .breathalyzer
    @State private var bacBrandModel: String = ""
    @State private var bacMeasuredAt: Date? = nil
    @State private var bacDelayMinutes: Int? = nil

    // Notes
    @State private var notes: String = ""

    // Presentation (use item: to avoid empty content)
    @State private var countdownMeta: SessionMeta? = nil

    private let ages = Array(18...90)
    private let heights = Array(56...80)
    private let weights = Array(stride(from: 80, through: 300, by: 5))
    private let orientations = ["portrait", "landscape"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Participant") {
                    TextField("Participant ID", text: $participantID)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    TextField("Sex (e.g., M / F / Other)", text: $sexStr)
                        .textInputAutocapitalization(.none)

                    HStack {
                        Picker("Age (years)", selection: $ageYears) {
                            Text("—").tag(Int?.none)
                            ForEach(ages, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
                        }
                        Picker("Height (in)", selection: $heightIn) {
                            Text("—").tag(Int?.none)
                            ForEach(heights, id: \.self) { h in
                                Text(inchesToFeetIn(h)).tag(Int?.some(h))
                            }
                        }
                        Picker("Weight (lb)", selection: $weightLb) {
                            Text("—").tag(Int?.none)
                            ForEach(weights, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
                        }
                    }
                }

                Section("Test setup") {
                    Picker("Phone position", selection: $position) {
                        ForEach(PhonePosition.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    Picker("Condition", selection: $condition) {
                        ForEach(Condition.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    Picker("Orientation at start", selection: $orientationStr) {
                        ForEach(orientations, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("BAC (optional)") {
                    Picker("Method", selection: $bacMethod) {
                        ForEach(BACMethod.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    TextField("BAC value (e.g., 0.045)", text: $bacStr)
                        .keyboardType(.decimalPad)
                    TextField("Brand/Model", text: $bacBrandModel)
                        .textInputAutocapitalization(.never)
                    DatePicker(
                        "Measured at",
                        selection: nonOptionalDateBinding($bacMeasuredAt, default: Date()),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    TextField("Delay since last drink (min)", value: $bacDelayMinutes, format: .number)
                        .keyboardType(.numberPad)
                }

                Section("Notes") {
                    TextField("Optional notes…", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Sampling") {
                    HStack {
                        LabeledValue(title: "Target Hz", value: "\(app.settings.targetHz)")
                        LabeledValue(title: "Preroll (s)", value: "3")
                    }
                }

                Section {
                    Button {
                        startTapped()
                    } label: {
                        Text("Start").font(.headline).frame(maxWidth: .infinity)
                    }
                    .disabled(participantID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("GaitBAC")
            // IMPORTANT: item: not isPresented:, so content is never empty
            .fullScreenCover(item: $countdownMeta) { meta in
                CountdownView(meta: meta).environmentObject(app)
            }
        }
    }

    // MARK: - Actions

    private func startTapped() {
        let meta = SessionMeta(
            participant_id: participantID.trimmingCharacters(in: .whitespacesAndNewlines),
            sex: sexStr.isEmpty ? nil : sexStr,
            age_years: strOrNil(ageYears),
            height_in: strOrNil(heightIn),
            weight_kg: strOrNil(weightLb),

            position: position,
            condition: condition,

            bac: parseBAC(bacStr),
            bac_method: bacMethod,
            bac_brand_model: bacBrandModel.isEmpty ? nil : bacBrandModel,
            bac_measured_at: bacMeasuredAt,

            notes: notes.isEmpty ? nil : notes,

            device_model: DeviceInfo.model,
            ios_version: DeviceInfo.iosVersion,

            session_id: UUID().uuidString,
            sampling_hz_target: app.settings.targetHz,
            sampling_hz_measured: 0,

            duration_target_s: 360,
            duration_recorded_s: 0,
            preroll_s: 3,

            orientation_start: orientationStr,
            bac_delay_min: bacDelayMinutes.map { Double($0) },

            quality_flags: [:]
        )
        // Present by setting the item (no races)
        countdownMeta = meta
    }

    // MARK: - Helpers

    private func inchesToFeetIn(_ inches: Int) -> String {
        let ft = inches / 12
        let inRem = inches % 12
        return "\(ft)′\(inRem)″"
    }
}

// Convert optional numeric to optional String
private func strOrNil<T: LosslessStringConvertible>(_ v: T?) -> String? {
    guard let v = v else { return nil }
    return String(v)
}

// Parse BAC string into Double?
private func parseBAC(_ s: String) -> Double? {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return Double(trimmed.replacingOccurrences(of: ",", with: "."))
}

// Wrap Binding<Date?> into Binding<Date> for DatePicker
private func nonOptionalDateBinding(_ source: Binding<Date?>, default defaultValue: @autoclosure @escaping () -> Date) -> Binding<Date> {
    Binding<Date>(
        get: { source.wrappedValue ?? defaultValue() },
        set: { newValue in source.wrappedValue = newValue }
    )
}

