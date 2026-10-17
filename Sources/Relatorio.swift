import Foundation

/// `Faxina.app/Contents/MacOS/Faxina --relatorio` — mostra no Terminal o que dá pra limpar.
/// Só mede: não apaga nada.
enum Relatorio {
    static func imprimir() {
        let d = lerDisco()
        print("Faxina — relatório (nada foi apagado)\n")
        print("Livre: \(tamanho(d.livre)) de \(tamanho(d.total))")
        print("O macOS libera sozinho: \(tamanho(d.purgavel))")
        print("Swap: \(tamanho(d.swapUsado)) de \(tamanho(d.swapTotal))")
        if d.atualizacaoPreparada { print("Atualização do macOS preparada (segura espaço até instalar)") }
        print("")

        let alvos = Catalogo.montar()
        let bytes = emParalelo(alvos.count) { Medidor.bytes(de: alvos[$0]) }
        var porGrupo: [Grupo: [(Alvo, Int64)]] = [:]
        for (a, b) in zip(alvos, bytes) where b >= 5_000_000 { porGrupo[a.grupo, default: []].append((a, b)) }
        var seguro: Int64 = 0, revisar: Int64 = 0
        for g in Grupo.allCases {
            guard let itens = porGrupo[g]?.sorted(by: { $0.1 > $1.1 }) else { continue }
            print("■ \(g.rawValue)")
            for (a, b) in itens {
                let abertos = Apps.nomesAbertos(a)
                let marca = a.nivel == .seguro ? "seguro " : "revise "
                let trava = abertos.isEmpty ? "" : "  [feche: \(abertos.joined(separator: ", "))]"
                print("  \(tamanho(b).padding(toLength: 9, withPad: " ", startingAt: 0)) \(marca) \(a.nome)\(trava)")
                if a.nivel == .seguro { seguro += b } else { revisar += b }
            }
        }
        print("\nSeguro: \(tamanho(seguro)) · Pra revisar: \(tamanho(revisar)) · \(alvos.count) itens no catálogo")
    }
}
