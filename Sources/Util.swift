import AppKit
import Darwin
import Foundation

// MARK: - Caminhos

enum Caminho {
    static let casa = FileManager.default.homeDirectoryForCurrentUser.path

    /// "~/x" → "/Users/fulano/x"
    static func h(_ p: String) -> String {
        p.hasPrefix("~") ? casa + String(p.dropFirst()) : p
    }

    /// "/Users/fulano/x" → "~/x"
    static func curto(_ p: String) -> String {
        p.hasPrefix(casa) ? "~" + String(p.dropFirst(casa.count)) : p
    }

    static func existe(_ p: String) -> Bool { FileManager.default.fileExists(atPath: p) }

    static func ehPasta(_ p: String) -> Bool {
        var d: ObjCBool = false
        return FileManager.default.fileExists(atPath: p, isDirectory: &d) && d.boolValue
    }

    /// Conteúdo de uma pasta (inclusive ocultos), em caminho completo.
    static func filhos(_ p: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: p)) ?? []).sorted().map { p + "/" + $0 }
    }

    static func nome(_ p: String) -> String { (p as NSString).lastPathComponent }
    static func pai(_ p: String) -> String { (p as NSString).deletingLastPathComponent }
}

/// Expande curingas (* ? {a,b}) sem passar por shell.
func expandir(_ padrao: String) -> [String] {
    let p = Caminho.h(padrao)
    guard p.contains("*") || p.contains("{") || p.contains("?") else {
        return Caminho.existe(p) ? [p] : []
    }
    var g = glob_t()
    defer { globfree(&g) }
    guard glob(p, GLOB_BRACE, nil, &g) == 0 else { return [] }
    return (0..<Int(g.gl_pathc)).compactMap { i in g.gl_pathv[i].map { String(cString: $0) } }
}

// MARK: - Segurança: o que nunca pode ser apagado inteiro

enum Seguranca {
    static let proibidos: Set<String> = {
        let c = Caminho.casa
        return Set(["/", c, c + "/Library", c + "/Library/Application Support", c + "/Library/Caches",
                    c + "/Library/Containers", c + "/Library/Group Containers", c + "/Library/Preferences",
                    c + "/Documents", c + "/Desktop", c + "/Pictures", c + "/Movies", c + "/Music",
                    c + "/Downloads", c + "/.cache", c + "/.config", c + "/Applications", "/Applications"])
    }()

    /// Só deixa apagar o conteúdo de pastas dentro da pasta pessoal que não sejam pastas-base.
    static func podeEsvaziar(_ p: String) -> Bool {
        p.hasPrefix(Caminho.casa + "/") && !proibidos.contains(p) && !p.contains("/../")
    }

    static func podeApagarArquivo(_ p: String) -> Bool {
        p.hasPrefix(Caminho.casa + "/") && !proibidos.contains(p) && !p.contains("/../")
    }
}

// MARK: - Formatação

/// GB/MB decimais, igual ao Finder.
func tamanho(_ bytes: Int64) -> String {
    let v = Double(max(bytes, 0))
    let f = NumberFormatter()
    f.locale = Locale(identifier: "pt_BR")
    if v >= 1e9 {
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return (f.string(from: NSNumber(value: v / 1e9)) ?? "") + " GB"
    }
    f.maximumFractionDigits = 0
    if v >= 1e6 { return (f.string(from: NSNumber(value: v / 1e6)) ?? "") + " MB" }
    if v >= 1e3 { return (f.string(from: NSNumber(value: v / 1e3)) ?? "") + " KB" }
    return "\(Int(v)) B"
}

func dataCurta(_ d: Date?) -> String {
    guard let d else { return "—" }
    let f = DateFormatter()
    f.locale = Locale(identifier: "pt_BR")
    f.dateStyle = .short
    return f.string(from: d)
}

// MARK: - Processos

@discardableResult
func rodar(_ exe: String, _ args: [String], timeout: TimeInterval = 120) -> (codigo: Int32, saida: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: exe)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    p.standardInput = FileHandle.nullDevice
    do { try p.run() } catch { return (-1, "") }
    let guarda = DispatchWorkItem { if p.isRunning { p.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: guarda)
    let dados = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    guarda.cancel()
    return (p.terminationStatus, String(decoding: dados, as: UTF8.self))
}

// MARK: - Medição

/// Espaço ocupado por um caminho (pasta ou arquivo), em bytes. Usa o du, que é rápido.
func medir(_ caminho: String) -> Int64 {
    guard Caminho.existe(caminho) else { return 0 }
    let r = rodar("/usr/bin/du", ["-skx", caminho], timeout: 120)
    let kb = r.saida.split(whereSeparator: { $0 == "\t" || $0 == "\n" }).first.flatMap { Int64($0) } ?? 0
    return kb * 1024
}

/// Arquivos dentro de uma pasta que não são mexidos há N dias.
func arquivosVelhos(em pasta: String, dias: Int, extensoes: Set<String>? = nil, profundidade: Int? = nil) -> [(String, Int64)] {
    let limite = Date().addingTimeInterval(-Double(dias) * 86_400)
    let chaves: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .totalFileAllocatedSizeKey]
    guard let en = FileManager.default.enumerator(at: URL(fileURLWithPath: pasta), includingPropertiesForKeys: chaves,
                                                  options: [], errorHandler: { _, _ in true }) else { return [] }
    var r: [(String, Int64)] = []
    while let u = en.nextObject() as? URL {
        if let prof = profundidade, en.level > prof { en.skipDescendants(); continue }
        guard let v = try? u.resourceValues(forKeys: Set(chaves)), v.isRegularFile == true else { continue }
        if let ex = extensoes, !ex.contains(u.pathExtension.lowercased()) { continue }
        guard let m = v.contentModificationDate, m < limite else { continue }
        r.append((u.path, Int64(v.totalFileAllocatedSize ?? 0)))
    }
    return r
}

/// Roda f(0..n-1) em paralelo e devolve na ordem.
final class Resultados<T>: @unchecked Sendable {
    private var v: [T?]
    private let trava = NSLock()
    init(_ n: Int) { v = .init(repeating: nil, count: n) }
    func por(_ i: Int, _ x: T) { trava.lock(); v[i] = x; trava.unlock() }
    var todos: [T] { v.map { $0! } }
}

func emParalelo<T>(_ n: Int, _ f: (Int) -> T) -> [T] {
    guard n > 0 else { return [] }
    let r = Resultados<T>(n)
    DispatchQueue.concurrentPerform(iterations: n) { i in r.por(i, f(i)) }
    return r.todos
}

// MARK: - Histórico (log de tudo que foi apagado)

enum Historico {
    static let arquivo = Caminho.casa + "/Library/Logs/Faxina.log"

    static func anotar(_ s: String) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let linha = "\(f.string(from: Date())) \(s)\n"
        if let h = FileHandle(forWritingAtPath: arquivo) {
            h.seekToEndOfFile()
            h.write(Data(linha.utf8))
            try? h.close()
        } else {
            try? linha.write(toFile: arquivo, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Apps abertos

enum Apps {
    static func nome(doBundle id: String) -> String? {
        guard id.contains("."), let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        return url.deletingPathExtension().lastPathComponent
    }

    /// ids podem terminar em * (prefixo): "com.adobe.Photoshop*"
    static func abertos(ids: [String], nomes: [String]) -> [NSRunningApplication] {
        guard !ids.isEmpty || !nomes.isEmpty else { return [] }
        let ns = Set(nomes.map { $0.lowercased() })
        return NSWorkspace.shared.runningApplications.filter { app in
            if let b = app.bundleIdentifier {
                for id in ids {
                    if id.hasSuffix("*") ? b.hasPrefix(String(id.dropLast())) : b == id { return true }
                }
            }
            if let n = app.localizedName?.lowercased(), ns.contains(n) { return true }
            return false
        }
    }

    /// Nomes (sem repetir) dos apps abertos que travam a limpeza de um item.
    static func nomesAbertos(_ a: Alvo) -> [String] {
        var vistos: [String] = []
        for app in abertos(ids: a.apps, nomes: a.nomesApps) {
            let n = (app.localizedName ?? "app").trimmingCharacters(in: CharacterSet(charactersIn: "\u{200E}\u{200F} "))
            if !vistos.contains(n) { vistos.append(n) }
        }
        return vistos
    }

    /// Fecha como o Cmd+Q: se tiver coisa sem salvar, o app pergunta e pode não fechar.
    static func fechar(_ apps: [NSRunningApplication]) async -> Bool {
        for a in apps { a.terminate() }
        for _ in 0..<40 {
            if apps.allSatisfy({ $0.isTerminated }) { return true }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return apps.allSatisfy { $0.isTerminated }
    }
}

// MARK: - Lixeira do Finder

enum Lixeira {
    /// Manda pra Lixeira pelo Finder (pede senha se precisar). Devolve quantos foram.
    @MainActor
    static func mandar(_ caminhos: [String]) async -> Int {
        let urls = caminhos.map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else { return 0 }
        return await withCheckedContinuation { c in
            NSWorkspace.shared.recycle(urls) { feitos, _ in c.resume(returning: feitos.count) }
        }
    }

    static func esvaziar() -> Bool {
        rodar("/usr/bin/osascript", ["-e", "tell application \"Finder\" to empty trash"], timeout: 300).codigo == 0
    }
}
