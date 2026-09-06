import SwiftUI

public struct StopPickerView: View {
    public let title: String
    @Binding public var selectedStopId: String
    @Binding public var selectedStopName: String

    @State private var searchText: String = ""
    @State private var searchResults: [TransitStop] = TransitStop.presetStops
    @State private var isSearching: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let departuresService: DeparturesServiceProtocol

    public init(
        title: String = "Select Stop",
        selectedStopId: Binding<String>,
        selectedStopName: Binding<String>,
        departuresService: DeparturesServiceProtocol = DeparturesAPIService()
    ) {
        self.title = title
        self._selectedStopId = selectedStopId
        self._selectedStopName = selectedStopName
        self.departuresService = departuresService
    }

    public var body: some View {
        List {
            if searchText.isEmpty {
                Section("Popular Stockholm Stations") {
                    ForEach(TransitStop.presetStops) { stop in
                        stopRow(stop)
                    }
                }
            } else {
                Section("Search Results") {
                    if isSearching && searchResults.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("Searching stations...")
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    } else if searchResults.isEmpty {
                        Text("No matching transit stops found.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(searchResults) { stop in
                            stopRow(stop)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: "Search station name (e.g. Odenplan)")
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
    }

    private func stopRow(_ stop: TransitStop) -> some View {
        Button {
            selectedStopId = stop.id
            selectedStopName = stop.name
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(stop.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    if let platform = stop.platform, !platform.isEmpty {
                        Text("Platform \(platform)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selectedStopId == stop.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .font(.body.weight(.bold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchResults = TransitStop.presetStops
            return
        }

        isSearching = true
        Task {
            do {
                let results = try await departuresService.searchStops(query: trimmed)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.searchResults = TransitStop.presetStops.filter {
                        $0.name.localizedCaseInsensitiveContains(trimmed)
                    }
                    self.isSearching = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        StopPickerView(
            selectedStopId: .constant("9021014001234000"),
            selectedStopName: .constant("Skanstull")
        )
    }
}

