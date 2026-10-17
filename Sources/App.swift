import AppKit
import SwiftUI

final class Delegado: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Aviso.pedirPermissao()
        Depuracao.iniciar()
        Task { @MainActor in
            Vigia.compartilhada.iniciar()
            await Estado.compartilhado.analisar()
        }
    }

    // fechar a janela não fecha o app: ele continua na barra de menus
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct FaxinaApp: App {
    @NSApplicationDelegateAdaptor(Delegado.self) var delegado
    @StateObject private var estado = Estado.compartilhado

    init() {
        if CommandLine.arguments.contains("--relatorio") {
            Relatorio.imprimir()
            exit(0)
        }
    }

    var body: some Scene {
        Window("Faxina", id: "principal") {
            JanelaPrincipal().environmentObject(estado)
        }
        .defaultSize(width: 1000, height: 680)

        MenuBarExtra {
            MenuView().environmentObject(estado)
        } label: {
            RotuloMenu(e: estado)
        }
        .menuBarExtraStyle(.window)
    }
}

struct RotuloMenu: View {
    @ObservedObject var e: Estado

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: e.abaixoDaMeta ? "exclamationmark.triangle.fill" : "sparkles")
            Text("\(Int((Double(e.disco.livre) / 1e9).rounded())) GB")
        }
    }
}

struct MenuView: View {
    @EnvironmentObject var e: Estado
    @Environment(\.openWindow) private var abrirJanela
    @State private var confirmando = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                AnelEspaco(disco: e.disco, metaBytes: e.metaBytes, espessura: 7, mostrarTexto: false)
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Espaço livre").font(.caption).foregroundStyle(.secondary)
                    Text(tamanho(e.disco.livre)).font(.title2.weight(.bold)).monospacedDigit()
                    Text(e.abaixoDaMeta ? "faltam \(tamanho(e.metaBytes - e.disco.livre)) pra meta" : "dentro da meta de \(e.metaGB) GB")
                        .font(.caption).foregroundStyle(e.abaixoDaMeta ? Color.red : Color.secondary)
                }
            }
            Divider()
            if e.analisando && e.analisadoEm == nil {
                HStack { ProgressView().controlSize(.small); Text("Procurando o que dá pra limpar…").font(.callout) }
            } else {
                HStack {
                    Label("Lixo seguro", systemImage: "sparkles").foregroundStyle(.green)
                    Spacer()
                    Text(tamanho(e.totalSeguroLivre)).monospacedDigit()
                    Button(confirmando ? "Confirmar" : "Limpar") {
                        if confirmando { confirmando = false; Task { await e.limparSeguro() } } else { confirmando = true }
                    }
                    .buttonStyle(.borderedProminent).tint(confirmando ? .orange : .green).controlSize(.small)
                    .disabled(e.totalSeguroLivre == 0 || e.limpando)
                }
                if confirmando {
                    Text("Apaga só cache e temporários. Tudo se refaz sozinho.").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Label("Pra revisar", systemImage: "eye").foregroundStyle(.orange)
                    Spacer()
                    Text(tamanho(e.totalRevisar)).monospacedDigit()
                }
                .font(.callout)
            }
            if e.limpando { HStack { ProgressView().controlSize(.small); Text("Limpando…") } }
            if let r = e.resultado { Text(r).font(.caption).foregroundStyle(.green) }
            Divider()
            HStack {
                Button("Abrir Faxina") {
                    NSApp.keyWindow?.close()   // fecha o menu da barra
                    abrirJanela(id: "principal")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button { Task { await e.analisar() } } label: { Image(systemName: "arrow.clockwise") }
                    .help("Medir de novo")
                Spacer()
                Button("Sair") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 300)
        .onAppear {
            confirmando = false
            Task { await e.atualizarDisco() }
        }
    }
}
