# Usar a Faxina

## O caminho mais curto

1. Clique no **✨** da barra de menus.
2. Em **Lixo seguro**, clique em **Limpar** e depois em **Confirmar**.

Pronto. Isso apaga só cache e arquivos temporários, que os apps refazem sozinhos.

Pra liberar mais, abra a janela (**Abrir Faxina**) e vá em **Limpeza**.

---

## Visão geral

- **Anel**: espaço livre. O tique marca a sua meta. Verde = folga; laranja = perto da meta;
  vermelho = abaixo dela.
- **Lixo seguro**: quanto dá pra limpar agora, sem perder nada.
- **Pra revisar**: coisas grandes que são suas (mídia do WhatsApp, modelos de IA…). Abra a Limpeza
  pra decidir.
- **O macOS libera sozinho**: espaço que o sistema guarda de reserva (snapshots, caches dele) e solta
  quando precisa. Você não precisa fazer nada.
- **Memória virtual (swap)**: arquivo que o macOS usa quando a memória RAM enche. Diminui quando você
  fecha apps pesados ou reinicia.
- **Atualização do macOS preparada**: quando aparece, o sistema baixou uma atualização e está
  segurando espaço. Instalar (ou reiniciar) devolve.

## Limpeza

Cada item mostra o tamanho, o que é e o que acontece se limpar.

- ☑️ **Seguro** já vem marcado: cache e temporários.
- 🟠 **revise** vem desmarcado: é seu ou não volta sozinho. Leia a nota antes de marcar.
- 🔒 **Feche o app pra limpar**: o app está aberto. Clique em **Fechar agora** (é o Cmd+Q normal: se
  tiver algo sem salvar, o app pergunta) ou feche você mesmo e clique em ↻.
- 🔍 mostra a pasta no Finder.

Clique em **Liberar X GB**. A confirmação avisa se tem algum item "revise" na lista.

## Arquivos grandes

Escolha o tamanho mínimo (100 MB a 5 GB) e clique em **Procurar**. Pode trocar de tela enquanto
procura: o resultado fica guardado.

- Selecione (Cmd+clique pra vários) e clique em **Mover pra Lixeira**. Vai pra Lixeira, dá pra recuperar.
- 🔒 com cadeado não dá pra selecionar: catálogo do Lightroom, bancos de dados de apps, dados internos
  de apps. Apagar isso estragaria o app.
- "arquivo de app — prefira a Limpeza": é de algum app (modelo de IA, máquina virtual). Dá pra apagar,
  mas a Limpeza explica melhor o que é.

## Mapa do espaço

Mostra cada pasta com o tamanho, da maior pra menor. **Clique duas vezes** numa pasta pra entrar,
**‹** pra voltar. **Começar em** troca entre pasta pessoal, Biblioteca (oculta) e Aplicativos.
Pastas que o Finder esconde aparecem marcadas como **oculta**.

## Desinstalar apps

Cada app mostra o tamanho do app **e** dos dados que ele guarda na sua Biblioteca. **Desinstalar**
fecha o app (se estiver aberto) e manda tudo pra Lixeira.

Apps da Adobe não têm o botão: desinstale pelo Creative Cloud, que remove os serviços de fundo também.

No fim da lista, **Sobras de apps que já não estão no Mac**: pastas de apps que você apagou só
arrastando pra Lixeira. Marque e mova pra Lixeira. Confira os nomes.

## Segundo plano

Tarefas que rodam sozinhas no Mac (LaunchAgents):

- **reabre app sozinho**: se você fecha o app e ele volta, é isso.
- **programa não existe mais**: sobra de app desinstalado.
- **erro N**: a tarefa está falhando.

**Pausar** para a tarefa e ela não volta ao reiniciar. **Religar** desfaz. Tarefas "do sistema"
só aparecem pra você saber que existem.

Se algum navegador estiver com **controle remoto ligado** (usado por automações de IA), aparece um aviso
no topo.

## Ajustes

- **Meta**: quantos GB livres você quer manter. Abaixo disso o ícone fica vermelho e chega aviso.
- **Vigiar o disco**: confere a cada 30 min (com o app aberto).
- **Limpar o lixo seguro sozinho**: quando passar da meta, limpa o seguro sem perguntar. Desligado
  por padrão.
- **Abrir quando o Mac ligar**: recomendado, pra vigia funcionar.
- **Histórico**: tudo que a Faxina apagou, com data.
