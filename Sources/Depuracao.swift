import AppKit

/// Modo de teste: `Faxina --fotos <pasta>` faz o app fotografar as próprias janelas quando recebe
/// o aviso "com.eduardomoraes.faxina.foto" (enviado por Ferramentas/foto.swift). Não precisa da
/// permissão de gravação de tela, porque o app só desenha a si mesmo. Sem o argumento, não faz nada.
enum Depuracao {
    static var pasta: String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "--fotos"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    static func iniciar() {
        guard let p = pasta else { return }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.eduardomoraes.faxina.foto"), object: nil, queue: .main
        ) { n in
            let nome = (n.object as? String) ?? "foto"
            var i = 0
            for w in NSApp.windows where w.isVisible && w.frame.width > 120 {
                salvar(w, "\(p)/\(nome)-\(i).png")
                i += 1
            }
        }
    }

    static func salvar(_ w: NSWindow, _ arquivo: String) {
        guard let v = w.contentView?.superview ?? w.contentView,
              let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return }
        v.cacheDisplay(in: v.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: arquivo))
    }
}
