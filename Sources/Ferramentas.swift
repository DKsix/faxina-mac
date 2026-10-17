import AppKit
import Foundation

// MARK: - Arquivos grandes

struct Grande: Identifiable, Hashable {
    let id: String
    let nome: String
    let pasta: String
    let bytes: Int64
    let modificado: Date?

    /// Arquivo de que um app depende (catálogo, banco de dados, dado interno): não pode ir pra Lixeira daqui.
    var protegido: Bool { Grande.motivoProtecao(id) != nil }
    var aviso: String? {
        if let m = Grande.motivoProtecao(id) { return m }
        if id.contains("/Library/") || id.dropFirst(Caminho.casa.count).contains("/.") {
            return "arquivo de app — prefira a Limpeza"
        }
        return nil
    }

    static func motivoProtecao(_ p: String) -> String? {
        let ext = (p as NSString).pathExtension.lowercased()
        if ["lrcat", "lrcat-wal", "lrcat-shm"].contains(ext) || p.contains(".lrcat-data/") { return "catálogo do Lightroom — não apague" }
        if p.contains(".lrdata/") { return "prévias do Lightroom — limpe pelo Lightroom" }
        if ["sqlite", "sqlite-wal", "sqlite-shm", "db", "realm"].contains(ext) { return "banco de dados de app — não apague" }
        if p.contains(".photoslibrary/") { return "biblioteca do Fotos — use o app Fotos" }
        if p.contains(".app/") { return "parte de um app — use Desinstalar" }
        if p.contains("/Library/Group Containers/") || p.contains("/Library/Containers/") || p.contains("/Library/Mail/") {
            return "dado interno de app — use a Limpeza"
        }
        return nil
    }
}

enum BuscaGrandes {
    /// Varre a pasta pessoal atrás de arquivos acima do mínimo. Pula a Lixeira.
    static func buscar(minimo: Int64, progresso: @escaping (Int) -> Void) -> [Grande] {
        let chaves: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .contentModificationDateKey]
        let raiz = URL(fileURLWithPath: Caminho.casa)
        guard let en = FileManager.default.enumerator(at: raiz, includingPropertiesForKeys: chaves, options: [],
                                                      errorHandler: { _, _ in true }) else { return [] }
        let lixeira = Caminho.casa + "/.Trash"
        var r: [Grande] = []
        var n = 0
        while let u = en.nextObject() as? URL {
            n += 1
            if n % 5000 == 0 { progresso(n) }
            if u.path == lixeira { en.skipDescendants(); continue }
            guard let v = try? u.resourceValues(forKeys: Set(chaves)), v.isRegularFile == true else { continue }
            let b = Int64(v.totalFileAllocatedSize ?? 0)
            if b >= minimo {
                r.append(Grande(id: u.path, nome: u.lastPathComponent, pasta: Caminho.pai(u.path), bytes: b,
                                modificado: v.contentModificationDate))
            }
        }
        progresso(n)
        return r.sorted { $0.bytes > $1.bytes }
    }
}

// MARK: - Mapa do espaço

struct ItemMapa: Identifiable {
    let id: String
    let nome: String
    let bytes: Int64
    let pasta: Bool
    let oculta: Bool
    let dica: String?
}

enum Mapa {
    static func filhos(de pasta: String) -> [ItemMapa] {
        let cams = Caminho.filhos(pasta).filter { !$0.hasSuffix("/.DS_Store") }
        let bytes = emParalelo(cams.count) { medir(cams[$0]) }
        return zip(cams, bytes).map { c, b in
            let n = Caminho.nome(c)
            return ItemMapa(id: c, nome: n, bytes: b, pasta: Caminho.ehPasta(c) && !c.hasSuffix(".app"),
                            oculta: n.hasPrefix("."), dica: dica(c))
        }.sorted { $0.bytes > $1.bytes }
    }

    /// Explicação curta das pastas que mais confundem (parte vem do Disco Livre).
    static func dica(_ p: String) -> String? {
        let regras: [(String, String)] = [
            ("group.net.whatsapp", "Mídia do WhatsApp — dá pra limpar na Limpeza"),
            ("Adobe Camera Raw", "Cache do Camera Raw — dá pra limpar na Limpeza"),
            (".lrdata", "Prévias do Lightroom. Lightroom → Biblioteca → Prévias → Descartar prévias 1:1"),
            ("Evoto_pro", "Evoto: o cache dá pra limpar na Limpeza"),
            ("coreMLCache", "Modelos de IA compilados (Evoto e parecidos)"),
            ("Claude/vm_bundles", "Máquina virtual do Cowork, do app Claude"),
            ("huggingface", "Modelos de IA locais"),
            ("whisper", "Modelos de transcrição"),
            (".lmstudio", "Modelos de IA do LM Studio"),
            (".ollama", "Modelos de IA do Ollama"),
            ("Crashpad", "Relatórios de erro — lixo"),
            ("Movies/.gallery", "Stills da galeria do DaVinci Resolve"),
            ("CacheClip", "Render cache do DaVinci — dá pra limpar"),
            ("Blackmagic Design", "DaVinci Resolve (bancos de projetos, LUTs)"),
            ("MobileSync", "Backups do iPhone. Finder → seu iPhone → Gerenciar backups"),
            ("CoreSimulator", "Simuladores do Xcode"),
            ("Steam", "Jogos da Steam. Desinstale pelo app"),
            ("Library/Containers", "Dados de apps da App Store"),
            ("Library/Group Containers", "Dados compartilhados de apps (WhatsApp, Telegram, Office…)"),
            ("/Library/Caches", "Caches de apps — a Limpeza cuida"),
            ("/Library/Logs", "Logs — os antigos saem na Limpeza"),
            ("/.npm", "Cache do npm — a Limpeza cuida"),
            ("/.cache", "Caches de ferramentas e modelos de IA"),
            ("/.Trash", "Lixeira"),
            (".photoslibrary", "Fotos. Ative 'Otimizar armazenamento' no app Fotos"),
        ]
        return regras.first { p.contains($0.0) }?.1
    }
}

// MARK: - Desinstalador

struct AppInstalado: Identifiable {
    let id: String
    let nome: String
    let bundle: String
    let versao: String
    let bytesApp: Int64
    let sobras: [String]
    let bytesSobras: Int64
    var total: Int64 { bytesApp + bytesSobras }
    var daAdobe: Bool { bundle.hasPrefix("com.adobe.") }
}

struct Sobra: Identifiable {
    let id: String
    let nome: String
    let bytes: Int64
}

enum Desinstalador {
    static func caminhosDosApps() -> [String] {
        var r: [String] = []
        for p in ["/Applications/*.app", "/Applications/*/*.app", "~/Applications/*.app"] { r += expandir(p) }
        return r
    }

    static func listar() -> [AppInstalado] {
        let cams = caminhosDosApps().filter { c in
            guard let id = Bundle(path: c)?.bundleIdentifier else { return false }
            return !id.hasPrefix("com.apple.") && id != Bundle.main.bundleIdentifier
        }
        return emParalelo(cams.count) { i -> AppInstalado in
            let c = cams[i]
            let b = Bundle(path: c)
            let id = b?.bundleIdentifier ?? ""
            let nome = (b?.infoDictionary?["CFBundleName"] as? String) ?? Caminho.nome(c).replacingOccurrences(of: ".app", with: "")
            let arquivo = Caminho.nome(c).replacingOccurrences(of: ".app", with: "")
            let sob = sobras(bundle: id, nomes: [nome, arquivo])
            return AppInstalado(id: c, nome: arquivo, bundle: id,
                                versao: (b?.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "",
                                bytesApp: medir(c), sobras: sob, bytesSobras: sob.reduce(0) { $0 + medir($1) })
        }.sorted { $0.total > $1.total }
    }

    /// Onde os apps deixam coisas na pasta pessoal.
    static func sobras(bundle id: String, nomes: [String]) -> [String] {
        guard !id.isEmpty else { return [] }
        let L = Caminho.casa + "/Library"
        var pads = ["\(L)/Application Support/\(id)", "\(L)/Caches/\(id)", "\(L)/Containers/\(id)",
                    "\(L)/Preferences/\(id).plist", "\(L)/Preferences/ByHost/\(id).*.plist",
                    "\(L)/Saved Application State/\(id).savedState", "\(L)/HTTPStorages/\(id)",
                    "\(L)/HTTPStorages/\(id).binarycookies", "\(L)/WebKit/\(id)", "\(L)/Logs/\(id)",
                    "\(L)/LaunchAgents/\(id)*.plist", "\(L)/Application Scripts/\(id)",
                    "\(L)/Cookies/\(id).binarycookies"]
        if id.split(separator: ".").count >= 3 { pads.append("\(L)/Group Containers/*\(id)*") }
        for n in Set(nomes) where n.count >= 3 {
            pads += ["\(L)/Application Support/\(n)", "\(L)/Caches/\(n)", "\(L)/Logs/\(n)"]
        }
        var r: [String] = []
        for p in pads { for c in expandir(p) where !r.contains(c) && Seguranca.podeApagarArquivo(c) { r.append(c) } }
        return r
    }

    /// "com.adobe.dunamis" → "com.adobe"
    static func fabricante(_ id: String) -> String? {
        let p = id.split(separator: ".")
        return p.count >= 3 ? "\(p[0]).\(p[1])".lowercased() : nil
    }

    /// Nomes (em minúsculas, tudo junto) de plugins de vídeo, foto e áudio instalados.
    static func nomesDePlugins() -> String {
        let L = Caminho.casa + "/Library"
        let pastas = ["/Library/OFX/Plugins", "\(L)/OFX/Plugins",
                      "/Library/Application Support/Adobe/Lightroom/Modules", "\(L)/Application Support/Adobe/Lightroom/Modules",
                      "/Library/Application Support/Adobe/Plug-Ins", "/Library/Audio/Plug-Ins/Components",
                      "/Library/Audio/Plug-Ins/VST3", "\(L)/Audio/Plug-Ins/Components", "/Library/Application Support"]
            + expandir("/Applications/Adobe Photoshop*/Plug-ins")
        return pastas.flatMap { Caminho.filhos($0).map { Caminho.nome($0).lowercased() } }.joined(separator: "|")
    }

    /// Pastas de apps que já não estão mais no Mac (pelo nome em formato de bundle id).
    static func orfas(instalados: [String]) -> [Sobra] {
        let L = Caminho.casa + "/Library"
        var cands: [String] = []
        for base in ["Containers", "Application Support", "Saved Application State", "HTTPStorages", "WebKit"] {
            cands += Caminho.filhos("\(L)/\(base)")
        }
        // fabricantes com algum app instalado (com.adobe, com.google…): os ajudantes deles não são sobra
        let fabricantes = Set(instalados.compactMap { fabricante($0) })
        let plugins = nomesDePlugins()
        let filtrados = cands.filter { c in
            let n = Caminho.nome(c).replacingOccurrences(of: ".savedState", with: "").replacingOccurrences(of: ".binarycookies", with: "")
            let partes = n.split(separator: ".")
            guard partes.count >= 3, !n.hasPrefix("com.apple."), !n.hasPrefix("group.") else { return false }
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: n) != nil { return false }
            // extensões e ajudantes de apps instalados usam o id do app como prefixo
            if instalados.contains(where: { n.hasPrefix($0) || $0.hasPrefix(n) }) { return false }
            if let f = fabricante(n), fabricantes.contains(f) { return false }
            // plugin instalado (ex.: Dehancer no DaVinci) guarda dados com o nome do fabricante
            let marca = partes[1].lowercased()
            if marca.count >= 4, plugins.contains(marca) { return false }
            return true
        }
        let bytes = emParalelo(filtrados.count) { medir(filtrados[$0]) }
        return zip(filtrados, bytes).filter { $0.1 >= 1_000_000 }
            .map { Sobra(id: $0.0, nome: Caminho.nome($0.0), bytes: $0.1) }
            .sorted { $0.bytes > $1.bytes }
    }
}

// MARK: - Tarefas em segundo plano

struct Tarefa: Identifiable {
    let id: String
    let label: String
    let arquivo: String
    let programa: String
    let reabreApp: Bool
    let rodando: Bool
    let desligada: Bool
    let doUsuario: Bool
    let programaSumiu: Bool
    let erro: Int?
}

enum Tarefas {
    static var dominio: String { "gui/\(getuid())" }

    static func listar() -> [Tarefa] {
        var estado: [String: (String, String)] = [:]
        for l in rodar("/bin/launchctl", ["list"]).saida.split(separator: "\n").dropFirst() {
            let c = l.split(separator: "\t", omittingEmptySubsequences: false)
            if c.count >= 3 { estado[String(c[2])] = (String(c[0]), String(c[1])) }
        }
        let desat = rodar("/bin/launchctl", ["print-disabled", dominio]).saida
        var r: [Tarefa] = []
        for (pasta, usuario) in [(Caminho.casa + "/Library/LaunchAgents", true), ("/Library/LaunchAgents", false),
                                 ("/Library/LaunchDaemons", false)] {
            for f in Caminho.filhos(pasta) where f.hasSuffix(".plist") {
                guard let d = NSDictionary(contentsOfFile: f) as? [String: Any], let label = d["Label"] as? String else { continue }
                let prog = (d["ProgramArguments"] as? [String])?.first ?? (d["Program"] as? String) ?? ""
                let ka = d["KeepAlive"]
                let reabre = prog.contains(".app/Contents/MacOS/") && ((ka as? Bool) == true || ka is [String: Any])
                let st = estado[label]
                let rodando = st.map { $0.0 != "-" } ?? false
                var erro: Int? = nil
                if let st, st.0 == "-", let e = Int(st.1), e != 0 { erro = e }
                let deslig = desat.contains("\"\(label)\" => disabled") || desat.contains("\"\(label)\" => true")
                let sumiu = prog.hasPrefix("/") && !Caminho.existe(prog)
                r.append(Tarefa(id: f, label: label, arquivo: f, programa: prog, reabreApp: reabre, rodando: rodando,
                                desligada: deslig, doUsuario: usuario, programaSumiu: sumiu, erro: erro))
            }
        }
        return r.sorted { ($0.doUsuario ? 0 : 1, $0.label) < ($1.doUsuario ? 0 : 1, $1.label) }
    }

    static func pausar(_ t: Tarefa) {
        rodar("/bin/launchctl", ["bootout", "\(dominio)/\(t.label)"])
        rodar("/bin/launchctl", ["disable", "\(dominio)/\(t.label)"])
        Historico.anotar("pausou tarefa: \(t.label)")
    }

    static func religar(_ t: Tarefa) {
        rodar("/bin/launchctl", ["enable", "\(dominio)/\(t.label)"])
        rodar("/bin/launchctl", ["bootstrap", dominio, t.arquivo])
        Historico.anotar("religou tarefa: \(t.label)")
    }

    /// Navegadores abertos com --remote-debugging-port (qualquer programa pode comandar).
    static func navegadoresControlados() -> [String] {
        rodar("/bin/ps", ["-axo", "command="]).saida.split(separator: "\n").compactMap { l in
            let s = String(l)
            guard s.contains("--remote-debugging-port="), !s.contains("--type=") else { return nil }
            let app = s.components(separatedBy: ".app/").first.map { Caminho.nome($0) } ?? "Navegador"
            return app
        }
    }
}
