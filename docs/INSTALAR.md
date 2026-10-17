# Instalar a Faxina — passo a passo

Tem dois jeitos. O **jeito 1** (compilar) é o mais seguro: você monta o app no seu próprio Mac a
partir do código, e o macOS abre sem reclamar. O **jeito 2** (baixar pronto) não precisa de
Terminal, mas o macOS vai pedir uma liberação na primeira vez.

Requisitos: **macOS 13 (Ventura) ou mais novo**, Mac com chip Apple (M1, M2…) ou Intel.

---

## Jeito 1: compilar no seu Mac (recomendado)

### Passo 1 — Abrir o Terminal

Aperte **Cmd + Espaço**, digite **Terminal** e aperte Enter.

### Passo 2 — Instalar as ferramentas da Apple (só na primeira vez)

Cole no Terminal e aperte Enter:

```bash
xcode-select --install
```

Vai abrir uma janela perguntando se quer instalar as **Ferramentas de Linha de Comando**.
Clique em **Instalar** e espere terminar (uns 5 a 15 minutos).

> Se aparecer `command line tools are already installed`, ótimo: já estão instaladas. Pule pro passo 3.

### Passo 3 — Baixar a Faxina

```bash
cd ~/Downloads
git clone https://github.com/DKsix/faxina-mac.git
cd faxina-mac
```

> Sem git? Na página do repositório, clique em **Code → Download ZIP**, abra o zip e, no Terminal,
> entre na pasta com `cd ~/Downloads/faxina-mac-main`.

### Passo 4 — Compilar e instalar

```bash
./build.sh instalar
```

Leva uns 30 segundos. No fim aparece:

```
✓ build/Faxina.app
✓ instalada em /Applications/Faxina.app
```

### Passo 5 — Abrir

```bash
open /Applications/Faxina.app
```

Ou abra pela pasta **Aplicativos**. Pronto:

- abre a janela da Faxina, já medindo o que dá pra limpar (uns segundos);
- aparece o ícone **✨ 44 GB** na barra de menus, lá em cima à direita.

Depois de instalada, pode apagar a pasta `faxina-mac` dos Downloads se quiser (guarde se for
atualizar depois — veja abaixo).

---

## Jeito 2: baixar o app pronto

1. Vá em [Releases](https://github.com/DKsix/faxina-mac/releases/latest) e baixe **Faxina.zip**.
2. Abra o zip e arraste **Faxina.app** pra pasta **Aplicativos**.
3. Abra a Faxina. Na primeira vez o macOS mostra **"Faxina" não pode ser aberto** (porque o app
   não é assinado com um certificado pago da Apple). Pra liberar:
   - **macOS 15 (Sequoia) ou mais novo:** Ajustes do Sistema → **Privacidade e Segurança** → role até
     o fim → **Abrir Mesmo Assim** → digite sua senha.
   - **macOS 13 e 14:** clique com o **botão direito** no app → **Abrir** → **Abrir**.
4. Isso só acontece na primeira vez.

> Conferir o arquivo (opcional): a release traz o `Faxina.zip.sha256`. No Terminal:
> `shasum -a 256 ~/Downloads/Faxina.zip` — o número tem que ser igual ao do arquivo.

---

## Permissões que podem aparecer

| Quando | O que aparece | O que fazer |
|---|---|---|
| Primeira vez que abre | "Faxina gostaria de enviar notificações" | **Permitir** — é o aviso de pouco espaço |
| Ao medir dados de outros apps | "Faxina gostaria de acessar dados de outros apps" | **Permitir** — só mede o tamanho das pastas |
| Ao esvaziar a Lixeira | "Faxina quer controlar o Finder" | **OK** — é o Finder que esvazia a Lixeira |
| Opcional | Acesso Total ao Disco | Em **Ajustes da Faxina → Abrir Acesso Total ao Disco**, ligue a Faxina. Sem isso ela funciona, só não enxerga a Lixeira, o Safari e alguns dados de apps |

---

## Deixar abrindo sozinha quando o Mac liga

Na Faxina: **Ajustes → Abrir a Faxina quando o Mac ligar**. A vigia só funciona com o app aberto,
então vale ligar.

---

## Atualizar

```bash
cd ~/Downloads/faxina-mac     # a pasta onde você baixou
git pull
./build.sh instalar
open /Applications/Faxina.app
```

Suas configurações (meta, vigia) ficam como estão.

---

## Desinstalar

1. Na barra de menus: **✨ → Sair**.
2. Arraste **/Applications/Faxina.app** pra Lixeira.
3. (Opcional) apague as configurações e o histórico:
   ```bash
   defaults delete com.eduardomoraes.faxina
   rm -f ~/Library/Logs/Faxina.log
   ```

A Faxina não instala tarefa em segundo plano, extensão nem nada fora do próprio app.

---

## Problemas comuns

**`xcrun: error: invalid active developer path`** — faltam as ferramentas da Apple. Rode
`xcode-select --install` (passo 2).

**`permission denied: ./build.sh`** — rode `chmod +x build.sh` e tente de novo.

**`/Applications` não deixa copiar** — rode `./build.sh` (sem "instalar") e arraste
`build/Faxina.app` pra pasta Aplicativos pelo Finder.

**O ícone não aparece na barra de menus** — a barra pode estar cheia (comum em MacBook com
notch). Feche outros ícones ou segure **Cmd** e arraste ícones pra liberar espaço.

**Os números não batem com o "Armazenamento" dos Ajustes do Sistema** — normal. Veja
[PERGUNTAS.md](PERGUNTAS.md#por-que-os-números-não-batem-com-os-ajustes-do-sistema).
