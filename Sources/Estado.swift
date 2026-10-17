import AppKit
import Foundation
import ServiceManagement
import UserNotifications

struct Item: Identifiable {
    let alvo: Alvo
    var bytes: Int64
    var abertos: [String]
    var id: String { alvo.id }
    var bloqueado: Bool { !abertos.isEmpty }
}

@MainActor
final class Estado: ObservableObject {
    static let compartilhado = Estado()

    @Published var disco = InfoDisco()
    @Published var itens: [Item] = []
    @Published var analisando = false
    @Published var analisadoEm: Date?
    @Published var marcados: Set<String> = []
    @Published var limpando = false
    @Published var resultado: String?
    @Published var fechando: Set<String> = []

    private let pref = UserDefaults.standard
    @Published var metaGB: Int { didSet { pref.set(metaGB, forKey: "metaGB") } }
    @Published var vigiaLigada: Bool { didSet { pref.set(vigiaLigada, forKey: "vigiaLigada") } }
    @Published var limparSozinho: Bool { didSet { pref.set(limparSozinho, forKey: "limparSozinho") } }
    @Published var abrirAoLigar: Bool = SMAppService.mainApp.status == .enabled

    init() {
        metaGB = pref.object(forKey: "metaGB") as? Int ?? 30
        vigiaLigada = pref.object(forKey: "vigiaLigada") as? Bool ?? true
        limparSozinho = pref.object(forKey: "limparSozinho") as? Bool ?? false
    }

    var metaBytes: Int64 { Int64(metaGB) * 1_000_000_000 }
    var abaixoDaMeta: Bool { disco.total > 0 && disco.livre < metaBytes }

    /// Itens pequenos demais (menos de 5 MB) não aparecem.
    var visiveis: [Item] { itens.filter { $0.bytes >= 5_000_000 } }
    var seguros: [Item] { visiveis.filter { $0.alvo.nivel == .seguro } }
    var totalSeguroLivre: Int64 { seguros.filter { !$0.bloqueado }.reduce(0) { $0 + $1.bytes } }
    var totalSeguro: Int64 { seguros.reduce(0) { $0 + $1.bytes } }
    var totalRevisar: Int64 { visiveis.filter { $0.alvo.nivel == .revisar }.reduce(0) { $0 + $1.bytes } }
    var totalMarcado: Int64 { visiveis.filter { marcados.contains($0.id) }.reduce(0) { $0 + $1.bytes } }

    // MARK: disco e análise

    func atualizarDisco() async {
        disco = await Task.detached(priority: .utility) { lerDisco() }.value
    }

    func analisar() async {
        guard !analisando else { return }
        analisando = true
        let medidos: [(Alvo, Int64)] = await Task.detached(priority: .userInitiated) {
            let alvos = Catalogo.montar()
            let bytes = emParalelo(alvos.count) { Medidor.bytes(de: alvos[$0]) }
            return Array(zip(alvos, bytes))
        }.value
        let antesMarcados = marcados
        itens = medidos.map { Item(alvo: $0.0, bytes: $0.1, abertos: Apps.nomesAbertos($0.0)) }
        if analisadoEm == nil {
            marcados = Set(seguros.filter { !$0.bloqueado }.map(\.id))
        } else {
            let ids = Set(itens.filter { !$0.bloqueado }.map(\.id))
            marcados = antesMarcados.intersection(ids)
        }
        analisadoEm = Date()
        analisando = false
        await atualizarDisco()
    }

    func conferirAbertos() {
        for i in itens.indices { itens[i].abertos = Apps.nomesAbertos(itens[i].alvo) }
        let livres = Set(itens.filter { !$0.bloqueado }.map(\.id))
        marcados = marcados.intersection(livres)
    }

    func fecharApps(de item: Item) async {
        fechando.insert(item.id)
        _ = await Apps.fechar(Apps.abertos(ids: item.alvo.apps, nomes: item.alvo.nomesApps))
        try? await Task.sleep(nanoseconds: 800_000_000)
        fechando.remove(item.id)
        conferirAbertos()
        if let i = itens.firstIndex(where: { $0.id == item.id }), !itens[i].bloqueado { marcados.insert(item.id) }
    }

    func marcarTodoSeguro() {
        marcados.formUnion(seguros.filter { !$0.bloqueado }.map(\.id))
    }

    // MARK: limpeza

    @discardableResult
    func limpar(_ ids: Set<String>) async -> Int64 {
        conferirAbertos()
        let escolhidos = visiveis.filter { ids.contains($0.id) && !$0.bloqueado }
        guard !escolhidos.isEmpty, !limpando else { return 0 }
        limpando = true
        resultado = nil
        let antes = disco.livre
        let previsto = escolhidos.reduce(0) { $0 + $1.bytes }
        let alvos = escolhidos.map(\.alvo)
        await Task.detached(priority: .userInitiated) { for a in alvos { Faxineiro.limpar(a) } }.value
        await atualizarDisco()
        let ganho = max(0, disco.livre - antes)
        resultado = "Liberei \(tamanho(max(ganho, previsto))) em \(escolhidos.count) itens. Livre agora: \(tamanho(disco.livre))."
        Historico.anotar("limpeza: \(escolhidos.count) itens, previsto \(tamanho(previsto)), livre \(tamanho(antes)) → \(tamanho(disco.livre))")
        limpando = false
        await analisar()
        return ganho
    }

    func limparSeguro() async {
        conferirAbertos()
        await limpar(Set(seguros.filter { !$0.bloqueado }.map(\.id)))
    }

    func mudarAbrirAoLigar(_ v: Bool) {
        do {
            if v { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {}
        abrirAoLigar = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - Avisos (notificações do macOS)

enum Aviso {
    static func pedirPermissao() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Manda no máximo um aviso de cada tipo a cada `intervalo` segundos.
    static func mandar(_ titulo: String, _ texto: String, chave: String, intervalo: TimeInterval) {
        let k = "aviso." + chave
        let agora = Date().timeIntervalSince1970
        if agora - UserDefaults.standard.double(forKey: k) < intervalo { return }
        UserDefaults.standard.set(agora, forKey: k)
        let c = UNMutableNotificationContent()
        c.title = titulo
        c.body = texto
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }
}

// MARK: - Vigia: confere o disco a cada 30 min enquanto o app está aberto

@MainActor
final class Vigia {
    static let compartilhada = Vigia()
    private var timer: Timer?
    private let chaveHist = "historicoLivre"

    func iniciar() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in
            Task { @MainActor in await Vigia.compartilhada.rodada() }
        }
        Task { await rodada() }
    }

    func rodada() async {
        let e = Estado.compartilhado
        await e.atualizarDisco()
        registrar(e.disco.livre)
        guard e.vigiaLigada else { return }

        // 1. app travando em loop: os relatórios de erro enchem o disco em dias
        let surtos = await Task.detached(priority: .utility) { Vigia.surtosDeCrash() }.value
        for (app, n, bytes) in surtos {
            Aviso.mandar("\(app) está travando sem parar",
                         "Apaguei \(n) relatórios de erro (\(tamanho(bytes))). Vale reiniciar ou atualizar o app.",
                         chave: "crash.\(app)", intervalo: 21_600)
        }

        // 2. queda rápida: algo novo está enchendo o disco
        if let maximo = maximoUltimas24h(), maximo - e.disco.livre > 10_000_000_000 {
            Aviso.mandar("Seu disco está enchendo rápido",
                         "Você perdeu \(tamanho(maximo - e.disco.livre)) nas últimas 24 horas. Abra a Faxina pra ver o quê.",
                         chave: "queda", intervalo: 43_200)
        }

        // 3. abaixo da meta
        if e.abaixoDaMeta {
            if e.limparSozinho {
                await e.analisar()
                let ganho = await e.limpar(Set(e.seguros.filter { !$0.bloqueado }.map(\.id)))
                if ganho > 0 {
                    Aviso.mandar("Limpeza automática", "Liberei \(tamanho(ganho)). Agora: \(tamanho(e.disco.livre)) livres.",
                                 chave: "auto", intervalo: 3600)
                }
            }
            if e.abaixoDaMeta {
                Aviso.mandar("Pouco espaço: \(tamanho(e.disco.livre)) livres",
                             "Sua meta é \(e.metaGB) GB. Abra a Faxina pra liberar.", chave: "meta", intervalo: 21_600)
            }
        }
    }

    /// Pastas de relatório de erro com mais de 500 arquivos: apaga e avisa.
    nonisolated static func surtosDeCrash() -> [(String, Int, Int64)] {
        let AS = Caminho.casa + "/Library/Application Support"
        var r: [(String, Int, Int64)] = []
        for c in expandir("\(AS)/*/Crashpad") + expandir("\(AS)/*/*/Crashpad") {
            let arquivos = (FileManager.default.enumerator(atPath: c)?.allObjects.count) ?? 0
            guard arquivos > 500 else { continue }
            let bytes = medir(c)
            for s in ["pending", "completed", "new"] {
                for f in Caminho.filhos(c + "/" + s) { try? FileManager.default.removeItem(atPath: f) }
            }
            let app = Caminho.nome(Caminho.pai(c))
            Historico.anotar("surto de crash: \(app) — \(arquivos) relatórios (\(tamanho(bytes)))")
            r.append((app, arquivos, bytes))
        }
        return r
    }

    private func registrar(_ livre: Int64) {
        var h = (UserDefaults.standard.array(forKey: chaveHist) as? [[Double]]) ?? []
        let agora = Date().timeIntervalSince1970
        h.append([agora, Double(livre)])
        h = h.filter { agora - $0[0] < 14 * 86_400 }
        UserDefaults.standard.set(h, forKey: chaveHist)
    }

    private func maximoUltimas24h() -> Int64? {
        let h = (UserDefaults.standard.array(forKey: chaveHist) as? [[Double]]) ?? []
        let agora = Date().timeIntervalSince1970
        let m = h.filter { agora - $0[0] < 86_400 }.map { $0[1] }.max()
        return m.map { Int64($0) }
    }
}
