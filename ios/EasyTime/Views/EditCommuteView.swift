import SwiftUI

public struct EditCommuteView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var commuteName: String

    @State private var outboundBoardingId: String
    @State private var outboundBoardingName: String
    @State private var outboundDestId: String
    @State private var outboundDestination: String
    @State private var outboundWalkMinutes: Int

    @State private var returnBoardingId: String
    @State private var returnBoardingName: String
    @State private var returnDestId: String
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
        _outboundDestId = State(initialValue: returnLeg.stopId)
        _outboundDestination = State(initialValue: outbound.destination)
        _outboundWalkMinutes = State(initialValue: outbound.walkingBufferMinutes)

        _returnBoardingId = State(initialValue: returnLeg.stopId)
        _returnBoardingName = State(initialValue: returnLeg.boardingStop)
        _returnDestId = State(initialValue: outbound.stopId)
        _returnDestination = State(initialValue: returnLeg.destination)
        _returnWalkMinutes = State(initialValue: returnLeg.walkingBufferMinutes)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Commute Name") {
                    TextField("Name (e.g. Office, Home)", text: $commuteName)
                }

                Section("Outbound Journey (To work)") {
                    NavigationLink {
                        StopPickerView(
                            title: "Select Boarding Station",
                            selectedStopId: $outboundBoardingId,
                            selectedStopName: $outboundBoardingName,
                            departuresService: departuresService
                        )
                    } label: {
                        HStack {
                            Text("From (Boarding)")
                            Spacer()
                            Text(outboundBoardingName.isEmpty ? "Select Station" : outboundBoardingName)
                                .foregroundStyle(outboundBoardingName.isEmpty ? .secondary : .primary)
                                .fontWeight(.medium)
                        }
                    }

                    NavigationLink {
                        StopPickerView(
                            title: "Select Destination Station",
                            selectedStopId: $outboundDestId,
                            selectedStopName: $outboundDestination,
                            departuresService: departuresService
                        )
                    } label: {
                        HStack {
                            Text("To (Destination)")
                            Spacer()
                            Text(outboundDestination.isEmpty ? "Select Station" : outboundDestination)
                                .foregroundStyle(outboundDestination.isEmpty ? .secondary : .primary)
                                .fontWeight(.medium)
                        }
                    }

                    Stepper(
                        "Walking buffer: \(outboundWalkMinutes) min",
                        value: $outboundWalkMinutes,
                        in: 1...60
                    )
                }

                Section {
                    Button {
                        swapLocations()
                    } label: {
                        Label("Swap Outbound & Return Stations", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline.weight(.medium))
                    }
                }

                Section("Return Journey (Home)") {
                    Toggle("Auto-reverse from Outbound", isOn: $syncReturnWithOutbound)

                    if syncReturnWithOutbound {
                        HStack {
                            Text("From (Boarding)")
                            Spacer()
                            Text(outboundDestination.isEmpty ? "Same as Outbound To" : outboundDestination)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("To (Destination)")
                            Spacer()
                            Text(outboundBoardingName.isEmpty ? "Same as Outbound From" : outboundBoardingName)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        NavigationLink {
                            StopPickerView(
                                title: "Select Return Boarding",
                                selectedStopId: $returnBoardingId,
                                selectedStopName: $returnBoardingName,
                                departuresService: departuresService
                            )
                        } label: {
                            HStack {
                                Text("From (Boarding)")
                                Spacer()
                                Text(returnBoardingName.isEmpty ? "Select Station" : returnBoardingName)
                                    .foregroundStyle(returnBoardingName.isEmpty ? .secondary : .primary)
                                    .fontWeight(.medium)
                            }
                        }

                        NavigationLink {
                            StopPickerView(
                                title: "Select Return Destination",
                                selectedStopId: $returnDestId,
                                selectedStopName: $returnDestination,
                                departuresService: departuresService
                            )
                        } label: {
                            HStack {
                                Text("To (Destination)")
                                Spacer()
                                Text(returnDestination.isEmpty ? "Select Station" : returnDestination)
                                    .foregroundStyle(returnDestination.isEmpty ? .secondary : .primary)
                                    .fontWeight(.medium)
                            }
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
                    .disabled(outboundBoardingName.isEmpty || outboundDestination.isEmpty)
                }
            }
        }
    }

    private func swapLocations() {
        let tempId = outboundBoardingId
        let tempName = outboundBoardingName

        outboundBoardingId = outboundDestId
        outboundBoardingName = outboundDestination

        outboundDestId = tempId
        outboundDestination = tempName
    }

    private func saveCommute() {
        let retBoardingId: String
        let retBoardingName: String
        let retDest: String

        if syncReturnWithOutbound {
            retBoardingId = outboundDestId.isEmpty ? (lookupStopId(name: outboundDestination) ?? returnBoardingId) : outboundDestId
            retBoardingName = outboundDestination
            retDest = outboundBoardingName
        } else {
            retBoardingId = returnBoardingId
            retBoardingName = returnBoardingName
            retDest = returnDestination
        }

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
