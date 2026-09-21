import SwiftUI

// Native research workspace: persistent navigation, independently scrolling results.
// Appearance follows macOS. Surfaces use 14pt radii; interactive rows use 8pt.
struct BenchmarksView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case charts = "Charts", rankings = "Rankings"
        var id: String { rawValue }
        var icon: String { self == .charts ? "chart.bar.xaxis" : "list.number" }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = BenchmarkStore()
    @State private var mode: Mode = .charts
    @State private var selected = BenchmarkDefinition.catalog[0]
    @State private var collection = RankingCollection.catalog[0]
    @State private var categorySearch = ""
    @State private var modelSearch = ""
    @State private var topCount = 6

    private var key: String { mode == .charts ? selected.id : "ranking-\(collection.id)" }
    private var loading: Bool { store.loading.contains(key) }
    private var metricSnapshot: BenchmarkSnapshot? { store.snapshots[selected.id] }
    private var rankingSnapshot: RankingSnapshot? { store.rankingSnapshots[collection.id] }
    private var fetchedAt: Date? { mode == .charts ? metricSnapshot?.fetchedAt : rankingSnapshot?.fetchedAt }
    private var title: String { mode == .charts ? selected.name : collection.title }
    private var unit: String { mode == .charts ? selected.category : rankingSnapshot?.metric ?? "Published score" }
    private var subtitle: String { mode == .charts ? selected.summary : collection.subtitle }
    private var sourceURL: URL {
        mode == .charts ? selected.url : URL(string: "https://modelgrep.com/best/\(collection.id)")!
    }
    private var direction: String {
        if mode == .charts { return selected.lowerIsBetter ? "Lower is better" : "Higher is better" }
        return "Modelgrep order"
    }

    private var allRows: [BenchmarkDisplayRow] {
        if mode == .charts {
            return (metricSnapshot?.entries ?? []).map {
                BenchmarkDisplayRow(id: $0.modelId, rank: $0.rank, name: $0.name,
                                    value: $0.value, display: $0.value.formatted(.number.precision(.fractionLength(0...2))),
                                    notes: $0.notes, url: $0.sourceURL)
            }
        }
        return (rankingSnapshot?.entries ?? []).map {
            BenchmarkDisplayRow(id: $0.modelId, rank: $0.rank, name: $0.name,
                                value: $0.metricValue, display: $0.metricDisplay, notes: $0.notes, url: $0.sourceURL)
        }
    }
    private var rows: [BenchmarkDisplayRow] {
        allRows.filter { modelSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(modelSearch) || $0.id.localizedCaseInsensitiveContains(modelSearch) }
    }
    private var chartRows: [BenchmarkDisplayRow] {
        Array(rows.prefix(topCount)).filter { $0.value != nil }
    }
    private var metricChoices: [BenchmarkDefinition] {
        BenchmarkDefinition.catalog.filter { categorySearch.isEmpty || $0.name.localizedCaseInsensitiveContains(categorySearch) || $0.category.localizedCaseInsensitiveContains(categorySearch) }
    }
    private var collectionChoices: [RankingCollection] {
        RankingCollection.catalog.filter { categorySearch.isEmpty || $0.title.localizedCaseInsensitiveContains(categorySearch) || $0.subtitle.localizedCaseInsensitiveContains(categorySearch) }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                workspaceHeader(compact: geometry.size.width < 850)
                Divider()
                if geometry.size.width >= 850 {
                    HStack(spacing: 0) {
                        categoryRail.frame(width: 214)
                        Divider()
                        results
                    }
                } else {
                    compactNavigation
                    Divider()
                    results
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationTitle("Benchmarks")
        .task(id: key) { await refresh() }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                await refresh()
            }
        }
    }

    private func workspaceHeader(compact: Bool) -> some View {
        HStack(spacing: compact ? 16 : 30) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Benchmarks").font(.system(size: 23, weight: .bold)).tracking(-0.6)
                if !compact { Text("Find the right model for your work.").font(.system(size: 12)).foregroundStyle(.secondary) }
            }
            HStack(spacing: 4) {
                ForEach(Mode.allCases) { option in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) { mode = option }
                        categorySearch = ""
                        modelSearch = ""
                    } label: {
                        Label(option.rawValue, systemImage: option.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 17).padding(.vertical, 10)
                            .foregroundStyle(mode == option ? Color.primary : Color.secondary)
                            .background(mode == option ? Color(nsColor: .controlBackgroundColor) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(mode == option ? Color.primary.opacity(0.12) : .clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(mode == option ? .isSelected : [])
                    .help(option == .charts ? "Compare individual model metrics" : "Ranked models for 31 specific use cases")
                }
            }.padding(4).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            Spacer(minLength: 0)
            Button { Task { await refresh(force: true) } } label: { Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .medium)) }
                .buttonStyle(.borderless).disabled(loading).help("Refresh current results").accessibilityLabel("Refresh current results")
        }.padding(.horizontal, 24).padding(.vertical, 18)
    }

    private var categoryRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(mode == .charts ? "Model metrics" : "Use cases").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(mode == .charts ? "7" : "31").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }.padding(.bottom, 12)
            searchField("Find a category", text: $categorySearch)
                .padding(.bottom, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    if mode == .charts {
                        ForEach(metricChoices) { metric in
                            categoryButton(metric.name, icon: metricIcon(metric.id), active: selected == metric) {
                                selected = metric; modelSearch = ""
                            }.help(metric.category)
                        }
                    } else {
                        ForEach(RankingCollection.groups, id: \.self) { group in
                            let choices = collectionChoices.filter { $0.group == group }
                            if !choices.isEmpty {
                                Text(groupTitle(group)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                                    .padding(.top, group == RankingCollection.groups.first ? 0 : 18).padding(.bottom, 6).padding(.leading, 10)
                                ForEach(choices) { choice in
                                    categoryButton(choice.title, icon: choice.icon, active: collection == choice) {
                                        collection = choice; modelSearch = ""
                                    }.help(choice.subtitle)
                                }
                            }
                        }
                    }
                    if mode == .charts ? metricChoices.isEmpty : collectionChoices.isEmpty {
                        Text("No matching categories").font(.system(size: 12)).foregroundStyle(.secondary).padding(10)
                    }
                }.padding(.trailing, 3)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Data by Modelgrep").font(.system(size: 11, weight: .medium))
                Text("Refreshes hourly").font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(.top, 15)
        }.padding(16).background(Color.primary.opacity(0.015))
    }

    private var compactNavigation: some View {
        HStack {
            Text(mode == .charts ? "Metric" : "Use case").font(.system(size: 12)).foregroundStyle(.secondary)
            if mode == .charts {
                Picker("Metric", selection: $selected) {
                    ForEach(BenchmarkDefinition.catalog) { Text($0.name).tag($0) }
                }.labelsHidden().frame(maxWidth: 260)
            } else {
                Picker("Use case", selection: $collection) {
                    ForEach(RankingCollection.groups, id: \.self) { group in
                        Section(groupTitle(group)) {
                            ForEach(RankingCollection.catalog.filter { $0.group == group }) { Text($0.title).tag($0) }
                        }
                    }
                }.labelsHidden().frame(maxWidth: 260)
            }
            Spacer()
            Text("Modelgrep").font(.system(size: 11)).foregroundStyle(.secondary)
        }.padding(.horizontal, 24).padding(.vertical, 10)
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    resultHeader
                    if let error = store.errors[key] {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(fetchedAt == nil ? error : "Showing saved results. \(error)", systemImage: "exclamationmark.triangle")
                                .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                            Button("Try again") { Task { await refresh(force: true) } }.disabled(loading)
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    if fetchedAt == nil && loading {
                        loadingSkeleton
                    } else if rows.isEmpty {
                        ContentUnavailableView(modelSearch.isEmpty ? "No results available" : "No matching models",
                                               systemImage: "chart.bar.xaxis",
                                               description: Text(modelSearch.isEmpty ? "Refresh to try loading this view again." : "Try another name or clear your search."))
                            .frame(minHeight: 280)
                    } else {
                        if !chartRows.isEmpty {
                            comparison
                        }
                        modelList
                    }
                    sourceNote
                }
                .padding(24).id("results-top").frame(maxWidth: 1200, alignment: .leading).frame(maxWidth: .infinity, alignment: .top)
            }
            .onChange(of: key) { _, _ in
                modelSearch = ""
                proxy.scrollTo("results-top", anchor: .top)
            }
        }
    }

    private var resultHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(title).font(.system(size: 29, weight: .bold)).tracking(-0.8)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Link(destination: sourceURL) { Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .medium)).padding(9) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    .help("View source on Modelgrep").accessibilityLabel("View source on Modelgrep")
            }
            HStack(spacing: 14) {
                if let date = fetchedAt {
                    Text("\(allRows.count) models")
                    Text("Updated \(date.formatted(date: .omitted, time: .shortened))").help(date.formatted(date: .abbreviated, time: .shortened))
                } else {
                    Text("Live model data")
                }
                if loading { ProgressView().controlSize(.mini) }
                Spacer()
                searchField("Search models", text: $modelSearch).frame(maxWidth: 220)
            }.font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var comparison: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(modelSearch.isEmpty ? "Leading models" : "Matching models").font(.system(size: 16, weight: .semibold))
                    Text("\(unit) · \(direction)").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Chart size", selection: $topCount) {
                    Text("Top 6").tag(6)
                    Text("Top 10").tag(10)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 135)
            }
            BenchmarkComparisonPlot(rows: chartRows, unit: unit)
            if mode == .rankings, let summary = rankingSnapshot?.answer, !summary.isEmpty {
                DisclosureGroup {
                    Text(summary).font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
                } label: {
                    Label("Modelgrep’s assessment", systemImage: "text.alignleft").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
            }
        }.padding(20)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08)))
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(modelSearch.isEmpty ? "All models" : "Matching models").font(.system(size: 16, weight: .semibold))
                Text("\(rows.count)").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Text(unit).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            LazyVStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        Text("\(row.rank)").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary).frame(width: 25)
                        BenchmarkMakerMark(maker: row.maker)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.shortName).font(.system(size: 13, weight: .medium)).lineLimit(1).help(row.name)
                            Text(row.id).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer(minLength: 8)
                        Text(row.display).font(.system(size: 14, weight: .semibold, design: .monospaced)).lineLimit(1).help(unit)
                        if let url = row.url {
                            Link(destination: url) { Image(systemName: "arrow.up.right").font(.system(size: 11)).padding(7) }
                                .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("View \(row.shortName) on Modelgrep")
                        }
                    }
                    .padding(.vertical, 12)
                    .help(row.notes ?? row.name)
                    if row.id != rows.last?.id { Divider().opacity(0.45) }
                }
            }
        }
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Loading model results").font(.system(size: 16, weight: .semibold))
            ForEach(0..<6) { index in
                HStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 5).fill(.quaternary).frame(width: 150, height: 15)
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(maxWidth: .infinity).frame(height: 18).padding(.trailing, CGFloat(index * 17))
                }
            }
        }.padding(22).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .ignore).accessibilityLabel("Loading model results")
    }

    private var sourceNote: some View {
        VStack(alignment: .leading, spacing: 5) {
            if mode == .charts, let data = metricSnapshot, data.hasMore {
                Text("Based on \(data.fetchedCount) fetched models out of \(data.total). Models without a reported score are excluded.")
            }
            Text(mode == .charts ? "Original metric units from Modelgrep. Different benchmarks measure different capabilities."
                 : "Published order and scores from Modelgrep. Each use case has its own ranking methodology.")
        }.font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private func searchField(_ label: String, text: Binding<String>) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
            TextField(label, text: text).textFieldStyle(.plain).font(.system(size: 12)).accessibilityLabel(label)
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).accessibilityLabel("Clear \(label.lowercased())")
            }
        }.padding(9).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
    }

    private func categoryButton(_ label: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 13)).frame(width: 18)
                Text(label).font(.system(size: 12, weight: active ? .semibold : .regular)).lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if active { Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)) }
            }
            .foregroundStyle(active ? Color.accentColor : Color.primary.opacity(0.85))
            .padding(.horizontal, 10).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(active ? .isSelected : [])
    }

    private func refresh(force: Bool = false) async {
        if mode == .charts { await store.refresh(selected, force: force) }
        else { await store.refresh(collection, force: force) }
    }

    private func groupTitle(_ group: String) -> String {
        switch group {
        case "Start here": return "General"
        case "Build": return "Development"
        case "Think": return "Reasoning & knowledge"
        case "Run": return "Deployment"
        default: return "Creative & specialist"
        }
    }

    private func metricIcon(_ id: String) -> String {
        switch id {
        case "intelligence": return "sparkles"
        case "coding": return "chevron.left.forwardslash.chevron.right"
        case "agentic": return "point.3.connected.trianglepath.dotted"
        case "design": return "paintpalette"
        case "throughput": return "bolt"
        case "latency": return "timer"
        default: return "text.alignleft"
        }
    }
}

private struct BenchmarkDisplayRow: Identifiable {
    let id: String
    let rank: Int
    let name: String
    let value: Double?
    let display: String
    let notes: String?
    let url: URL?
    var maker: String { String(id.split(separator: "/").first ?? "") }
    var shortName: String {
        guard let colon = name.firstIndex(of: ":") else { return name }
        return String(name[name.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    }
}

/// A shared zero-baseline plot with fixed label/score columns, so long model
/// names never become tiny axis labels or collide with the values.
private struct BenchmarkComparisonPlot: View {
    let rows: [BenchmarkDisplayRow]
    let unit: String
    @State private var hovered: String?
    private let rowHeight: CGFloat = 43
    private var maximum: Double {
        let target = max(rows.compactMap(\.value).max() ?? 1, 0.001) * 1.04 / 4
        let magnitude = pow(10, floor(log10(target)))
        let normalized = target / magnitude
        let step = [1.0, 1.5, 2, 2.5, 4, 5, 7.5, 10].first { $0 >= normalized } ?? 10
        return step * magnitude * 4
    }

    var body: some View {
        GeometryReader { geometry in
            let nameWidth: CGFloat = geometry.size.width < 610 ? 145 : 205
            let scoreWidth: CGFloat = geometry.size.width < 610 ? 72 : 95
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            HStack(spacing: 9) {
                                Text("\(row.rank)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).frame(width: 17, alignment: .leading)
                                Text(row.shortName).font(.system(size: 12, weight: row.id == rows.first?.id ? .semibold : .regular))
                                    .lineLimit(1).truncationMode(.middle).help(row.name)
                                Spacer(minLength: 0)
                            }.frame(height: rowHeight)
                        }
                    }.frame(width: nameWidth)
                    GeometryReader { plot in
                        ZStack(alignment: .topLeading) {
                            ForEach(0..<5) { tick in
                                Rectangle().fill(Color.primary.opacity(tick == 0 ? 0.12 : 0.05))
                                    .frame(width: 1).offset(x: plot.size.width * CGFloat(tick) / 4)
                            }
                            VStack(spacing: 0) {
                                ForEach(rows) { row in
                                    HStack(spacing: 0) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(row.id == rows.first?.id || hovered == row.id ? Color.accentColor : Color.accentColor.opacity(0.48))
                                            .frame(width: max(row.value == 0 ? 0 : 2, plot.size.width * CGFloat(max(0, row.value ?? 0) / maximum)), height: 18)
                                        Spacer(minLength: 0)
                                    }
                                    .frame(height: rowHeight).contentShape(Rectangle())
                                    .onHover { hovered = $0 ? row.id : nil }
                                    .help("\(row.name): \(row.display) \(unit)")
                                    .accessibilityLabel("\(row.name), rank \(row.rank), \(row.display) \(unit)")
                                }
                            }
                        }
                    }
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(rows) { row in
                            Text(row.display).font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(row.id == rows.first?.id ? Color.accentColor : .primary)
                                .lineLimit(1).minimumScaleFactor(0.85)
                                .frame(height: rowHeight).frame(maxWidth: .infinity, alignment: .trailing)
                                .help("\(row.display) \(unit)")
                        }
                    }.frame(width: scoreWidth)
                }.frame(height: rowHeight * CGFloat(rows.count))
                HStack(spacing: 12) {
                    Color.clear.frame(width: nameWidth)
                    HStack {
                        ForEach(0..<5) { tick in
                            if tick > 0 { Spacer(minLength: 0) }
                            Text((maximum * Double(tick) / 4).formatted(.number.notation(.compactName).precision(.fractionLength(0...1))))
                                .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                    Color.clear.frame(width: scoreWidth)
                }.frame(height: 26)
            }
        }.frame(height: rowHeight * CGFloat(rows.count) + 26)
    }
}

private struct BenchmarkMakerMark: View {
    let maker: String
    private var asset: String? {
        switch maker {
        case "anthropic": return "Logo-claude-code"
        case "openai": return "Logo-codex"
        case "google": return "Logo-gemini-cli"
        default: return nil
        }
    }
    var body: some View {
        Group {
            if let asset, let image = NSImage(named: asset) {
                Image(nsImage: image).resizable().scaledToFit().padding(4)
            } else {
                Text(String(maker.prefix(2)).uppercased()).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
            }
        }.frame(width: 28, height: 28)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
            .accessibilityHidden(true)
    }
}
