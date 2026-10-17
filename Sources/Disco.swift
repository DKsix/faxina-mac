import Darwin
import Foundation

struct InfoDisco {
    var total: Int64 = 0
    /// O que o Finder chama de "disponível agora".
    var livre: Int64 = 0
    /// Livre + o que o macOS consegue soltar sozinho (snapshots, caches do sistema).
    var livreComPurgavel: Int64 = 0
    var swapUsado: Int64 = 0
    var swapTotal: Int64 = 0
    var snapshots: [String] = []

    var usado: Int64 { max(0, total - livre) }
    var purgavel: Int64 { max(0, livreComPurgavel - livre) }
    /// O macOS deixou uma atualização preparada, que segura espaço até ser instalada.
    var atualizacaoPreparada: Bool { snapshots.contains { $0.contains("MSUPrepareUpdate") } }
}

func lerDisco() -> InfoDisco {
    var i = InfoDisco()
    let chaves: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey,
                                       .volumeAvailableCapacityForImportantUsageKey]
    if let v = try? URL(fileURLWithPath: Caminho.casa).resourceValues(forKeys: chaves) {
        i.total = Int64(v.volumeTotalCapacity ?? 0)
        i.livre = Int64(v.volumeAvailableCapacity ?? 0)
        i.livreComPurgavel = v.volumeAvailableCapacityForImportantUsage ?? i.livre
    }
    var sw = xsw_usage()
    var n = MemoryLayout<xsw_usage>.size
    if sysctlbyname("vm.swapusage", &sw, &n, nil, 0) == 0 {
        i.swapUsado = Int64(sw.xsu_used)
        i.swapTotal = Int64(sw.xsu_total)
    }
    let s = rodar("/usr/bin/tmutil", ["listlocalsnapshots", "/"], timeout: 20).saida
    i.snapshots = s.split(separator: "\n").map { String($0) }.filter { $0.hasPrefix("com.apple") }
    return i
}
