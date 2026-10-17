import AppKit
import Foundation

// O catálogo do que dá pra limpar. A ideia de separar "seguro" de "revise" e a lista de
// caches de Electron vêm do Disco Livre (MIT, Willian Carlos Lameu); o resto foi montado em cima
// do que existe neste Mac.

enum Nivel { case seguro, revisar }

enum Modo {
    case conteudo                 // apaga o que tem dentro (a pasta fica)
    case antigos(dias: Int)       // só arquivos sem mexer há N dias
    case instaladores(dias: Int)  // .dmg/.pkg/.iso/.xip soltos — vão pra Lixeira
    case lixeira                  // esvazia a Lixeira do Finder
}

enum Grupo: String, CaseIterable {
    case fotografia = "Fotografia e vídeo"
    case mensagens = "Mensagens"
    case ia = "IA"
    case navegadores = "Navegadores"
    case apps = "Apps"
    case programacao = "Programação"
    case sistema = "Sistema"
    case arquivos = "Seus arquivos"

    var icone: String {
        switch self {
        case .fotografia: "camera.aperture"
        case .mensagens: "message"
        case .ia: "cpu"
        case .navegadores: "globe"
        case .apps: "square.stack.3d.up"
        case .programacao: "chevron.left.forwardslash.chevron.right"
        case .sistema: "gearshape"
        case .arquivos: "folder"
        }
    }
}

struct Alvo: Identifiable {
    let id: String
    let grupo: Grupo
    let nome: String
    let nota: String
    let nivel: Nivel
    let caminhos: [String]
    let modo: Modo
    /// Bundle ids (aceita * no fim) dos apps que precisam estar fechados.
    let apps: [String]
    /// Nomes dos apps, pra quando não se sabe o bundle id.
    let nomesApps: [String]
}

enum ID {
    static let adobe = ["com.adobe.LightroomClassic*", "com.adobe.Photoshop*", "com.adobe.bridge*", "com.adobe.Lightroom*"]
    static let evoto = "com.cclian.Evoto"
    static let whatsapp = "net.whatsapp.WhatsApp"
    static let telegram = "ru.keepcoder.Telegram"
    static let claude = "com.anthropic.claudefordesktop"
    static let arc = "company.thebrowser.Browser"
    static let chrome = "com.google.Chrome"
    static let safari = "com.apple.Safari"
    static let firefox = "org.mozilla.firefox"
    static let edge = "com.microsoft.edgemac"
    static let brave = "com.brave.Browser"
    static let resolve = "com.blackmagic-design.DaVinciResolve*"
    static let xcode = "com.apple.dt.Xcode"
    static let vscode = "com.microsoft.VSCode"
}

enum Catalogo {
    /// Pastas de cache que apps Electron/Chromium criam dentro de Application Support.
    static let cachesElectron = ["Cache", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache",
                                 "GrShaderCache", "ShaderCache", "Service Worker/CacheStorage", "Service Worker/ScriptCache"]

    /// Nome bonito e bundle id de pastas conhecidas de Application Support.
    static let pastasConhecidas: [String: (String, [String])] = [
        "Code": ("VS Code", [ID.vscode]),
        "discord": ("Discord", ["com.hnc.Discord"]),
        "Notion": ("Notion", ["notion.id"]),
        "Notion Calendar": ("Notion Calendar", ["com.cron.electron"]),
        "Claude": ("Claude", [ID.claude]),
        "Slack": ("Slack", ["com.tinyspeck.slackmacgap"]),
        "obsidian": ("Obsidian", ["md.obsidian"]),
        "Todoist": ("Todoist", ["com.todoist.mac.Todoist"]),
        "Steam": ("Steam", ["com.valvesoftware.steam"]),
        "Spotify": ("Spotify", ["com.spotify.client"]),
        "Figma": ("Figma", ["com.figma.Desktop"]),
        "Codex": ("Codex", ["com.openai.codex"]),
        "CapCut": ("CapCut", ["com.lemon.lvoverseas"]),
    ]

    static func montar() -> [Alvo] {
        var lista: [Alvo] = []
        var cobertos: [String] = []
        let L = "~/Library", AS = "~/Library/Application Support", CA = "~/Library/Caches"

        // um caminho só entra uma vez no catálogo (nada de contar duas vezes)
        func livre(_ c: String) -> Bool {
            !cobertos.contains { c == $0 || c.hasPrefix($0 + "/") || $0.hasPrefix(c + "/") }
        }

        func add(_ g: Grupo, _ nome: String, _ nivel: Nivel, _ padroes: [String], modo: Modo = .conteudo,
                 apps: [String] = [], nomes: [String] = [], nota: String = "") {
            var cams: [String] = []
            for p in padroes {
                for c in expandir(p) where livre(c) && !cams.contains(c) { cams.append(c) }
            }
            guard !cams.isEmpty else { return }
            cobertos += cams
            lista.append(Alvo(id: "\(g.rawValue)|\(nome)|\(cams[0])", grupo: g, nome: nome, nota: nota, nivel: nivel,
                              caminhos: cams, modo: modo, apps: apps, nomesApps: nomes))
        }

        // ── Fotografia e vídeo ─────────────────────────────────────────
        add(.fotografia, "Cache do Camera Raw (Lightroom e Photoshop)", .seguro,
            ["\(CA)/Adobe Camera Raw 2", "\(CA)/Adobe Camera Raw BigTableGroupCache"], apps: ID.adobe,
            nota: "Prévias que o Camera Raw guarda pra abrir as fotos mais rápido. Ele refaz sozinho.")
        add(.fotografia, "Arquivos temporários da Adobe", .seguro, ["\(CA)/Adobe"], apps: ID.adobe,
            nota: "Cache dos apps da Adobe.")
        add(.fotografia, "Cache do Evoto", .seguro, ["\(AS)/Evoto_pro/cache"], apps: [ID.evoto], nomes: ["Evoto"],
            nota: "Prévias e arquivos temporários das edições. O Evoto refaz sozinho.")
        add(.fotografia, "Atualização do Evoto já baixada", .seguro, ["\(AS)/Evoto_pro/updateDownload"],
            apps: [ID.evoto], nomes: ["Evoto"], nota: "Instalador de versão nova. Baixa de novo se precisar.")
        add(.fotografia, "Cache de render do DaVinci Resolve", .seguro,
            ["~/Movies/CacheClip", "\(CA)/com.blackmagic-design.DaVinciResolve"], apps: [ID.resolve],
            nomes: ["DaVinci Resolve"], nota: "Render cache. O Resolve gera de novo quando precisar.")
        add(.fotografia, "Modelos de IA compilados (coreMLCache)", .revisar, ["\(AS)/coreMLCache"],
            apps: [ID.evoto], nomes: ["Evoto"],
            nota: "Modelos de IA de apps de edição (Evoto e parecidos). O app recompila ou baixa de novo — a primeira edição depois fica mais lenta.")

        // ── Mensagens ──────────────────────────────────────────────────
        add(.mensagens, "Mídia do WhatsApp", .revisar,
            ["\(L)/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media"],
            apps: [ID.whatsapp], nomes: ["WhatsApp"],
            nota: "Fotos, vídeos, áudios e documentos recebidos. As conversas ficam; a mídia sai deste Mac e continua no celular.")
        add(.mensagens, "Mídia do Telegram", .revisar,
            ["\(L)/Group Containers/*.ru.keepcoder.Telegram/*/*/postbox/media"], apps: [ID.telegram], nomes: ["Telegram"],
            nota: "Arquivos baixados das conversas. O Telegram baixa de novo da nuvem quando você abrir.")

        // ── IA ─────────────────────────────────────────────────────────
        add(.ia, "Máquina virtual do Claude (Cowork)", .revisar, ["\(AS)/Claude/vm_bundles"],
            apps: [ID.claude], nomes: ["Claude"],
            nota: "Usada só pelo modo Cowork do app Claude. Ele baixa de novo (uns 10 GB) se você usar o Cowork.")
        add(.ia, "Modelos do Hugging Face (Llama, Whisper…)", .revisar, ["~/.cache/huggingface/hub"],
            nota: "Modelos de IA que rodam no Mac. O programa que usa baixa de novo.")
        add(.ia, "Cache do Hugging Face", .seguro, ["~/.cache/huggingface/xet"])
        add(.ia, "Modelos do Whisper (transcrição)", .revisar, ["~/.cache/whisper-cpp", "~/.cache/whisper"],
            nota: "Modelos de transcrição de áudio. Baixam de novo quando você transcrever.")
        add(.ia, "Modelos do PyTorch", .revisar, ["~/.cache/torch"], nota: "Pesos de modelos baixados por scripts de IA.")
        add(.ia, "Modelos do Ollama", .revisar, ["~/.ollama/models"], nomes: ["Ollama"])
        add(.ia, "Modelos do LM Studio", .revisar, ["~/.lmstudio/models", "~/.cache/lm-studio/models"], nomes: ["LM Studio"])
        add(.ia, "Navegadores do Playwright", .revisar, ["\(CA)/ms-playwright"],
            nota: "Navegadores usados por automações. Baixam de novo quando uma automação rodar.")

        // ── Navegadores ────────────────────────────────────────────────
        let perfil = "{Service Worker/CacheStorage,Service Worker/ScriptCache,GPUCache,Code Cache}"
        add(.navegadores, "Cache do Arc", .seguro,
            ["\(CA)/Arc", "\(CA)/company.thebrowser.Browser", "\(AS)/Arc/User Data/*/\(perfil)"],
            apps: [ID.arc], nomes: ["Arc"], nota: "Páginas e imagens guardadas. Logins e abas ficam.")
        add(.navegadores, "Cache do Chrome", .seguro,
            ["\(CA)/Google/Chrome", "\(AS)/Google/Chrome/*/\(perfil)"], apps: [ID.chrome],
            nota: "Páginas e imagens guardadas. Perfis, logins e favoritos ficam.")
        add(.navegadores, "Cache do Safari", .seguro, ["\(CA)/com.apple.Safari"], apps: [ID.safari])
        add(.navegadores, "Cache do Firefox", .seguro, ["\(CA)/Firefox"], apps: [ID.firefox])
        add(.navegadores, "Cache do Edge", .seguro, ["\(CA)/Microsoft Edge", "\(AS)/Microsoft Edge/*/\(perfil)"],
            apps: [ID.edge])
        add(.navegadores, "Cache do Brave", .seguro,
            ["\(CA)/BraveSoftware", "\(AS)/BraveSoftware/Brave-Browser/*/\(perfil)"], apps: [ID.brave])

        // ── Programação ────────────────────────────────────────────────
        add(.programacao, "Cache do npm", .seguro, ["~/.npm/_cacache"], nota: "Pacotes baixados. O npm baixa de novo.")
        add(.programacao, "Cache do pip", .seguro, ["\(CA)/pip"])
        add(.programacao, "Cache do uv (Python)", .seguro, ["~/.cache/uv"])
        add(.programacao, "Cache do pnpm", .seguro, ["\(CA)/pnpm"])
        add(.programacao, "Cache do Yarn", .seguro, ["\(CA)/Yarn"])
        add(.programacao, "Cache do Homebrew", .seguro, ["\(CA)/Homebrew"])
        add(.programacao, "Cache do Go", .seguro, ["\(CA)/go-build"])
        add(.programacao, "Cache do CocoaPods", .seguro, ["\(CA)/CocoaPods"])
        add(.programacao, "Xcode DerivedData", .seguro, ["\(L)/Developer/Xcode/DerivedData"], apps: [ID.xcode])
        add(.programacao, "Extensões do VS Code já instaladas", .seguro,
            ["\(AS)/Code/CachedExtensionVSIXs", "\(AS)/Code/CachedData"], apps: [ID.vscode],
            nota: "Cópia dos instaladores das extensões. As extensões continuam.")

        // ── Sistema ────────────────────────────────────────────────────
        let crash = "Crashpad/{pending,completed,new}"
        add(.sistema, "Relatórios de erro de apps", .seguro,
            ["\(AS)/*/\(crash)", "\(AS)/*/*/\(crash)", "\(CA)/*/\(crash)", "\(L)/Logs/DiagnosticReports"],
            nota: "Relatórios gerados quando um app trava. Ninguém usa depois.")
        add(.sistema, "Atualizações de apps já instaladas", .seguro,
            ["\(CA)/*ShipIt", "\(CA)/*/org.sparkle-project.Sparkle", "\(AS)/Google/GoogleUpdater/crx_cache",
             "\(CA)/*-updater", "\(CA)/*.updater"],
            nota: "Instaladores de atualizações que já foram aplicadas.")
        add(.sistema, "Logs com mais de 7 dias", .seguro, ["\(L)/Logs"], modo: .antigos(dias: 7))
        add(.sistema, "Lixeira", .revisar, ["~/.Trash"], modo: .lixeira,
            nota: "Apaga de vez o que está na Lixeira. Precisa da permissão pra controlar o Finder.")

        // ── Seus arquivos ──────────────────────────────────────────────
        add(.arquivos, "Instaladores esquecidos (.dmg, .pkg)", .revisar, ["~/Downloads", "~/Desktop"],
            modo: .instaladores(dias: 14), nota: "Instaladores com mais de 14 dias. Vão pra Lixeira (dá pra recuperar).")

        // ── Apps: caches internos (Electron/Chromium) ──────────────────
        let pular: Set<String> = ["Google", "Arc", "Evoto_pro", "coreMLCache", "Microsoft Edge", "BraveSoftware"]
        for pasta in Caminho.filhos(Caminho.h(AS)) where Caminho.ehPasta(pasta) {
            let nome = Caminho.nome(pasta)
            if nome.hasPrefix("com.apple") || pular.contains(nome) { continue }
            var pads = cachesElectron.map { "\(pasta)/\($0)" }
            pads += cachesElectron.map { "\(pasta)/Partitions/*/\($0)" }
            pads.append("\(pasta)/WebStorage/*/CacheStorage")
            let (mostrado, ids) = pastasConhecidas[nome] ?? (Apps.nome(doBundle: nome) ?? nome, [nome])
            add(.apps, "Cache interno do \(mostrado)", .seguro, pads, apps: ids, nomes: [nome, mostrado],
                nota: "Páginas, imagens e código que o app guarda. Ele refaz sozinho.")
        }

        // ── Apps: ~/Library/Caches (o "lixo de usuário" do CleanMyMac) ─
        let pularCaches: Set<String> = ["CloudKit", "GeoServices", "FamilyCircle", "PassKit", "Faxina"]
        for pasta in Caminho.filhos(Caminho.h(CA)) where Caminho.ehPasta(pasta) {
            let nome = Caminho.nome(pasta)
            if nome.hasPrefix("com.apple.") || pularCaches.contains(nome) { continue }
            let mostrado = Apps.nome(doBundle: nome) ?? nome
            add(.apps, "Cache: \(mostrado)", .seguro, [pasta], apps: [nome], nomes: [mostrado, nome],
                nota: "Arquivos temporários. O app refaz sozinho.")
        }

        return lista
    }
}

// MARK: - Medir e limpar

enum Medidor {
    static let extInstaladores: Set<String> = ["dmg", "pkg", "iso", "xip"]

    static func bytes(de a: Alvo) -> Int64 {
        switch a.modo {
        case .conteudo, .lixeira:
            return a.caminhos.reduce(0) { $0 + medir($1) }
        case .antigos(let d):
            return a.caminhos.reduce(0) { s, c in s + arquivosVelhos(em: c, dias: d).reduce(0) { $0 + $1.1 } }
        case .instaladores(let d):
            return a.caminhos.reduce(0) { s, c in
                s + arquivosVelhos(em: c, dias: d, extensoes: extInstaladores, profundidade: 1).reduce(0) { $0 + $1.1 }
            }
        }
    }
}

enum Faxineiro {
    /// Apaga um item do catálogo. Os instaladores vão pra Lixeira; o resto sai de vez.
    static func limpar(_ a: Alvo) {
        let fm = FileManager.default
        switch a.modo {
        case .conteudo:
            for c in a.caminhos where Seguranca.podeEsvaziar(c) {
                if Caminho.ehPasta(c) {
                    for f in Caminho.filhos(c) { try? fm.removeItem(atPath: f) }
                } else {
                    try? fm.removeItem(atPath: c)
                }
            }
        case .antigos(let d):
            for c in a.caminhos {
                for (f, _) in arquivosVelhos(em: c, dias: d) where Seguranca.podeApagarArquivo(f) {
                    try? fm.removeItem(atPath: f)
                }
            }
        case .instaladores(let d):
            for c in a.caminhos {
                for (f, _) in arquivosVelhos(em: c, dias: d, extensoes: Medidor.extInstaladores, profundidade: 1) {
                    try? fm.trashItem(at: URL(fileURLWithPath: f), resultingItemURL: nil)
                }
            }
        case .lixeira:
            _ = Lixeira.esvaziar()
        }
        Historico.anotar("limpou: \(a.nome) — \(a.caminhos.map(Caminho.curto).joined(separator: ", "))")
    }
}
