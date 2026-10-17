import AppKit
import SwiftUI

// MARK: - Componentes

struct AnelEspaco: View {
    let disco: InfoDisco
    let metaBytes: Int64
    var espessura: CGFloat = 14
    var mostrarTexto = true

    var fracLivre: Double { disco.total > 0 ? Double(disco.livre) / Double(disco.total) : 0 }
    var fracMeta: Double { disco.total > 0 ? Double(metaBytes) / Double(disco.total) : 0 }
    var cor: Color {
        if disco.livre < metaBytes { return .red }
        if disco.livre < metaBytes + metaBytes / 3 { return .orange }
        return .green
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: espessura)
            Circle()
                .trim(from: 0, to: max(0.01, fracLivre))
                .stroke(cor.gradient, style: StrokeStyle(lineWidth: espessura, lineCap: .round))
                .rotationEffect(.degrees(-90))
            GeometryReader { g in
                Capsule()
                    .fill(Color.primary.opacity(0.7))
                    .frame(width: 3, height: espessura + 6)
                    .position(x: g.size.width / 2, y: espessura / 2)
                    .rotationEffect(.degrees(fracMeta * 360))
            }
            if mostrarTexto {
                VStack(spacing: 0) {
                    Text("\(Int((Double(disco.livre) / 1e9).rounded()))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("GB livres").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .help("O anel é o espaço livre. O tique marca a sua meta.")
    }
}

struct Cartao<Conteudo: View>: View {
    let titulo: String
    let icone: String
    let cor: Color
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(titulo, systemImage: icone)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(cor)
            conteudo
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
    }
}

struct Etiqueta: View {
    let texto: String
    let cor: Color
    init(_ texto: String, _ cor: Color) { self.texto = texto; self.cor = cor }

    var body: some View {
        Text(texto)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(cor.opacity(0.16)))
            .foregroundStyle(cor)
    }
}

func mostrarNoFinder(_ caminhos: [String]) {
    let urls = caminhos.prefix(8).filter { Caminho.existe($0) }.map { URL(fileURLWithPath: $0) }
    if !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
}

// MARK: - Seções da janela

enum Secao: String, CaseIterable, Identifiable {
    case visao = "Visão geral"
    case limpeza = "Limpeza"
    case grandes = "Arquivos grandes"
    case mapa = "Mapa do espaço"
    case apps = "Desinstalar apps"
    case segundo = "Segundo plano"
    case ajustes = "Ajustes"

    var id: String { rawValue }
    var icone: String {
        switch self {
        case .visao: "gauge.with.dots.needle.67percent"
        case .limpeza: "sparkles"
        case .grandes: "doc.badge.ellipsis"
        case .mapa: "square.grid.3x3.square"
        case .apps: "trash.square"
        case .segundo: "gearshape.2"
        case .ajustes: "slider.horizontal.3"
        }
    }
}

struct JanelaPrincipal: View {
    @EnvironmentObject var e: Estado
    @State private var secao: Secao? = .visao

    var body: some View {
        NavigationSplitView {
            List(Secao.allCases, selection: $secao) { s in
                NavigationLink(value: s) {
                    Label(s.rawValue, systemImage: s.icone)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 200)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    AnelEspaco(disco: e.disco, metaBytes: e.metaBytes, espessura: 5, mostrarTexto: false)
                        .frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(tamanho(e.disco.livre)).font(.callout.weight(.semibold)).monospacedDigit()
                        Text("livres").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
            }
        } detail: {
            switch secao ?? .visao {
            case .visao: VisaoGeralView(secao: $secao)
            case .limpeza: LimpezaView()
            case .grandes: GrandesView()
            case .mapa: MapaView()
            case .apps: DesinstalarView()
            case .segundo: SegundoPlanoView()
            case .ajustes: AjustesView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

// MARK: - Visão geral

struct VisaoGeralView: View {
    @EnvironmentObject var e: Estado
    @Binding var secao: Secao?
    @State private var confirmando = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 30) {
                    AnelEspaco(disco: e.disco, metaBytes: e.metaBytes).frame(width: 170, height: 170)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Espaço livre").foregroundStyle(.secondary)
                        Text(tamanho(e.disco.livre)).font(.system(size: 38, weight: .bold, design: .rounded))
                        Text("de \(tamanho(e.disco.total)) · \(tamanho(e.disco.usado)) usados")
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Circle().fill(e.abaixoDaMeta ? Color.red : Color.green).frame(width: 8, height: 8)
                            Text(e.abaixoDaMeta ? "Faltam \(tamanho(e.metaBytes - e.disco.livre)) pra sua meta de \(e.metaGB) GB"
                                                : "Dentro da meta de \(e.metaGB) GB")
                        }
                        .font(.callout)
                        .padding(.top, 4)
                    }
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
                    Cartao(titulo: "Lixo seguro", icone: "sparkles", cor: .green) {
                        if e.analisando && e.analisadoEm == nil {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(tamanho(e.totalSeguroLivre)).font(.title2.weight(.bold)).monospacedDigit()
                            HStack {
                                Text("cache e temporários, se refaz sozinho").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button(confirmando ? "Confirmar" : "Limpar") {
                                    if confirmando { confirmando = false; Task { await e.limparSeguro() } } else { confirmando = true }
                                }
                                .buttonStyle(.borderedProminent).tint(confirmando ? .orange : .green)
                                .controlSize(.small)
                                .disabled(e.totalSeguroLivre == 0 || e.limpando)
                            }
                        }
                    }
                    Cartao(titulo: "Pra revisar", icone: "eye", cor: .orange) {
                        Text(tamanho(e.totalRevisar)).font(.title2.weight(.bold)).monospacedDigit()
                        HStack {
                            Text("mídia do WhatsApp, modelos de IA…").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Ver") { secao = .limpeza }.controlSize(.small)
                        }
                    }
                    Cartao(titulo: "O macOS libera sozinho", icone: "arrow.triangle.2.circlepath", cor: .blue) {
                        Text(tamanho(e.disco.purgavel)).font(.title2.weight(.bold)).monospacedDigit()
                        Text("espaço reservado que o sistema solta quando precisa").font(.caption).foregroundStyle(.secondary)
                    }
                    Cartao(titulo: "Memória virtual (swap)", icone: "memorychip", cor: .purple) {
                        Text(tamanho(e.disco.swapUsado)).font(.title2.weight(.bold)).monospacedDigit()
                        Text("arquivo de troca da memória. Diminui quando você fecha apps pesados ou reinicia")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if e.disco.atualizacaoPreparada {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill").font(.title2).foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tem uma atualização do macOS preparada").fontWeight(.semibold)
                            Text("Ela segura espaço no disco até ser instalada. Instalar (ou reiniciar) devolve esse espaço.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Abrir Atualização de Software") {
                            if let u = URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension") {
                                NSWorkspace.shared.open(u)
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.blue.opacity(0.08)))
                }

                if let r = e.resultado {
                    Label(r, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }

                if !e.visiveis.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("O que mais ocupa (do que dá pra limpar)").font(.headline)
                        ForEach(e.visiveis.sorted { $0.bytes > $1.bytes }.prefix(8)) { i in
                            HStack {
                                Image(systemName: i.alvo.grupo.icone).frame(width: 20).foregroundStyle(.secondary)
                                Text(i.alvo.nome)
                                if i.alvo.nivel == .revisar { Etiqueta("revise", .orange) }
                                if i.bloqueado { Etiqueta("app aberto", .gray) }
                                Spacer()
                                Text(tamanho(i.bytes)).monospacedDigit().foregroundStyle(.secondary)
                            }
                            .font(.callout)
                        }
                        Button("Ver tudo na Limpeza") { secao = .limpeza }.padding(.top, 4)
                    }
                }
            }
            .padding(26)
        }
        .navigationTitle("Visão geral")
        .toolbar {
            ToolbarItem {
                Button { Task { await e.analisar() } } label: {
                    if e.analisando { ProgressView().controlSize(.small) } else { Label("Analisar de novo", systemImage: "arrow.clockwise") }
                }
                .help("Medir tudo de novo")
            }
        }
    }
}

// MARK: - Limpeza

struct LimpezaView: View {
    @EnvironmentObject var e: Estado
    @State private var confirmando = false

    var marcadosRevisar: [Item] { e.visiveis.filter { e.marcados.contains($0.id) && $0.alvo.nivel == .revisar } }

    var body: some View {
        VStack(spacing: 0) {
            if e.analisadoEm == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Procurando o que dá pra limpar…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Grupo.allCases, id: \.self) { g in
                        let itens = e.visiveis.filter { $0.alvo.grupo == g }.sorted { $0.bytes > $1.bytes }
                        if !itens.isEmpty {
                            Section {
                                ForEach(itens) { LinhaLimpeza(item: $0) }
                            } header: {
                                HStack {
                                    Label(g.rawValue, systemImage: g.icone)
                                    Spacer()
                                    Text(tamanho(itens.reduce(0) { $0 + $1.bytes })).monospacedDigit()
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
            Divider()
            HStack(spacing: 12) {
                if e.limpando {
                    ProgressView().controlSize(.small)
                    Text("Limpando…")
                } else if let r = e.resultado {
                    Label(r, systemImage: "checkmark.circle.fill").foregroundStyle(.green).lineLimit(2)
                }
                Spacer()
                Button("Marcar todo o seguro") { e.marcarTodoSeguro() }
                Button("Desmarcar tudo") { e.marcados.removeAll() }
                Button {
                    confirmando = true
                } label: {
                    Text(e.marcados.isEmpty ? "Marque o que quer limpar" : "Liberar \(tamanho(e.totalMarcado))")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(e.marcados.isEmpty || e.limpando)
            }
            .padding(14)
        }
        .navigationTitle("Limpeza")
        .toolbar {
            ToolbarItem {
                Button { Task { await e.analisar() } } label: {
                    if e.analisando { ProgressView().controlSize(.small) } else { Label("Analisar de novo", systemImage: "arrow.clockwise") }
                }
            }
        }
        .alert("Liberar \(tamanho(e.totalMarcado))?", isPresented: $confirmando) {
            Button("Liberar", role: .destructive) { Task { await e.limpar(e.marcados) } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            if marcadosRevisar.isEmpty {
                Text("Só cache e arquivos temporários. Tudo se refaz sozinho.")
            } else {
                Text("Inclui coisas que não voltam sozinhas: \(marcadosRevisar.map(\.alvo.nome).joined(separator: ", ")). Isso não dá pra desfazer.")
            }
        }
        .onAppear { e.conferirAbertos() }
    }
}

struct LinhaLimpeza: View {
    @EnvironmentObject var e: Estado
    let item: Item

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: Binding(get: { e.marcados.contains(item.id) },
                                     set: { v in if v { e.marcados.insert(item.id) } else { e.marcados.remove(item.id) } }))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(item.bloqueado)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.alvo.nome).fontWeight(.medium)
                    if item.alvo.nivel == .revisar { Etiqueta("revise", .orange) }
                }
                if !item.alvo.nota.isEmpty {
                    Text(item.alvo.nota).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if item.bloqueado {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                        Text("Feche o \(item.abertos.joined(separator: ", ")) pra limpar")
                        Button(e.fechando.contains(item.id) ? "Fechando…" : "Fechar agora") {
                            Task { await e.fecharApps(de: item) }
                        }
                        .controlSize(.small)
                        .disabled(e.fechando.contains(item.id))
                        .help("Fecha como o Cmd+Q. Se tiver algo sem salvar, o app pergunta antes.")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 12)
            Text(tamanho(item.bytes))
                .monospacedDigit()
                .foregroundStyle(item.bloqueado ? Color.secondary : Color.primary)
            Button { mostrarNoFinder(item.alvo.caminhos) } label: { Image(systemName: "magnifyingglass") }
                .buttonStyle(.borderless)
                .help("Mostrar no Finder")
        }
        .padding(.vertical, 4)
    }
}
