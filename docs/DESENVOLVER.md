# Desenvolver

## Compilar

```bash
./build.sh            # build/Faxina.app (universal: arm64 + x86_64)
./build.sh instalar   # e copia pra /Applications
./build.sh zip        # e gera build/Faxina.zip + .sha256 (pra release)
```

Só precisa das Ferramentas de Linha de Comando (`xcode-select --install`). Sem Xcode, sem pacotes.

## Modo relatório (só mede)

```bash
build/Faxina.app/Contents/MacOS/Faxina --relatorio
```

Imprime o catálogo com tamanhos e apps abertos. Não apaga nada. Bom pra conferir um item novo.

## Adicionar um item ao catálogo

Em [`Sources/Catalogo.swift`](../Sources/Catalogo.swift), dentro de `Catalogo.montar()`:

```swift
add(.fotografia, "Cache do Capture One", .seguro,
    ["\(CA)/com.captureone.captureone16"],
    apps: ["com.captureone.captureone*"], nomes: ["Capture One"],
    nota: "Prévias do Capture One. Ele refaz sozinho.")
```

- Use `.revisar` se a pessoa perde algo (mídia, modelo que demora pra baixar, dado de app).
- Sempre diga em `nota` **o que acontece ao limpar**.
- Coloque itens específicos **antes** dos geradores automáticos (o primeiro a pegar um caminho fica com ele).
- Confira com `--relatorio`.

## Testes visuais (`--fotos`)

O app sabe fotografar as próprias janelas (sem precisar de permissão de gravação de tela):

```bash
swiftc -O Ferramentas/foto.swift -o /tmp/foto
open -n /Applications/Faxina.app --args --fotos /tmp/fotos
/tmp/foto 01-visao-geral        # salva /tmp/fotos/01-visao-geral-0.png
```

Sem `--fotos`, isso fica desligado.

## Testar a limpeza sem risco

Crie uma pasta falsa em `~/.faxina-teste`, monte um `Alvo` apontando pra ela e chame
`Faxineiro.limpar`. As travas de `Seguranca` recusam pastas-base — vale testar também
`Seguranca.podeEsvaziar(NSHomeDirectory() + "/Documents")` (tem que dar `false`).

## Publicar uma versão

1. Suba `VERSAO` em `build.sh` e o texto "Sobre" em `TelasFerramentas.swift`.
2. `./build.sh zip`
3. Crie a release no GitHub com `build/Faxina.zip` e `build/Faxina.zip.sha256`, e anote em `CHANGELOG.md`.
