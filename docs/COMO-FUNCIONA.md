# Como a Faxina funciona

App nativo em **Swift/SwiftUI**, sem dependências, compilado com `swiftc` (não precisa do Xcode).
Roda como app normal (janela + Dock) e com um item na barra de menus (`MenuBarExtra`).

## Visão geral do código

```
Sources/
├── App.swift              entrada do app, janela, barra de menus
├── Estado.swift           estado central (disco, itens, marcados), limpeza, avisos, vigia
├── Catalogo.swift         catálogo do que dá pra limpar + medir + apagar
├── Disco.swift            espaço livre, purgável, swap, snapshots
├── Ferramentas.swift      arquivos grandes, mapa, desinstalador, tarefas de fundo
├── TelasPrincipais.swift  componentes, menu lateral, Visão geral, Limpeza
├── TelasFerramentas.swift Arquivos grandes, Mapa, Desinstalar, Segundo plano, Ajustes
├── Relatorio.swift        modo --relatorio (Terminal, só mede)
├── Depuracao.swift        modo --fotos (testes visuais)
└── Util.swift             caminhos, glob, du, processos, segurança, histórico
```

## O catálogo

Cada item de limpeza é um `Alvo`:

| Campo | Pra quê |
|---|---|
| `grupo` | Fotografia e vídeo, Mensagens, IA, Navegadores, Apps, Programação, Sistema, Seus arquivos |
| `nivel` | `.seguro` (vem marcado) ou `.revisar` (só sai se a pessoa marcar) |
| `caminhos` | pastas reais, depois de expandir curingas (`*`, `{a,b}`) |
| `modo` | `.conteudo` (esvazia a pasta), `.antigos(dias)` (só arquivos velhos), `.instaladores(dias)` (vão pra Lixeira), `.lixeira` |
| `apps` / `nomesApps` | apps que precisam estar fechados (bundle id, aceita `*` no fim) |
| `nota` | o texto que explica o que acontece ao limpar |

O catálogo é montado na hora, olhando o que existe no Mac. Um mesmo caminho nunca entra em dois
itens (pra não contar duas vezes nem apagar cache de app aberto por outro item).

Itens gerados automaticamente:
- **Cache interno de cada app** em `~/Library/Application Support/*` que tenha pastas de cache de
  Electron/Chromium.
- **Cache de cada app** em `~/Library/Caches/*` (fora os da Apple).

## Medir

`du -skx` em paralelo (`DispatchQueue.concurrentPerform`). Um Mac comum mede ~60 itens em 2–3 s.
O `du` conta clones do APFS inteiros, por isso a medida pode ser maior que o ganho real
(ver [PERGUNTAS.md](PERGUNTAS.md)).

## Apagar — as travas

1. **Confirmação** antes de qualquer limpeza, avisando os itens "revise".
2. **App aberto bloqueia** o item (checado de novo na hora de apagar).
3. `Seguranca.podeEsvaziar`: só caminhos **dentro da pasta pessoal** e **nunca** uma pasta-base
   (casa, Biblioteca, Caches, Application Support, Containers, Documentos, Mesa, Downloads…).
4. Modo `.conteudo` apaga **o que tem dentro**; a pasta fica (apps esperam que ela exista).
5. Arquivos da pessoa (instaladores, arquivos grandes, apps, sobras) vão pra **Lixeira** via
   `NSWorkspace.recycle` — recuperáveis.
6. Arquivos grandes **protegidos** (catálogo do Lightroom, `.sqlite`/`.db`, dentro de `.app`,
   `Containers`, `Group Containers`, `.photoslibrary`) não podem ser selecionados.
7. **Histórico** em `~/Library/Logs/Faxina.log`.

## Vigia

Com o app aberto, a cada 30 minutos (`Vigia` em `Estado.swift`):

1. **Loop de erro**: pasta `Crashpad` com mais de 500 arquivos → apaga os relatórios e avisa
   (um app travando em loop já encheu 16 GB em 3 dias).
2. **Queda rápida**: perdeu mais de 10 GB em 24 h → avisa (histórico de 14 dias em `UserDefaults`).
3. **Abaixo da meta**: avisa (no máximo a cada 6 h). Se "limpar sozinho" estiver ligado, limpa o
   seguro antes.

Avisos via `UserNotifications`. Não há LaunchAgent: a vigia vive dentro do app (ligue "Abrir quando
o Mac ligar", que usa `SMAppService`).

## Desinstalador

Pra cada app em `/Applications` (fora os da Apple), procura dados pelo **bundle id** e pelo
**nome** em `Application Support`, `Caches`, `Containers`, `Group Containers`, `Preferences`,
`Saved Application State`, `HTTPStorages`, `WebKit`, `Logs`, `LaunchAgents`, `Application Scripts`.

**Sobras órfãs**: pastas com nome de bundle id cujo app não existe mais. Pra não marcar peça de app
instalado como sobra, ignora: ids que são prefixo/extensão de app instalado, mesmo fabricante de
app instalado (`com.adobe.*`), e fabricantes com plugin instalado (OFX, Lightroom, Photoshop, áudio).

## Configurações

`UserDefaults` do domínio `com.eduardomoraes.faxina`: `metaGB`, `vigiaLigada`, `limparSozinho`,
`historicoLivre`, `aviso.*` (controle de repetição dos avisos).
