import SwiftUI
import UniformTypeIdentifiers

@main
struct FollowerWatchMacApp: App {
    @StateObject private var store = WatchStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct Snapshot: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var followers: [String]
    var following: [String]
}

struct WatchedProfile: Codable, Identifiable {
    var id = UUID()
    var username: String
    var snapshots: [Snapshot] = []
}

@MainActor
final class WatchStore: ObservableObject {
    @Published var profiles: [WatchedProfile] = [] { didSet { save() } }
    @Published var selectedID: UUID?
    @Published var search = ""
    @Published var notice = "Başlamak için bir profil ekleyin veya Instagram verisi içe aktarın."
    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("FollowerWatchMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }()

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([WatchedProfile].self, from: data) {
            profiles = decoded
        }
        selectedID = profiles.first?.id
    }
    var selected: WatchedProfile? { profiles.first { $0.id == selectedID } }
    var previous: Snapshot? { selected?.snapshots.dropLast().last }
    var latest: Snapshot? { selected?.snapshots.last }

    func addProfile(_ name: String) {
        let clean = name.trimmingCharacters(in: CharacterSet(charactersIn: "@ \n\t"))
        guard !clean.isEmpty else { return }
        if let existing = profiles.first(where: {$0.username.lowercased() == clean.lowercased()}) {
            selectedID = existing.id; notice = "Profil zaten kayıtlı."; return
        }
        let profile = WatchedProfile(username: clean)
        profiles.append(profile); selectedID = profile.id
        notice = "@\(clean) profili eklendi."
    }
    func addSnapshot(followers: [String], following: [String]) {
        guard let id = selectedID, let index = profiles.firstIndex(where: {$0.id == id}) else { return }
        profiles[index].snapshots.append(Snapshot(followers: normalized(followers), following: normalized(following)))
        notice = "Yeni tarama kaydedildi. \(followers.count) takipçi, \(following.count) takip edilen."
    }
    func removeProfile(_ id: UUID) {
        profiles.removeAll {$0.id == id}; selectedID = profiles.first?.id
    }
    func normalized(_ values: [String]) -> [String] {
        Array(Set(values.map{$0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "")}
            .filter{ !$0.isEmpty })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
    func exportData() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("follower-watch-backup.json")
        guard let data = try? JSONEncoder().encode(profiles) else { return nil }
        try? data.write(to: url); return url
    }
}

struct ContentView: View {
    @EnvironmentObject var store: WatchStore
    @State private var newName = ""
    @State private var importType = "followers"
    @State private var stagedFollowers: [String]?
    @State private var stagedFollowing: [String]?
    @State private var showingImporter = false
    @State private var showingAdd = false
    @State private var showingExport = false
    @State private var tab = "overview"

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if tab == "overview" { overview }
                        else if tab == "followers" { listView(title: "Takipçiler", values: store.latest?.followers ?? []) }
                        else if tab == "following" { listView(title: "Takip Edilenler", values: store.latest?.following ?? []) }
                        else if tab == "changes" { changesView }
                        else { historyView }
                    }.padding(28)
                }
                HStack {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text(store.notice).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Veriler yalnızca bu Mac'te saklanır").font(.caption2).foregroundStyle(.tertiary)
                }.padding(.horizontal, 24).padding(.vertical, 12)
                    .background(.ultraThinMaterial)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json, .commaSeparatedText, .plainText], allowsMultipleSelection: false) { result in
            importFile(result)
        }
        .fileExporter(isPresented: $showingExport, document: BackupDocument(url: store.exportData()), contentType: .json, defaultFilename: "follower-watch-backup") { _ in }
        .sheet(isPresented: $showingAdd) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Yeni profil").font(.title2.bold())
                TextField("Instagram kullanıcı adı", text: $newName).textFieldStyle(.roundedBorder)
                HStack {
                    Button("İptal") { showingAdd = false }
                    Spacer()
                    Button("Ekle") { store.addProfile(newName); newName = ""; showingAdd = false }.keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 360)
        }
    }

    var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "person.2.wave.2.fill").font(.title2).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Follower Watch").font(.headline)
                    Text("DESKTOP").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(.secondary)
                }
            }.padding(.top, 28)
            Button { showingAdd = true } label: {
                Label("Profil ekle", systemImage: "plus").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent)
            Text("PROFİLLER").font(.caption2.bold()).foregroundStyle(.secondary).tracking(1.2)
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(store.profiles) { profile in
                        Button { store.selectedID = profile.id; tab = "overview" } label: {
                            HStack {
                                Image(systemName: "at").foregroundStyle(.secondary)
                                Text(profile.username).lineLimit(1)
                                Spacer()
                                if store.selectedID == profile.id { Circle().fill(.blue).frame(width: 7, height: 7) }
                            }.padding(9).background(store.selectedID == profile.id ? Color.accentColor.opacity(0.13) : .clear).clipShape(RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                }
            }
            Divider()
            navButton("Genel Bakış", "square.grid.2x2", "overview")
            navButton("Takipçiler", "person.2", "followers")
            navButton("Takip Edilenler", "person.crop.circle.badge.checkmark", "following")
            navButton("Değişiklikler", "arrow.left.arrow.right", "changes")
            navButton("Tarama geçmişi", "clock", "history")
            Spacer()
            Button { showingExport = true } label: { Label("Yedeği dışa aktar", systemImage: "square.and.arrow.up") }.buttonStyle(.plain).foregroundStyle(.secondary)
            Text("Ücretsiz • Yerel • Türkçe").font(.caption2).foregroundStyle(.tertiary).padding(.bottom, 18)
        }
        .padding(.horizontal, 16).frame(width: 235).background(Color(nsColor: .controlBackgroundColor))
    }
    func navButton(_ title: String, _ icon: String, _ key: String) -> some View {
        Button { tab = key } label: {
            Label(title, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading).padding(9)
                .background(tab == key ? Color.accentColor.opacity(0.12) : .clear).clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(pageTitle).font(.title2.bold())
                Text(store.selected.map{"@\($0.username)"} ?? "Henüz profil seçilmedi").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Liste", selection: $importType) {
                Text("Takipçiler").tag("followers")
                Text("Takip edilenler").tag("following")
            }.pickerStyle(.segmented).frame(width: 210)
            Button { showingImporter = true } label: { Label("Dosya seç", systemImage: "square.and.arrow.down") }.buttonStyle(.borderedProminent).disabled(store.selected == nil)
        }.padding(.horizontal, 28).padding(.vertical, 18).background(.ultraThinMaterial)
    }
    var pageTitle: String {
        ["overview":"Genel Bakış","followers":"Takipçiler","following":"Takip Edilenler","changes":"Değişiklikler","history":"Tarama Geçmişi"][tab] ?? "Follower Watch"
    }
    var overview: some View {
        VStack(alignment: .leading, spacing: 20) {
            if store.selected == nil {
                emptyState
            } else {
                HStack(spacing: 14) {
                    metric("Takipçi", "\(store.latest?.followers.count ?? 0)", "person.2.fill")
                    metric("Takip Edilen", "\(store.latest?.following.count ?? 0)", "person.fill")
                    metric("Yeni Takipçi", "\(newFollowers.count)", "arrow-down-left")
                    metric("Kaybedilen", "\(lostFollowers.count)", "arrow-up-right")
                }
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Son tarama").font(.headline)
                        Text(store.latest.map{ $0.date.formatted(date: .long, time: .shortened) } ?? "Henüz tarama yok").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { importType = "followers"; showingImporter = true } label: { Label("Yeni tarama ekle", systemImage: "plus.circle.fill") }.buttonStyle(.borderedProminent)
                }.padding(20).background(.background).clipShape(RoundedRectangle(cornerRadius: 14))
                changesPreview
                Text("Nasıl çalışır?").font(.headline)
                Text("Instagram'dan indirdiğin followers ve following JSON dosyalarını içe aktar. Her yeni tarama, önceki kayıtla karşılaştırılır. Böylece yeni gelenleri ve listeden çıkanları görebilirsin.")
                    .foregroundStyle(.secondary).font(.callout)
            }
        }
    }
    func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).foregroundStyle(.blue).font(.title3)
            Text(value).font(.system(size: 27, weight: .bold, design: .rounded))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(.background).clipShape(RoundedRectangle(cornerRadius: 14))
    }
    var newFollowers: [String] {
        guard let old = store.previous, let now = store.latest else { return [] }
        return Array(Set(now.followers).subtracting(old.followers)).sorted()
    }
    var lostFollowers: [String] {
        guard let old = store.previous, let now = store.latest else { return [] }
        return Array(Set(old.followers).subtracting(now.followers)).sorted()
    }
    var changesPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Son değişiklikler").font(.headline)
            if store.previous == nil { Text("Değişiklikleri görmek için en az iki tarama kaydetmelisin.").foregroundStyle(.secondary).font(.callout) }
            else {
                changeRow("Yeni takipçiler", newFollowers, .green)
                changeRow("Takipten çıkanlar", lostFollowers, .red)
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.background).clipShape(RoundedRectangle(cornerRadius: 14))
    }
    func changeRow(_ title: String, _ values: [String], _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
            Spacer()
            Text("\(values.count)").bold().foregroundStyle(color)
            Text(values.prefix(3).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }
    func listView(title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            TextField("Kullanıcı adı ara…", text: $store.search).textFieldStyle(.roundedBorder)
            if values.isEmpty { Text("Henüz veri yok. Instagram dışa aktarma dosyanı içe aktar.").foregroundStyle(.secondary).padding(.vertical, 20) }
            else {
                ForEach(values.filter{$0.localizedCaseInsensitiveContains(store.search)}, id: \.self) { name in
                    HStack {
                        Image(systemName: "person.crop.circle").foregroundStyle(.secondary)
                        Text("@\(name)")
                        Spacer()
                        Button { NSWorkspace.shared.open(URL(string: "https://www.instagram.com/\(name)/")!) } label: { Image(systemName: "arrow.up.right") }.buttonStyle(.plain).foregroundStyle(.secondary)
                    }.padding(11).background(.background).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    var changesView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("İki son tarama arasındaki farklar").font(.headline)
            if store.previous == nil { Text("Karşılaştırma için en az iki tarama gerekli.").foregroundStyle(.secondary) }
            else {
                listSection("Yeni takipçiler", newFollowers, .green)
                listSection("Takipten çıkanlar", lostFollowers, .red)
                listSection("Yeni takip edilenler", followingAdded, .green)
                listSection("Takibi bırakılanlar", followingRemoved, .orange)
            }
        }
    }
    var followingAdded: [String] {
        guard let a = store.previous, let b = store.latest else { return [] }
        return Array(Set(b.following).subtracting(a.following)).sorted()
    }
    var followingRemoved: [String] {
        guard let a = store.previous, let b = store.latest else { return [] }
        return Array(Set(a.following).subtracting(b.following)).sorted()
    }
    func listSection(_ title: String, _ values: [String], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).font(.headline); Spacer(); Text("\(values.count)").foregroundStyle(color).bold() }
            if values.isEmpty { Text("Değişiklik yok").font(.caption).foregroundStyle(.secondary) }
            ForEach(values, id: \.self) { Text("@\( $0 )").font(.callout).padding(8).frame(maxWidth: .infinity, alignment: .leading).background(.background).clipShape(RoundedRectangle(cornerRadius: 7)) }
        }.padding(16).background(.background.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
    var historyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kayıtlı taramalar").font(.headline)
            if let profile = store.selected {
                ForEach(profile.snapshots.reversed()) { snap in
                    HStack {
                        Image(systemName: "clock").foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(snap.date.formatted(date: .long, time: .shortened))
                            Text("\(snap.followers.count) takipçi • \(snap.following.count) takip edilen").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }.padding(14).background(.background).clipShape(RoundedRectangle(cornerRadius: 9))
                }
            } else { emptyState }
        }
    }
    var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.badge.plus").font(.system(size: 42)).foregroundStyle(.secondary)
            Text("Henüz profil yok").font(.title3.bold())
            Text("Bir Instagram kullanıcı adı ekleyerek başla.").foregroundStyle(.secondary)
            Button("İlk profili ekle") { showingAdd = true }.buttonStyle(.borderedProminent)
        }.frame(maxWidth: .infinity).padding(60)
    }
    func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.lowercased()
            let names: [String]
            if ext == "csv" || ext == "txt" {
                names = String(data: data, encoding: .utf8)?.components(separatedBy: .newlines).map{$0.trimmingCharacters(in: .whitespacesAndNewlines)} ?? []
            } else {
                names = parseInstagramJSON(data)
            }
            guard !names.isEmpty else { store.notice = "Dosyada kullanıcı adı bulunamadı."; return }
            if importType == "followers" { stagedFollowers = names }
            else { stagedFollowing = names }
            if let followers = stagedFollowers, let following = stagedFollowing {
                store.addSnapshot(followers: followers, following: following)
                stagedFollowers = nil
                stagedFollowing = nil
            } else {
                store.notice = importType == "followers"
                    ? "Takipçi dosyası alındı. Şimdi Takip Edilenler'i seçip ikinci dosyayı içe aktarın."
                    : "Takip edilen dosyası alındı. Şimdi Takipçiler'i seçip ikinci dosyayı içe aktarın."
            }
        } catch { store.notice = "İçe aktarma hatası: \(error.localizedDescription)" }
    }
    func parseInstagramJSON(_ data: Data) -> [String] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var found: [String] = []
        func walk(_ value: Any) {
            if let array = value as? [Any] { array.forEach(walk) }
            else if let dict = value as? [String: Any] {
                if let string = dict["value"] as? String, dict["href"] != nil { found.append(string) }
                else if let string = dict["username"] as? String { found.append(string) }
                else if let string = dict["title"] as? String, !string.isEmpty { found.append(string) }
                else { dict.values.forEach(walk) }
            }
        }
        walk(object)
        return Array(Set(found))
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(url: URL?) { data = url.flatMap{try? Data(contentsOf: $0)} ?? Data("[]".utf8) }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws { FileWrapper(regularFileWithContents: data) }
}
