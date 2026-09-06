import SwiftUI

public struct EditCommuteView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var commuteName: String
    @State private var outboundBoardingId: String
    @State private var outboundBoardingName: String
    @State private var outboundDestination: String
    @State private var outboundWalkMinutes: Int

    @State private var returnBoardingId: String
    @State private var returnBoardingName: String
    @State private var returnDestination: String
    @State private var returnWalkMinutes: Int

    @State private var syncReturnWithOutbound: Bool = true

    private let originalCommute: SavedCommute
    private let departuresService: DeparturesServiceProtocol
    private let onSave: (SavedCommute) -> Void

    public init(
        commute: SavedCommute,
        departuresService: DeparturesServiceProtocol = DeparturesAPIService(),
        onSave: @escaping (SavedCommute) -> Void
    ) {
        self.originalCommute = commute
        self.departuresService = departuresService
        self.onSave = onSave

        let outbound = commute.leg(for: .outbound)
        let returnLeg = commute.leg(for: .returnTrip)

        _commuteName = State(initialValue: commute.name)
        _outboundBoardingId = State(initialValue: outbound.stopId)
        _outboundBoardingName = State(initialValue: outbound.boardingStop)
        _outboundDestination = State(initialValue: outbound.destination)
        _outboundWalkMinutes = State(initialValue: outbound.walkingBufferMinutes)

        _returnBoardingId = State(initialValue: returnLeg.stopId)
        _returnBoardingName = State(initialValue: returnLeg.boardingStop)
        _returnDestination = State(initialValue: returnLeg.destination)
        _returnWalkMinutes = State(initialValue: returnLeg.walkingBufferMinutes)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Commute Name") {
                    TextField("Name (e.g. Office, Gym)", text: $commuteName)
                }

                Section("Outbound (To work)") {
                    NavigationLink {
                        StopPickerView(
                            title: "Select Boarding Stop",
                            selectedStopId: $outboundBoardingId,
                            selectedStopName: $outboundBoardingName,
                            departuresService: departuresService
                        )
                    } label: {
                        HStack {
                            Text("Boarding Stop")
                            Spacer()
                            Text(outboundBoardingName.isEmpty ? "Select stop" : outboundBoardingName)
                                .foregroundStyle(outboundBoardingName.isEmpty ? .secondary : .primary)
                        }
                    }

                    HStack {
                        Text("Destination")
                        Spacer()
                        TextField("Towards station/headsign", text: $outboundDestination)
                            .multilineTextAlignment(.trailing)
                    }

                    Stepper(
                        "Walking buffer: \(outboundWalkMinutes) min",
                        value: $outboundWalkMinutes,
                        in: 1...60
                    )
                }

                Section("Return Trip (Home)") {
                    Toggle("Sync reverse of outbound", isOn: $syncReturnWithOutbound)

                    if !syncReturnWithOutbound {
                        NavigationLink {
                            StopPickerView(
                                title: "Select Return Stop",
                                selectedStopId: $returnBoardingId,
                                selectedStopName: $returnBoardingName,
                                departuresService: departuresService
                            )
                        } label: {
                            HStack {
                                Text("Boarding Stop")
                                Spacer()
                                Text(returnBoardingName.isEmpty ? "Select stop" : returnBoardingName)
                                    .foregroundStyle(returnBoardingName.isEmpty ? .secondary : .primary)
                            }
                        }

                        HStack {
                            Text("Destination")
                            Spacer()
                            TextField("Towards station/headsign", text: $returnDestination)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Stepper(
                        "Walking buffer: \(returnWalkMinutes) min",
                        value: $returnWalkMinutes,
                        in: 1...60
                    )
                }
            }
            .navigationTitle("Edit Commute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCommute()
                    }
                    .disabled(outboundBoardingName.isEmpty)
                }
            }
        }
    }

    private func saveCommute() {
        let retBoardingId = syncReturnWithOutbound ? (lookupStopId(name: outboundDestination) ?? returnBoardingId) : returnBoardingId
        let retBoardingName = syncReturnWithOutbound ? outboundDestination : returnBoardingName
        let retDest = syncReturnWithOutbound ? outboundBoardingName : returnDestination

        let outboundLeg = CommuteLeg(
            stopId: outboundBoardingId,
            boardingStop: outboundBoardingName,
            destination: outboundDestination,
            walkingBufferMinutes: outboundWalkMinutes,
            routeFilter: originalCommute.leg(for: .outbound).routeFilter,
            directionId: "0",
            platform: originalCommute.leg(for: .outbound).platform,
            departures: []
        )

        let returnLeg = CommuteLeg(
            stopId: retBoardingId,
            boardingStop: retBoardingName,
            destination: retDest,
            walkingBufferMinutes: returnWalkMinutes,
            routeFilter: originalCommute.leg(for: .returnTrip).routeFilter,
            directionId: "1",
            platform: originalCommute.leg(for: .returnTrip).platform,
            departures: []
        )

        let updatedCommute = SavedCommute(
            id: originalCommute.id,
            name: commuteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Commute" : commuteName,
            origin: outboundBoardingName,
            destination: outboundDestination,
            directions: [
                .outbound: outboundLeg,
                .returnTrip: returnLeg
            ]
        )

        onSave(updatedCommute)
        dismiss()
    }

    private func lookupStopId(name: String) -> String? {
        TransitStop.presetStops.first {
            $0.name.localizedCaseInsensitiveContains(name)
        }?.id
    }
}

#Preview {
    EditCommuteView(commute: .officeFixture) { _ in }
}

