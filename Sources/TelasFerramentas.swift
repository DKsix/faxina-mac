import AppKit
import SwiftUI

// MARK: - Arquivos grandes

extension View {
    /// Linha que não pode ser selecionada (macOS 14+; no 13 o filtro da seleção já segura).
    @ViewBuilder func semSelecao(_ v: Bool) -> some View {
        if #available(macOS 14.0, *) { self.selectionDisabled(v) } else { self }
    }
}

@MainActor
final class GrandesModelo: ObservableObject {
    static let compartilhado = GrandesModelo()
    @Published var itens: [Grande] = []
    @Published var buscando = false
    @Published var vistos = 0
    @Published var minimoMB = 500
    @Published var selecao = Set<String>() {
        didSet {
            // arquivos protegidos (catálogo do Lightroom, bancos de dados…) não entram na seleção
            let livres = selecao.filter { Grande.motivoProtecao($0) == nil }
            if livres != selecao { selecao = livres }
        }
    }
    @Published var buscou = false

    func buscar() async {
        buscando = true
        vistos = 0
        selecao.removeAll()
        let minimo = Int64(minimoMB) * 1_000_000
        let r = await Task.detached(priority: .userInitiated) {
            BuscaGrandes.buscar(minimo: minimo) { n in DispatchQueue.main.async { GrandesModelo.compartilhado.vistos = n } }
        }.value
        itens = r
        buscando = false
        buscou = true
    }

    func lixeira() async {
        let alvo = itens.filter { selecao.contains($0.id) && !$0.protegido }.map(\.id)
        let n = await Lixeira.mandar(alvo)
        Historico.anotar("arquivos grandes → Lixeira: \(n) itens")
        itens.removeAll { selecao.contains($0.id) && !Caminho.existe($0.id) }
        selecao.removeAll()
    }
}

struct GrandesView: View {
    @ObservedObject private var m = GrandesModelo.compartilhado
    @State private var confirmando = false

    var totalSel: Int64 { m.itens.filter { m.selecao.contains($0.id) }.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Mostrar arquivos acima de")
                Picker("", selection: $m.minimoMB) {
                    Text("100 MB").tag(100); Text("500 MB").tag(500); Text("1 GB").tag(1000); Text("5 GB").tag(5000)
                }
                .labelsHidden().frame(width: 110)
                Button(m.buscando ? "Procurando…" : "Procurar") { Task { await m.buscar() } }
                    .disabled(m.buscando)
                if m.buscando { ProgressView().controlSize(.small); Text("\(m.vistos) arquivos vistos").foregroundStyle(.secondary) }
                Spacer()
            }
            .padding(14)
            Divider()
            if !m.buscou && !m.buscando {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.ellipsis").font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("Procura vídeos, brutos, backups e arquivos esquecidos na sua pasta pessoal.").foregroundStyle(.secondary)
                    Text("Nada é apagado sem você escolher. O que você apagar vai pra Lixeira.").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $m.selecao) {
                    ForEach(m.itens) { g in
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: g.id)).resizable().frame(width: 26, height: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    if g.protegido { Image(systemName: "lock.fill").foregroundStyle(.orange) }
                                    Text(g.nome).lineLimit(1)
                                    if let a = g.aviso { Etiqueta(a, g.protegido ? .orange : .gray) }
                                }
                                Text(Caminho.curto(g.pasta)).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            }
                            .opacity(g.protegido ? 0.6 : 1)
                            Spacer()
                            Text(dataCurta(g.modificado)).font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                            Text(tamanho(g.bytes)).monospacedDigit().frame(width: 80, alignment: .trailing)
                            Button { mostrarNoFinder([g.id]) } label: { Image(systemName: "magnifyingglass") }.buttonStyle(.borderless)
                        }
                        .tag(g.id)
                        .semSelecao(g.protegido)
                    }
                }
                .listStyle(.inset)
            }
            Divider()
            HStack {
                Text("\(m.itens.count) arquivos · \(tamanho(m.itens.reduce(0) { $0 + $1.bytes }))").foregroundStyle(.secondary)
                Spacer()
                Button("Mover \(m.selecao.count) pra Lixeira (\(tamanho(totalSel)))") { confirmando = true }
                    .disabled(m.selecao.isEmpty)
            }
            .padding(14)
        }
        .navigationTitle("Arquivos grandes")
        .alert("Mover \(m.selecao.count) arquivos pra Lixeira?", isPresented: $confirmando) {
            Button("Mover pra Lixeira", role: .destructive) { Task { await m.lixeira() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Ficam na Lixeira até você esvaziar. Dá pra recuperar até lá.")
        }
    }
}

// MARK: - Mapa do espaço

@MainActor
final class MapaModelo: ObservableObject {
    static let compartilhado = MapaModelo()
    @Published var pilha: [String] = [Caminho.casa]
    @Published var itens: [ItemMapa] = []
    @Published var carregando = false
    private var memoria: [String: [ItemMapa]] = [:]

    var atual: String { pilha.last ?? Caminho.casa }

    func carregar(forcar: Bool = false) async {
        let p = atual
        if !forcar, let m = memoria[p] { itens = m; return }
        carregando = true
        itens = []
        let r = await Task.detached(priority: .userInitiated) { Mapa.filhos(de: p) }.value
        memoria[p] = r
        if atual == p { itens = r }
        carregando = false
    }

    func entrar(_ p: String) async { pilha.append(p); await carregar() }
    func voltar() async { if pilha.count > 1 { pilha.removeLast(); await carregar() } }
    func raiz(_ p: String) async { pilha = [p]; await carregar() }
}

struct MapaView: View {
    @ObservedObject private var m = MapaModelo.compartilhado

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { Task { await m.voltar() } } label: { Image(systemName: "chevron.left") }.disabled(m.pilha.count < 2)
                Text(Caminho.curto(m.atual)).font(.headline).lineLimit(1).truncationMode(.head)
                Spacer()
                Menu("Começar em") {
                    Button("Pasta pessoal") { Task { await m.raiz(Caminho.casa) } }
                    Button("Biblioteca (oculta)") { Task { await m.raiz(Caminho.casa + "/Library") } }
                    Button("Aplicativos") { Task { await m.raiz("/Applications") } }
                }
                .frame(width: 130)
                Button { Task { await m.carregar(forcar: true) } } label: { Image(systemName: "arrow.clockwise") }
            }
            .padding(14)
            Divider()
            if m.carregando {
                VStack(spacing: 10) { ProgressView(); Text("Medindo as pastas…").foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let maior = max(m.itens.first?.bytes ?? 1, 1)
                List(m.itens) { i in
                    HStack(spacing: 10) {
                        Group {
                            if i.pasta {
                                Image(systemName: "folder.fill").foregroundStyle(Color.accentColor)
                            } else {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: i.id)).resizable()
                            }
                        }
                        .frame(width: 18, height: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(i.nome).lineLimit(1)
                                if i.oculta { Etiqueta("oculta", .orange) }
                            }
                            if let d = i.dica { Text(d).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                        }
                        Spacer()
                        GeometryReader { g in
                            Capsule().fill(Color.accentColor.opacity(0.35))
                                .frame(width: max(2, g.size.width * CGFloat(Double(i.bytes) / Double(maior))))
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(width: 140, height: 8)
                        Text(tamanho(i.bytes)).monospacedDigit().frame(width: 80, alignment: .trailing)
                        Button { mostrarNoFinder([i.id]) } label: { Image(systemName: "magnifyingglass") }.buttonStyle(.borderless)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { if i.pasta { Task { await m.entrar(i.id) } } }
                    .help(i.pasta ? "Clique duas vezes pra entrar" : "")
                }
                .listStyle(.inset)
            }
            Divider()
            Text("Clique duas vezes numa pasta pra ver o que tem dentro. Pastas ocultas aparecem marcadas.")
                .font(.caption).foregroundStyle(.secondary).padding(10)
        }
        .navigationTitle("Mapa do espaço")
        .task { if m.itens.isEmpty { await m.carregar() } }
    }
}

// MARK: - Desinstalar apps

@MainActor
final class DesinstalarModelo: ObservableObject {
    static let compartilhado = DesinstalarModelo()
    @Published var apps: [AppInstalado] = []
    @Published var orfas: [Sobra] = []
    @Published var orfasMarcadas = Set<String>()
    @Published var carregando = false
    @Published var aviso: String?

    func carregar() async {
        carregando = true
        let (a, o) = await Task.detached(priority: .userInitiated) { () -> ([AppInstalado], [Sobra]) in
            let a = Desinstalador.listar()
            return (a, Desinstalador.orfas(instalados: a.map(\.bundle)))
        }.value
        apps = a
        orfas = o
        carregando = false
    }

    func desinstalar(_ app: AppInstalado) async {
        if let rodando = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundle).first {
            _ = await Apps.fechar([rodando])
        }
        let n = await Lixeira.mandar([app.id] + app.sobras)
        Historico.anotar("desinstalou: \(app.nome) (\(n) itens → Lixeira)")
        aviso = n > 0 ? "\(app.nome) foi pra Lixeira com \(max(0, n - 1)) sobras. Esvazie a Lixeira pra liberar \(tamanho(app.total))."
                      : "Não consegui mover \(app.nome). Tente arrastar pra Lixeira pelo Finder."
        apps.removeAll { $0.id == app.id && !Caminho.existe(app.id) }
    }

    func limparOrfas() async {
        let n = await Lixeira.mandar(Array(orfasMarcadas))
        Historico.anotar("sobras de apps → Lixeira: \(n) itens")
        orfas.removeAll { orfasMarcadas.contains($0.id) && !Caminho.existe($0.id) }
        orfasMarcadas.removeAll()
        aviso = "\(n) sobras foram pra Lixeira."
    }
}

struct DesinstalarView: View {
    @ObservedObject private var m = DesinstalarModelo.compartilhado
    @State private var confirmar: AppInstalado?
    @State private var confirmarOrfas = false

    var body: some View {
        VStack(spacing: 0) {
            if m.carregando && m.apps.isEmpty {
                VStack(spacing: 10) { ProgressView(); Text("Medindo os apps e o que eles deixam espalhado…").foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Apps instalados (com o que eles guardam na sua pasta)") {
                        ForEach(m.apps) { a in
                            HStack(spacing: 10) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: a.id)).resizable().frame(width: 28, height: 28)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(a.nome)
                                    Text("app \(tamanho(a.bytesApp)) · dados \(tamanho(a.bytesSobras))\(a.versao.isEmpty ? "" : " · v\(a.versao)")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(tamanho(a.total)).monospacedDigit()
                                if a.daAdobe {
                                    Text("desinstale pelo Creative Cloud").font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Button("Desinstalar") { confirmar = a }.controlSize(.small)
                                }
                            }
                        }
                    }
                    if !m.orfas.isEmpty {
                        Section("Sobras de apps que já não estão no Mac") {
                            ForEach(m.orfas) { o in
                                HStack {
                                    Toggle("", isOn: Binding(get: { m.orfasMarcadas.contains(o.id) },
                                                             set: { v in if v { m.orfasMarcadas.insert(o.id) } else { m.orfasMarcadas.remove(o.id) } }))
                                        .toggleStyle(.checkbox).labelsHidden()
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(o.nome)
                                        Text(Caminho.curto(Caminho.pai(o.id))).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(tamanho(o.bytes)).monospacedDigit()
                                    Button { mostrarNoFinder([o.id]) } label: { Image(systemName: "magnifyingglass") }.buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
            Divider()
            HStack {
                if let a = m.aviso { Label(a, systemImage: "info.circle").lineLimit(2) }
                Spacer()
                if !m.orfas.isEmpty {
                    Button("Mover \(m.orfasMarcadas.count) sobras pra Lixeira") { confirmarOrfas = true }
                        .disabled(m.orfasMarcadas.isEmpty)
                }
            }
            .padding(14)
        }
        .navigationTitle("Desinstalar apps")
        .toolbar {
            ToolbarItem {
                Button { Task { await m.carregar() } } label: {
                    if m.carregando { ProgressView().controlSize(.small) } else { Label("Atualizar", systemImage: "arrow.clockwise") }
                }
            }
        }
        .task { if m.apps.isEmpty { await m.carregar() } }
        .alert(item: $confirmar) { a in
            Alert(title: Text("Desinstalar \(a.nome)?"),
                  message: Text("O app e \(a.sobras.count) pastas de dados (\(tamanho(a.total))) vão pra Lixeira. Se ele estiver aberto, eu fecho antes."),
                  primaryButton: .destructive(Text("Desinstalar")) { Task { await m.desinstalar(a) } },
                  secondaryButton: .cancel(Text("Cancelar")))
        }
        .alert("Mover \(m.orfasMarcadas.count) sobras pra Lixeira?", isPresented: $confirmarOrfas) {
            Button("Mover", role: .destructive) { Task { await m.limparOrfas() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("São pastas de apps que não encontrei instalados. Confira os nomes antes. Dá pra recuperar da Lixeira.")
        }
    }
}

// MARK: - Segundo plano

struct SegundoPlanoView: View {
    @State private var tarefas: [Tarefa] = []
    @State private var navegadores: [String] = []
    @State private var carregando = true

    func carregar() async {
        carregando = true
        let (t, n) = await Task.detached { (Tarefas.listar(), Tarefas.navegadoresControlados()) }.value
        tarefas = t
        navegadores = n
        carregando = false
    }

    var body: some View {
        List {
            if !navegadores.isEmpty {
                Section("Atenção") {
                    ForEach(Array(Set(navegadores)), id: \.self) { n in
                        Label("\(n) está com controle remoto ligado. Qualquer programa do Mac pode comandar esse navegador. Se não é uma automação sua, feche ele.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            Section("Tarefas que rodam sozinhas (LaunchAgents)") {
                ForEach(tarefas) { t in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: t.desligada ? "pause.circle" : (t.rodando ? "play.circle.fill" : "circle"))
                            .foregroundStyle(t.desligada ? Color.secondary : (t.rodando ? Color.green : Color.secondary))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(t.label).fontWeight(.medium)
                                if !t.doUsuario { Etiqueta("do sistema", .gray) }
                                if t.reabreApp { Etiqueta("reabre app sozinho", .orange) }
                                if t.programaSumiu { Etiqueta("programa não existe mais", .red) }
                                if let er = t.erro { Etiqueta("erro \(er)", .red) }
                                if t.desligada { Etiqueta("pausada", .gray) }
                            }
                            Text(Caminho.curto(t.programa)).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        if t.doUsuario {
                            if t.desligada {
                                Button("Religar") { Tarefas.religar(t); Task { await carregar() } }.controlSize(.small)
                            } else {
                                Button("Pausar") { Tarefas.pausar(t); Task { await carregar() } }.controlSize(.small)
                                    .help("Para e não volta ao reiniciar. Dá pra religar aqui.")
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.inset)
        .overlay { if carregando && tarefas.isEmpty { ProgressView() } }
        .navigationTitle("Segundo plano")
        .toolbar { ToolbarItem { Button { Task { await carregar() } } label: { Label("Atualizar", systemImage: "arrow.clockwise") } } }
        .task { await carregar() }
    }
}

// MARK: - Ajustes

struct AjustesView: View {
    @EnvironmentObject var e: Estado

    var body: some View {
        Form {
            Section("Meta") {
                Stepper(value: $e.metaGB, in: 5...200, step: 5) {
                    Text("Manter pelo menos **\(e.metaGB) GB** livres")
                }
                Text("Abaixo disso, o ícone da barra fica vermelho e a Faxina avisa.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Vigia") {
                Toggle("Vigiar o disco (a cada 30 minutos)", isOn: $e.vigiaLigada)
                Toggle("Limpar o lixo seguro sozinho quando passar da meta", isOn: $e.limparSozinho)
                    .disabled(!e.vigiaLigada)
                Toggle("Abrir a Faxina quando o Mac ligar", isOn: Binding(get: { e.abrirAoLigar }, set: { e.mudarAbrirAoLigar($0) }))
                Text("A vigia avisa quando o espaço fica abaixo da meta, quando o disco perde mais de 10 GB em 24 horas e quando um app trava em loop (os relatórios de erro são apagados sozinhos).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Permissões") {
                Text("Pra medir a Lixeira, o Safari e os dados de outros apps, a Faxina precisa de Acesso Total ao Disco. Sem isso ela funciona, só não enxerga essas pastas.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Abrir Acesso Total ao Disco") {
                    if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") { NSWorkspace.shared.open(u) }
                }
            }
            Section("Histórico") {
                Text("Tudo o que a Faxina apaga fica anotado em ~/Library/Logs/Faxina.log").font(.caption).foregroundStyle(.secondary)
                Button("Abrir histórico") {
                    if !Caminho.existe(Historico.arquivo) { Historico.anotar("histórico criado") }
                    NSWorkspace.shared.open(URL(fileURLWithPath: Historico.arquivo))
                }
            }
            Section("Sobre") {
                Text("Faxina 1.0 — código aberto (MIT). A lista de caches e a separação entre seguro e revise partiram do Disco Livre (MIT, Willian Carlos Lameu).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Ajustes")
    }
}
