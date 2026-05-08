import SwiftUI
import SwiftData
import FamilyControls

struct AppBlockingView: View {
    @Query private var profiles: [AppBlockingProfile]
    @Environment(AppBlockingService.self) private var service

    var body: some View {
        List {
            if !service.isAuthorized {
                authorizationSection
            }
            conceptSection
            segmentsSection
        }
        .navigationTitle("Blocage d'apps")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { service.checkStatus() }
    }

    private var authorizationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Autorisation Temps d'écran", systemImage: "lock.shield.fill")
                    .font(.subheadline.bold())
                Text("PrayPlan a besoin d'accéder aux Temps d'écran pour bloquer les applications distrayantes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await service.requestAuthorization() }
                } label: {
                    Label("Autoriser", systemImage: "checkmark.shield")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
                if let err = service.authorizationError {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var conceptSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(Color.brandGreen)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dopamine progressive")
                        .font(.subheadline.bold())
                    Text("0 dopamine au Fajr, accès total le soir. Chaque segment débloque progressivement plus d'apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var segmentsSection: some View {
        Section {
            ForEach(PrayerSegment.allCases) { segment in
                let profile = profiles.first { $0.segment == segment }
                Group {
                    if let profile {
                        NavigationLink {
                            SegmentBlockingDetailView(profile: profile)
                                .environment(service)
                        } label: {
                            SegmentBlockingRow(profile: profile)
                        }
                    } else {
                        SegmentBlockingRowPlaceholder(segment: segment)
                    }
                }
            }
        } header: {
            Text("Intervalles de prière")
        } footer: {
            Text("Sélectionne les apps à bloquer pour chaque intervalle. Plus le soleil monte, plus d'apps sont accessibles.")
        }
    }
}

// MARK: - Row

struct SegmentBlockingRow: View {
    @Bindable var profile: AppBlockingProfile

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(profile.segment.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: profile.segment.systemIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(profile.segment.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.segment.displayName)
                    .font(.subheadline.weight(.medium))
                DopamineBar(level: profile.dopamineLevel, isEnabled: profile.isEnabled)
            }

            Spacer()

            if profile.isEnabled && profile.hasAppsSelected {
                Image(systemName: "shield.fill")
                    .font(.caption)
                    .foregroundStyle(profile.segment.color)
            }
        }
        .padding(.vertical, 2)
        .opacity(profile.isEnabled ? 1 : 0.7)
    }
}

struct SegmentBlockingRowPlaceholder: View {
    let segment: PrayerSegment

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(segment.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: segment.systemIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(segment.color)
            }
            Text(segment.displayName)
                .font(.subheadline)
            Spacer()
            ProgressView().scaleEffect(0.7)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Dopamine Bar

struct DopamineBar: View {
    let level: Int      // 0-5
    let isEnabled: Bool

    private var barColor: Color {
        switch level {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return .mint
        case 4: return .teal
        default: return .green
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i < level ? barColor : Color(.tertiarySystemFill))
                    .frame(width: 14, height: 5)
            }
            Text(levelLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
        }
    }

    private var levelLabel: String {
        switch level {
        case 0: return "Bloqué"
        case 1: return "Minimal"
        case 2: return "Limité"
        case 3: return "Modéré"
        case 4: return "Ouvert"
        default: return "Libre"
        }
    }
}

// MARK: - Detail View

struct SegmentBlockingDetailView: View {
    @Bindable var profile: AppBlockingProfile
    @Environment(AppBlockingService.self) private var service

    @State private var showPicker = false
    @State private var currentSelection = FamilyActivitySelection()

    private var selectedAppCount: Int {
        guard let data = profile.selectionData,
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return 0 }
        return sel.applicationTokens.count + sel.categoryTokens.count
    }

    var body: some View {
        Form {
            headerSection
            toggleSection
            if profile.isEnabled {
                appsSection
            }
            if profile.isEnabled && profile.hasAppsSelected {
                previewSection
            }
        }
        .navigationTitle(profile.segment.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(isPresented: $showPicker, selection: $currentSelection)
        .onChange(of: currentSelection) { _, newSel in
            profile.selectionData = try? JSONEncoder().encode(newSel)
        }
        .onChange(of: profile.isEnabled) { _, enabled in
            if !enabled { service.clearBlocking() }
        }
    }

    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(profile.segment.color.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: profile.segment.systemIcon)
                        .font(.title2)
                        .foregroundStyle(profile.segment.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.segment.displayName)
                        .font(.headline)
                    DopamineBar(level: profile.dopamineLevel, isEnabled: profile.isEnabled)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var toggleSection: some View {
        Section {
            Toggle("Activer le blocage", isOn: $profile.isEnabled)
                .tint(.brandGreen)
        } footer: {
            Text(profile.isEnabled
                 ? "Le blocage s'applique automatiquement pendant cet intervalle."
                 : "Les apps sont librement accessibles pendant cet intervalle.")
        }
    }

    private var appsSection: some View {
        Section {
            Button {
                if let data = profile.selectionData,
                   let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
                    currentSelection = saved
                } else {
                    currentSelection = FamilyActivitySelection()
                }
                showPicker = true
            } label: {
                HStack {
                    Label("Choisir les apps", systemImage: "apps.iphone.badge.plus")
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedAppCount > 0 {
                        Text("\(selectedAppCount) sélectionnée\(selectedAppCount > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Aucune")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Applications à bloquer")
        } footer: {
            Text("Sélectionne les apps ou catégories à bloquer pendant \(profile.segment.displayName).")
        }
    }

    private var previewSection: some View {
        Section {
            Button("Réinitialiser la sélection", role: .destructive) {
                profile.selectionData = nil
                currentSelection = FamilyActivitySelection()
                service.clearBlocking()
            }
        }
    }
}
