//
//  ProjectDetailView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/24/25.
//

import SwiftUI
import SwiftData

// MARK: - Project Detail (tabbed skeleton)

struct ProjectDetailView: View {
    @Bindable var project: Item

    // Required when using @Bindable in a custom init.
    init(project: Item) { self._project = Bindable(project) }

    var body: some View {
        TabView {
            // 1) Scan
            ScanTab(project: project)
                .tabItem { Label("Scan", systemImage: "dot.radiowaves.left.and.right") }

            // 2) Fixtures
            FixturesTab(project: project)
                .tabItem { Label("Fixtures", systemImage: "lightbulb") }

            // 3) Rooms
            RoomsTab(project: project)
                .tabItem { Label("Rooms", systemImage: "square.grid.2x2") }

            // 4) Export
            ExportTab(project: project)
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }

            // 5) Project Settings
            ProjectSettingsTab(project: project)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}




// --- Step 5c: Fixtures tab with + button & sheet ---
private struct FixturesTab: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Item
    @State private var showingAdd = false
    // 11f: editing + delete state
    @State private var editingFixture: Fixture?
    @State private var showDeleteConfirm = false
    @State private var pendingDelete: Fixture?

    // --- 5e: Filters state ---
    @State private var filterAddressText: String = ""   // e.g. "0-10", "12", "-20", "30-"
    @State private var filterGroupsMask: UInt16 = 0     // any-of groups

    // Computed filtered list
    private var filteredFixtures: [Fixture] {
        var list = project.fixtures

        // Address filter
        let (minAddr, maxAddr) = parseAddressRange(filterAddressText)
        if let min = minAddr { list = list.filter { $0.shortAddress >= min } }
        if let max = maxAddr { list = list.filter { $0.shortAddress <= max } }

        // Groups filter (match any selected)
        if filterGroupsMask != 0 {
            list = list.filter { ($0.groups & filterGroupsMask) != 0 }
        }

        // nice, stable ordering
        return list.sorted {
            if $0.shortAddress != $1.shortAddress { return $0.shortAddress < $1.shortAddress }
            return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
    }

    var body: some View {
        List {
            if project.fixtures.isEmpty {
                ContentUnavailableView {
                    Label("No fixtures yet", systemImage: "lightbulb.slash")
                } description: {
                    Text("Add fixtures manually while we stub commissioning.")
                } actions: {
                    Button("Add Fixture") { showingAdd = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                // --- 5e: Filters UI (always visible when list has items) ---
                FixtureFiltersView(
                    addressText: $filterAddressText,
                    groupsMask: $filterGroupsMask,
                    onClear: { filterAddressText = ""; filterGroupsMask = 0 }
                )

                // header
                HStack {
                    Text("Label").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Addr").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    Spacer()
                    Text("Groups").font(.caption).foregroundStyle(.secondary).monospaced()
                    Spacer()
                    Text("Room").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Last Seen").font(.caption).foregroundStyle(.secondary)
                }
                .listRowSeparator(.hidden)

                if filteredFixtures.isEmpty {
                    ContentUnavailableView {
                        Label("No results", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("Try clearing or adjusting filters.")
                    } actions: {
                        Button("Clear Filters") { filterAddressText = ""; filterGroupsMask = 0 }
                    }
                } else {
                    ForEach(filteredFixtures, id: \.persistentModelID) { f in
                        FixtureRow(fixture: f)
                            // Tap to edit
                            .onTapGesture { editingFixture = f }

                            // Leading swipe: Edit
                            .swipeActions(edge: .leading) {
                                Button("Edit") { editingFixture = f }
                            }

                            // Trailing swipe: Delete (with confirmation)
                            .swipeActions {
                                Button(role: .destructive) {
                                    pendingDelete = f
                                    showDeleteConfirm = true
                                } label: {
                                    Text("Delete")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Fixtures")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Fixture", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddFixtureSheet(project: project)
                .presentationDetents([.medium, .large])
                .environment(\.modelContext, modelContext)
        }
        // 11f: Edit Fixture sheet (present when editingFixture != nil)
        // 11f: Edit Fixture sheet (present when editingFixture != nil)
        .sheet(
            isPresented: Binding(
                get: { editingFixture != nil },
                set: { if !$0 { editingFixture = nil } }
            )
        ) {
            if let fx = editingFixture {
                EditFixtureSheet(fixture: fx)
                    .environment(\.modelContext, modelContext)
                    .presentationDetents([.medium, .large])
            }
        }
        // 11f: Delete confirmation dialog
        .confirmationDialog("Delete Fixture?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let fx = pendingDelete else { return }
                Task { @MainActor in
                    do {
                        try await FixtureSyncService.shared.delete(fx, context: modelContext)
                    } catch {
                        // Silence harmless deletes of non-existent/unauthorized docs
                        let ns = error as NSError
                        let domain = ns.domain
                        let code = ns.code
                        let isFirestore = (domain == "FIRFirestoreErrorDomain"
                                           || domain == "com.google.firebase.firestore"
                                           || domain == "FirestoreErrorDomain")
                        let ignorable = isFirestore && (code == 5 /* notFound */ || code == 7 /* permissionDenied */)
                        if !ignorable {
                            print("[Fixture] delete error: \(error.localizedDescription)")
                        }
                    }
                }
                
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Deleting a fixture will NOT change its address on the device. To change the address, put the fixture in commission mode and rescan.")
        }
    }
}

// Row for one fixture (keep your existing copy if present)
private struct FixtureRow: View {
    let fixture: Fixture

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(fixture.label).lineLimit(1).layoutPriority(1)
            Spacer(minLength: 8)
            Text("\(fixture.shortAddress)").monospacedDigit()
            Spacer(minLength: 8)
            Text(groupsString(fixture.groups)).monospaced().foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(fixture.room?.isEmpty == false ? fixture.room! : "—").foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(lastSeenString(fixture.commissionedAt)).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

// --- 5e: Filters Section ---
private struct FixtureFiltersView: View {
    @Binding var addressText: String
    @Binding var groupsMask: UInt16
    var onClear: () -> Void

    var body: some View {
        Section {
            // Address range
            VStack(alignment: .leading, spacing: 6) {
                TextField("Address (e.g., 0-10, 12, -20, 30-)", text: $addressText)
                    .textInputAutocapitalization(.never)
                Text(addressHint(addressText))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Groups (match any)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Groups (match any)")
                    if groupsMask != 0 {
                        Text("• \(selectedGroupList(groupsMask))")
                            .foregroundStyle(.secondary)
                    }
                }
                GroupsGrid(mask: $groupsMask)
            }

            // Clear
            HStack {
                Spacer()
                Button("Clear Filters", role: .cancel) { onClear() }
                    .disabled(addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && groupsMask == 0)
            }
        } header: {
            Text("Filters")
        }
    }
}

// Helpers (keep only one copy in this file)
private func groupsString(_ mask: UInt16) -> String {
    var out: [String] = []
    for i in 0..<16 {
        let bit: UInt16 = 1 << UInt16(i)
        if (mask & bit) != 0 { out.append("G\(i)") }
    }
    return out.isEmpty ? "—" : out.joined(separator: ",")
}

private func lastSeenString(_ date: Date?) -> String {
    guard let d = date else { return "—" }
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .none
    return fmt.string(from: d)
}

// --- 5e Helpers ---
private func parseAddressRange(_ text: String) -> (Int?, Int?) {
    // Normalize weird hyphens/en-dashes and spaces
    var t = text.replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "—", with: "-")
                .replacingOccurrences(of: "−", with: "-")
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

    if t.isEmpty { return (nil, nil) }

    // Single number => exact match
    if let v = Int(t) {
        let c = clampAddress(v)
        return (c, c)
    }

    // Range variants: "a-b", "-b", "a-"
    let parts = t.split(separator: "-", omittingEmptySubsequences: false)
    let left  = parts.indices.contains(0) ? String(parts[0]) : ""
    let right = parts.indices.contains(1) ? String(parts[1]) : ""

    var minVal: Int? = left.isEmpty  ? nil : Int(left).map(clampAddress)
    var maxVal: Int? = right.isEmpty ? nil : Int(right).map(clampAddress)

    // If both present and swapped, fix order
    if let minV = minVal, let maxV = maxVal, minV > maxV {
        swap(&minVal, &maxVal)
    }
    return (minVal, maxVal)
}

private func clampAddress(_ v: Int) -> Int { max(0, min(63, v)) }

private func selectedGroupList(_ mask: UInt16) -> String {
    var items: [String] = []
    for i in 0..<16 {
        let bit: UInt16 = 1 << UInt16(i)
        if (mask & bit) != 0 { items.append("G\(i)") }
    }
    return items.joined(separator: ",")
}

private func addressHint(_ text: String) -> String {
    let (minA, maxA) = parseAddressRange(text)
    switch (minA, maxA) {
    case (nil, nil): return "Showing all addresses 0–63"
    case let (m?, n?): return "Showing \(m)–\(n)"
    case let (m?, nil): return "Showing \(m)–63"
    case let (nil, n?): return "Showing 0–\(n)"
    }
}

// --- Step 5c: Add Fixture sheet (Canvas‑friendly) ---
private struct AddFixtureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var project: Item

    @State private var label: String = ""
    @State private var address: Int = 0                // 0…63
    @State private var groupsMask: UInt16 = 0          // G0…G15 bitmask
    @State private var room: String = ""
    @State private var dtType: String = ""             // "", "DT6", "DT8", "D4i"

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Required") {
                    TextField("Label", text: $label)
                        .textInputAutocapitalization(.words)
                    Picker("Address", selection: $address) {
                        ForEach(0..<64, id: \.self) { Text("\($0)") }
                    }
                }

                Section("Groups") {
                    GroupsGrid(mask: $groupsMask)
                }

                Section("Optional") {
                    TextField("Room", text: $room)
                        .textInputAutocapitalization(.words)
                    Picker("DT Type", selection: $dtType) {
                        Text("—").tag("")
                        Text("DT6").tag("DT6")
                        Text("DT8").tag("DT8")
                        Text("D4i").tag("D4i")
                    }
                }
            }
            .navigationTitle("Add Fixture")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
                        let fixture = Fixture(
                            label: trimmed,
                            shortAddress: address,
                            groups: groupsMask,
                            room: room.nilIfEmpty,
                            serial: nil,
                            dtTypeRaw: dtType.nilIfEmpty,
                            commissionedAt: nil,
                            notes: nil
                            // no need to pass `project:` here
                        )

                        // Link + insert in one shot
                        project.fixtures.append(fixture)

                        // Persist and refresh UI
                        try? ctx.save()

                        // 11e-3: push the new fixture to Firestore
                        Task { @MainActor in
                            do {
                                try await FixtureSyncService.shared.push(fixture, context: ctx)
                                #if DEBUG
                                print("[FixSync] Pushed fixture \(fixture.label)")
                                #endif
                            } catch {
                                #if DEBUG
                                print("[FixSync] Push failed: \(error.localizedDescription)")
                                #endif
                            }
                        }

                        dismiss()

                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// 11f: Edit Fixture (label & room only; other fields are read-only)
private struct EditFixtureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var fixture: Fixture

    // Draft fields so Cancel truly discards edits
    @State private var draftLabel: String = ""
    @State private var draftRoom: String = ""
    @State private var didLoadDraft = false


    init(fixture: Fixture) {
        self._fixture = Bindable(fixture)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Editable") {
                    TextField("Label", text: $draftLabel)
                        .textInputAutocapitalization(.words)

                    TextField("Room", text: $draftRoom)
                        .keyboardType(.default)                  // ensures space bar is present
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                }
                .onAppear {
                    guard !didLoadDraft else { return }
                    draftLabel = fixture.label
                    draftRoom  = fixture.room ?? ""
                    didLoadDraft = true
                }


                Section("Read‑only") {
                    HStack { Text("Address"); Spacer(); Text("\(fixture.shortAddress)").monospacedDigit() }
                    HStack { Text("Groups");  Spacer(); Text(groupsString(fixture.groups)).monospaced() }
                    HStack { Text("Serial");  Spacer(); Text(fixture.serial ?? "—").foregroundStyle(.secondary).textSelection(.enabled) }
                    HStack { Text("DT Type"); Spacer(); Text(fixture.dtTypeRaw ?? "—").foregroundStyle(.secondary) }
                }

                Section(footer: Text("Editing label or room does not change the physical device configuration.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Edit Fixture")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Copy drafts → model
                        let newLabel = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                        let newRoom  = draftRoom.trimmingCharacters(in: .whitespacesAndNewlines)
                        fixture.label = newLabel
                        fixture.room  = newRoom.isEmpty ? nil : newRoom

                        // Persist local changes
                        try? ctx.save()

                        // Push to Firestore
                        Task { @MainActor in
                            do {
                                try await FixtureSyncService.shared.push(fixture, context: ctx)
                            } catch {
                                print("[Fixture] push error: \(error.localizedDescription)")
                            }
                        }
                        dismiss()
                    }

                }
            }
        }
    }
}


// Compact chip grid for G0…G15
private struct GroupsGrid: View {
    @Binding var mask: UInt16
    private let columns = [GridItem(.adaptive(minimum: 52, maximum: 72))]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(0..<16, id: \.self) { i in
                let on = (mask & (1 << UInt16(i))) != 0
                Button {
                    let bit: UInt16 = 1 << UInt16(i)
                    if (mask & bit) != 0 { mask &= ~bit } else { mask |= bit }
                } label: {
                    Text("G\(i)")
                        .font(.callout)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(on ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(on ? Color.accentColor : Color.secondary.opacity(0.35))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// tiny convenience for Optional fields
private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

// MARK: - Tabs (placeholders for now)

private struct ScanTab: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var project: Item
    
    @AppStorage("commissioningMode") private var commissioningMode: CommissioningMode = .simulated

    // Hold both implementations; we’ll route calls through `client` later.
    private let simClient = SimCommissioningClient()
    private let bleClient = BLECommissioningClient()

    // Selected client for the current mode. (No behavior uses it yet in 7a.)
    private var client: any CommissioningClient {
        commissioningMode == .simulated ? simClient : bleClient
    }

    @State private var isScanning = false
    @State private var results: [SimDevice] = []
    @State private var timer: Timer?

    // 6b — single-device commissioning
    @State private var pendingDevice: SimDevice?

    // 6c — identify pulse
    @State private var identifying: Set<String> = []
    @State private var identifyPhase: Bool = false
    @State private var identifyTimers: [String: Timer] = [:]

    // 6d — bulk commissioning
    @State private var showingBulk = false
    @State private var bulkResultMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label(isScanning ? "Scanning…" : "Idle",
                      systemImage: isScanning ? "dot.radiowaves.left.and.right" : "pause.circle")
                Spacer()
                Text("\(results.count) found").foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            List {
                if results.isEmpty {
                    ContentUnavailableView {
                        Label(isScanning ? "Scanning…" : "No devices yet", systemImage: "lightbulb")
                    } description: {
                        Text(isScanning
                             ? "Listening for Pod4 fixtures…"
                             : "Tap Start Scan to simulate nearby fixtures.")
                    } actions: {
                        if !isScanning {
                            Button("Populate Demo Results") { populateDemo() }
                        }
                    }
                } else {
                    ForEach(results) { dev in
                        let isIdentifying = identifying.contains(dev.id)

                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dev.name).font(.headline)
                                Text(dev.subtitle).font(.caption).foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            HStack(spacing: 8) {
                                // Identify
                                Button {
                                    identify(dev)
                                } label: {
                                    Label(isIdentifying ? "Identifying…" : "Identify",
                                          systemImage: "lightbulb.max")
                                }
                                .buttonStyle(.bordered)
                                .disabled(isIdentifying)

                                // Commission…
                                Button {
                                    pendingDevice = dev
                                } label: {
                                    Label("Commission…", systemImage: "checkmark.seal")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                        // Pulse while identifying
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isIdentifying
                                      ? Color.accentColor.opacity(identifyPhase ? 0.24 : 0.10)
                                      : Color.clear)
                        )
                        .scaleEffect(isIdentifying && identifyPhase ? 1.01 : 1.0)
                        .animation(.easeInOut(duration: 0.18), value: identifyPhase)
                        .overlay(alignment: .topTrailing) {
                            Text("Mode: \(commissioningMode.displayName)")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .accessibilityLabel("Commissioning mode \(commissioningMode.displayName)")
                                .padding(12)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingBulk = true
                } label: {
                    Label("Bulk…", systemImage: "square.stack.3d.up")
                }
                .disabled(results.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isScanning {
                    Button { stopScan() } label: { Label("Stop", systemImage: "stop.circle") }
                } else {
                    Button { startScan() } label: { Label("Start Scan", systemImage: "play.circle") }
                }
            }
        }
        .onDisappear {
            stopScan()
            stopAllIdentifications()
        }
        // Single-device commissioning sheet (6b)
        .sheet(item: $pendingDevice) { dev in
            CommissionDeviceSheet(
                project: project,
                device: dev,
                onCommissioned: { serial in
                    results.removeAll { $0.id == serial }
                }
            )
            .environment(\.modelContext, ctx)
            .presentationDetents([.medium, .large])
        }
        // Bulk commissioning sheet (6d)
        .sheet(isPresented: $showingBulk) {
            BulkCommissionSheet(
                project: project,
                devices: results,
                onDone: { commissionedSerials, summary in
                    // Remove commissioned from the list, show summary
                    let commissioned = Set(commissionedSerials)
                    results.removeAll { commissioned.contains($0.id) }
                    bulkResultMessage = summary
                }
            )
            .environment(\.modelContext, ctx)
            .presentationDetents([.medium, .large])
        }
        // Simple summary alert after bulk
        .alert("Bulk Commission", isPresented: Binding(
            get: { bulkResultMessage != nil },
            set: { if !$0 { bulkResultMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(bulkResultMessage ?? "")
        }
    }

    // MARK: - Scan controls

    private func startScan() {
        results.removeAll()
        isScanning = true
        timer?.invalidate()
        var steps = 0
        let t = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { t in
            steps += 1
            results.append(SimDevice.random(excluding: Set(results.map { $0.serial })))
            if steps >= 6 {
                isScanning = false
                t.invalidate()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopScan() {
        isScanning = false
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Identify (6c)

    private func identify(_ dev: SimDevice) {
        let id = dev.id
        identifyTimers[id]?.invalidate()
        identifyTimers[id] = nil

        identifying.insert(id)

        var pulsesRemaining = 8 // ~1.6s @ 0.2s steps
        let t = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { t in
            withAnimation(.easeInOut(duration: 0.18)) {
                identifyPhase.toggle()
            }
            pulsesRemaining -= 1
            if pulsesRemaining <= 0 {
                t.invalidate()
                identifying.remove(id)
                identifyTimers[id] = nil
                if identifying.isEmpty { identifyPhase = false }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        identifyTimers[id] = t
    }

    private func stopAllIdentifications() {
        identifyTimers.values.forEach { $0.invalidate() }
        identifyTimers.removeAll()
        identifying.removeAll()
        identifyPhase = false
    }

    // MARK: - Demo

    private func populateDemo() {
        results = (0..<4).map { _ in SimDevice.random(excluding: Set(results.map { $0.serial })) }
    }

    // ============================================================
    // MARK: - NESTED SHEETS
    // ============================================================

    // Shared helper visible to both nested sheets
    private static func nextAvailableAddress(in project: Item) -> Int? {
        let used = Set(project.fixtures.map { $0.shortAddress })
        for addr in 0...63 where !used.contains(addr) { return addr }
        return nil
    }
    
    // --- Step 6b: Commission Device sheet (nested) ---
    private struct CommissionDeviceSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(\.modelContext) private var ctx

        @Bindable var project: Item
        let device: SimDevice
        var onCommissioned: (String) -> Void

        // Prefill fields
        @State private var label: String
        @State private var address: Int
        @State private var groupsMask: UInt16 = 0
        @State private var room: String = ""
        @State private var dtType: String

        init(project: Item, device: SimDevice, onCommissioned: @escaping (String) -> Void) {
            self._project = Bindable(project)
            self.device = device
            self.onCommissioned = onCommissioned
            // Defaults
            _label = State(initialValue: device.name)
            let next = ScanTab.nextAvailableAddress(in: project) ?? 0
            _address = State(initialValue: next)
            _dtType = State(initialValue: device.dtTypeRaw)
        }

        // Validation
        private var usedAddresses: Set<Int> { Set(project.fixtures.map { $0.shortAddress }) }
        private var addressInUse: Bool { usedAddresses.contains(address) }
        private var addressOutOfRange: Bool { !(0...63).contains(address) }
        private var canSave: Bool {
            !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !addressOutOfRange
            && !addressInUse
        }
        private var nextFree: Int? { ScanTab.nextAvailableAddress(in: project) }

        var body: some View {
            NavigationStack {
                Form {
                    Section("Required") {
                        TextField("Label", text: $label)
                            .textInputAutocapitalization(.words)

                        Stepper(value: $address, in: 0...63) {
                            HStack {
                                Text("Address")
                                Spacer()
                                Text("\(address)").monospacedDigit()
                            }
                        }

                        if addressOutOfRange {
                            Text("Address must be between 0 and 63.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else if addressInUse {
                            Text("Address \(address) is already in use.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        if let nf = nextFree, nf != address {
                            Button("Use Next Free (\(nf))") { address = nf }
                        }
                    }

                    Section("Groups") {
                        GroupsGrid(mask: $groupsMask)
                    }

                    Section("Optional") {
                        TextField("Room", text: $room)
                            .textInputAutocapitalization(.words)

                        Picker("DT Type", selection: $dtType) {
                            Text("—").tag("")
                            Text("DT6").tag("DT6")
                            Text("DT8").tag("DT8")
                            Text("D4i").tag("D4i")
                        }
                        HStack {
                            Text("Serial")
                            Spacer()
                            Text(device.serial)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .navigationTitle("Commission Device")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
                            let fixture = Fixture(
                                label: trimmed,
                                shortAddress: address,
                                groups: groupsMask,
                                room: room.nilIfEmpty,
                                serial: device.serial,
                                dtTypeRaw: dtType.nilIfEmpty,
                                commissionedAt: Date(),
                                notes: "Commissioned via simulator"
                            )
                            project.fixtures.append(fixture)
                            try? ctx.save()

                            // Push to Firestore (async, best‑effort)
                            Task { @MainActor in
                                do {
                                    try await FixtureSyncService.shared.push(fixture, context: ctx)
                                } catch {
                                    #if DEBUG
                                    print("[FixSync] Commission push failed: \(error.localizedDescription)")
                                    #endif
                                }
                            }

                            onCommissioned(device.serial)
                            dismiss()

                        }
                        .disabled(!canSave)
                    }
                }
            }
        }

        // Compute the next free short address 0…63 in this project
        private static func nextAvailableAddress(in project: Item) -> Int? {
            let used = Set(project.fixtures.map { $0.shortAddress })
            for addr in 0...63 where !used.contains(addr) { return addr }
            return nil
        }
    }

    // --- Step 6d: Bulk commission sheet (nested) ---
    private struct BulkCommissionSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(\.modelContext) private var ctx

        @Bindable var project: Item
        let devices: [SimDevice]                // visible devices to commission
        var onDone: (_ commissionedSerials: [String], _ summary: String) -> Void

        @State private var room: String = ""
        @State private var groupsMask: UInt16 = 0
        @State private var startAddress: Int

        init(project: Item, devices: [SimDevice],
             onDone: @escaping (_ commissionedSerials: [String], _ summary: String) -> Void) {
            self._project = Bindable(project)
            self.devices = devices
            self.onDone = onDone
            _startAddress = State(initialValue: ScanTab.nextAvailableAddress(in: project) ?? 0)
        }

        private var usedAddrs: Set<Int> { Set(project.fixtures.map { $0.shortAddress }) }
        private var availableCount: Int { max(0, 64 - usedAddrs.count) }
        private var willCommissionCount: Int { min(availableCountFromStart(), devices.count) }

        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        HStack {
                            Text("Devices visible")
                            Spacer()
                            Text("\(devices.count)")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Available addresses")
                            Spacer()
                            Text("\(availableCount)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Defaults") {
                        Stepper(value: $startAddress, in: 0...63) {
                            HStack {
                                Text("Start Address")
                                Spacer()
                                Text("\(startAddress)").monospacedDigit()
                            }
                        }
                        GroupsGrid(mask: $groupsMask)
                        TextField("Room (optional)", text: $room)
                            .textInputAutocapitalization(.words)
                    }

                    if devices.count > 0 {
                        Section {
                            Text("Will commission up to **\(willCommissionCount)** of **\(devices.count)** devices based on free addresses from \(startAddress) to 63.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Bulk Commission")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Commission All") {
                            let (serials, committed, skipped) = performBulkCommission()
                            let nextFree = ScanTab.nextAvailableAddress(in: project).map { "\($0)" } ?? "—"
                            let summary = "Commissioned \(committed) of \(devices.count). Skipped \(skipped). Next free: \(nextFree)."
                            onDone(serials, summary)
                            dismiss()
                        }
                        .disabled(devices.isEmpty || willCommissionCount == 0)
                    }
                }
            }
        }

        private func availableCountFromStart() -> Int {
            var seen = usedAddrs
            var addr = startAddress
            var count = 0
            while addr <= 63 {
                if !seen.contains(addr) {
                    count += 1
                    seen.insert(addr)
                }
                addr += 1
            }
            return count
        }

        /// Commission sequentially from `startAddress`, skipping used; no wrap-around.
        /// Returns: (commissionedSerials, committedCount, skippedCount)
        private func performBulkCommission() -> ([String], Int, Int) {
            var commissionedSerials: [String] = []
            var used = usedAddrs
            var addr = startAddress
            var committed = 0

            for dev in devices {
                // next free address
                while addr <= 63, used.contains(addr) { addr += 1 }
                guard addr <= 63 else { break } // out of space

                let fx = Fixture(
                    label: dev.name,
                    shortAddress: addr,
                    groups: groupsMask,
                    room: room.nilIfEmpty,
                    serial: dev.serial,
                    dtTypeRaw: dev.dtTypeRaw,
                    commissionedAt: Date(),
                    notes: "Bulk commissioned via simulator"
                )
                project.fixtures.append(fx)
                used.insert(addr)
                commissionedSerials.append(dev.serial)
                committed += 1

                // Push to Firestore (async, best‑effort)
                Task { @MainActor in
                    do {
                        try await FixtureSyncService.shared.push(fx, context: ctx)
                    } catch {
                        #if DEBUG
                        print("[FixSync] Bulk commission push failed for \(dev.serial): \(error.localizedDescription)")
                        #endif
                    }
                }

                addr += 1

            }

            if committed > 0 {
                try? ctx.save()
            }

            let skipped = devices.count - committed
            return (commissionedSerials, committed, skipped)
        }
    }
}


// MARK: - Simulation types & helpers

private struct SimDevice: Identifiable, Hashable {
    var id: String { serial }
    let name: String       // e.g., "Pod4 7F3A"
    let serial: String     // e.g., "C7-7F3A-219B"
    let dtTypeRaw: String  // "DT6" | "DT8" | "D4i"
    let rssi: Int          // -30…-90

    var subtitle: String {
        "\(dtTypeRaw)  •  S/N \(serial)  •  RSSI \(rssi)"
    }

    static func random(excluding existing: Set<String>) -> SimDevice {
        var serial: String
        repeat {
            serial = String(
                format: "%02X-%04X-%04X",
                Int.random(in: 0...255),
                Int.random(in: 0...0xFFFF),
                Int.random(in: 0...0xFFFF)
            )
        } while existing.contains(serial)
        let nick = String(serial.split(separator: "-")[1].suffix(4))
        let dt = ["DT6", "DT8", "D4i"].randomElement()!
        let rssi = Int.random(in: -82 ... -38)
        let name = "Pod4 \(nick)"
        return SimDevice(name: name, serial: serial, dtTypeRaw: dt, rssi: rssi)
    }
}

/// First free short address 0…63 (or nil if full)
private func nextAvailableAddress(for project: Item) -> Int? {
    let used = Set(project.fixtures.map { $0.shortAddress })
    for addr in 0...63 where !used.contains(addr) {
        return addr
    }
    return nil
}


// --- Step 5d: Rooms tab (grouped by room) ---
private struct RoomsTab: View {
    @Bindable var project: Item

    var body: some View {
        List {
            if project.fixtures.isEmpty {
                ContentUnavailableView {
                    Label("Rooms view", systemImage: "square.grid.2x2")
                } description: {
                    Text("Add fixtures to see them grouped by room.")
                }
            } else {
                ForEach(roomGroups(for: project)) { group in
                    Section {
                        ForEach(group.fixtures, id: \.persistentModelID) { f in
                            FixtureRow(fixture: f)   // Reuse the existing row
                        }
                    } header: {
                        HStack {
                            Text(group.name)
                            Spacer()
                            Text("\(group.fixtures.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Rooms")
    }
}

// Identifiable wrapper so ForEach is happy
private struct RoomGroup: Identifiable {
    var name: String
    var fixtures: [Fixture]
    var id: String { name }
}

// Helper to compute groups & sorting (kept private in this file)
private func roomGroups(for project: Item) -> [RoomGroup] {
    // Normalize room names; empty/nil => "Unassigned"
    let normalized = Dictionary(grouping: project.fixtures) { (f: Fixture) -> String in
        let t = (f.room ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Unassigned" : t
    }

    // Sort fixtures within a room: by address, then label
    func fixtureSort(_ a: Fixture, _ b: Fixture) -> Bool {
        if a.shortAddress != b.shortAddress { return a.shortAddress < b.shortAddress }
        return a.label.localizedCaseInsensitiveCompare(b.label) == .orderedAscending
    }

    // Sort room sections: alphabetical, "Unassigned" last
    let roomNames = normalized.keys.sorted { a, b in
        if a == "Unassigned" { return false }
        if b == "Unassigned" { return true }
        return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
    }

    return roomNames.map { name in
        RoomGroup(name: name, fixtures: (normalized[name] ?? []).sorted(by: fixtureSort))
    }
}

private struct ExportTab: View {
    let project: Item   // read-only is fine; we aren’t editing here

    var body: some View {
        ExportView(project: project)
    }
}

// MARK: - Project Settings (edit fields from the wizard)

private struct ProjectSettingsTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var project: Item

    // Segmented control for control system
    @State private var csIndex: Int
    private let options = ["control4", "crestron", "lutron"]

    init(project: Item) {
        self._project = Bindable(project)
        self._csIndex = State(initialValue: Self.index(for: project.controlSystemRaw))
    }

    private static func index(for raw: String?) -> Int {
        switch raw?.lowercased() {
        case "crestron": return 1
        case "lutron":   return 2
        default:         return 0 // control4
        }
    }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Project name", text: $project.title)
                    .onChange(of: project.title) { _ in
                        AutosaveCenter.shared.touch(project, context: context)
                    }
                    .textInputAutocapitalization(.words)
            }

            Section("Contact") {
                TextField("First name", text: Binding(
                    get: { project.contactFirstName ?? "" },
                    set: { project.contactFirstName = $0.isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.words)

                TextField("Last name", text: Binding(
                    get: { project.contactLastName ?? "" },
                    set: { project.contactLastName = $0.isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.words)
            }

            Section("Site") {
                TextField("Site address", text: Binding(
                    get: { project.siteAddress ?? "" },
                    set: { project.siteAddress = $0.isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.words)
            }

            Section("Control system") {
                Picker("Control system", selection: $csIndex) {
                    Text("Control4").tag(0)
                    Text("Crestron").tag(1)
                    Text("Lutron").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: csIndex) { i in
                    project.controlSystemRaw = options[i]
                }
            }

            Section {
                Button("Save Changes") {
                    try? context.save()
                }
            }
        }
    }
}

#if DEBUG
private struct ProjectDetailPreviewHost: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\Item.createdAt, order: .reverse)]) private var items: [Item]

    var body: some View {
        let project = items.first ?? seed()
        return NavigationStack { ProjectDetailView(project: project) }
    }

    @MainActor
    private func seed() -> Item {
        let p = Item(title: "Smith Residence")
        p.createdAt = Date()
        p.contactFirstName = "Alex"
        p.contactLastName  = "Smith"
        p.siteAddress      = "123 Ocean Ave"
        p.controlSystemRaw = "Lutron QS"
        ctx.insert(p)

        let f1 = Fixture(label: "Kitchen Cans", shortAddress: 3, groups: 1)
        f1.room = "Kitchen"; f1.serial = "SN-001"; f1.dtTypeRaw = "DT8"; f1.project = p
        ctx.insert(f1)

        let f2 = Fixture(label: "Dining Pendants", shortAddress: 7, groups: 2)
        f2.room = "Dining"; f2.project = p
        ctx.insert(f2)

        try? ctx.save()
        return p
    }
}

#Preview("Project Detail — Seeded") {
    ProjectDetailPreviewHost()
        .modelContainer(for: [Org.self, Item.self, Fixture.self], inMemory: true)
}
#endif
//End
