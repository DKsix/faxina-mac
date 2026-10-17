# O que a Faxina limpa

**Seguro** = se refaz sozinho; vem marcado.
**Revise** = é seu ou demora pra voltar; só sai se você marcar.
**App** = precisa estar fechado pra limpar.

A lista completa está em [`Sources/Catalogo.swift`](../Sources/Catalogo.swift). Itens que não
existem no seu Mac simplesmente não aparecem; itens com menos de 5 MB ficam escondidos.

## Fotografia e vídeo

| Item | Nível | Onde | App | O que acontece ao limpar |
|---|---|---|---|---|
| Cache do Camera Raw | seguro | `~/Library/Caches/Adobe Camera Raw 2` | Lightroom, Photoshop, Bridge | As prévias são refeitas ao abrir as fotos |
| Arquivos temporários da Adobe | seguro | `~/Library/Caches/Adobe` | Lightroom, Photoshop | Refeitos pelos apps |
| Cache do Evoto | seguro | `~/Library/Application Support/Evoto_pro/cache` | Evoto | Refeito ao editar |
| Atualização do Evoto já baixada | seguro | `…/Evoto_pro/updateDownload` | Evoto | Baixa de novo se precisar |
| Cache de render do DaVinci Resolve | seguro | `~/Movies/CacheClip` | DaVinci Resolve | O Resolve renderiza de novo |
| Modelos de IA compilados (coreMLCache) | revise | `~/Library/Application Support/coreMLCache` | Evoto | O app recompila/baixa; a primeira edição fica lenta |

## Mensagens

| Item | Nível | Onde | O que acontece ao limpar |
|---|---|---|---|
| Mídia do WhatsApp | revise | `~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media` | Fotos, vídeos, áudios e documentos somem do Mac. As conversas ficam. A mídia continua no celular |
| Mídia do Telegram | revise | `…/ru.keepcoder.Telegram/…/postbox/media` | O Telegram baixa de novo da nuvem quando você abrir |

## IA

| Item | Nível | Onde | O que acontece ao limpar |
|---|---|---|---|
| Máquina virtual do Claude (Cowork) | revise | `~/Library/Application Support/Claude/vm_bundles` | O app Claude baixa de novo (~10 GB) se você usar o Cowork |
| Modelos do Hugging Face | revise | `~/.cache/huggingface/hub` | Programas que usam baixam de novo |
| Modelos do Whisper | revise | `~/.cache/whisper-cpp` | Baixam de novo na próxima transcrição |
| Modelos do PyTorch | revise | `~/.cache/torch` | Baixam de novo |
| Modelos do Ollama / LM Studio | revise | `~/.ollama/models`, `~/.lmstudio/models` | Precisa baixar o modelo de novo no app |
| Navegadores do Playwright | revise | `~/Library/Caches/ms-playwright` | Automações baixam de novo |
| Cache do Hugging Face (Xet) | seguro | `~/.cache/huggingface/xet` | Refeito |

## Navegadores (seguro)

Arc, Chrome, Safari, Firefox, Edge, Brave. Limpa **só o cache** (páginas e imagens guardadas,
Service Worker, GPU). Perfis, logins, favoritos, histórico e abas **ficam**. O navegador precisa
estar fechado.

## Apps (seguro)

- **Cache interno de apps Electron/Chromium** (Notion, VS Code, Discord, Claude, Slack, Spotify,
  Obsidian, Todoist…): pastas `Cache`, `Code Cache`, `GPUCache`, `Service Worker/CacheStorage` e
  parecidas dentro de `~/Library/Application Support/<App>`. No Notion isso costuma passar de 3 GB.
- **Cache de cada app em `~/Library/Caches`**: um item por app (é o "lixo de usuário" do CleanMyMac).
  Caches da Apple (`com.apple.*`) ficam de fora.

## Programação (seguro)

npm (`~/.npm/_cacache`), pip, uv (`~/.cache/uv`), pnpm, Yarn, Homebrew, Go, CocoaPods,
Xcode DerivedData, instaladores de extensões do VS Code.

## Sistema

| Item | Nível | O que é |
|---|---|---|
| Relatórios de erro de apps | seguro | Pastas `Crashpad` e `DiagnosticReports`. Um app travando em loop pode gerar dezenas de GB em dias |
| Atualizações de apps já instaladas | seguro | `*ShipIt`, Sparkle, Google Updater: instaladores de versões já aplicadas |
| Logs com mais de 7 dias | seguro | Só os arquivos velhos de `~/Library/Logs` |
| Lixeira | revise | Esvazia de vez (pede permissão pra controlar o Finder) |

## Seus arquivos

| Item | Nível | O que é |
|---|---|---|
| Instaladores esquecidos | revise | `.dmg`, `.pkg`, `.iso`, `.xip` com mais de 14 dias em Downloads e na Mesa. **Vão pra Lixeira** |

---

## O que a Faxina **nunca** apaga

- Nada fora da sua pasta pessoal (`/Users/você`).
- O conteúdo inteiro de Documentos, Mesa, Imagens, Filmes, Música, Downloads, Biblioteca.
- Perfis de navegador, conversas, catálogos do Lightroom, bancos de dados de apps.
- Nada de um app que esteja aberto.
