# Perguntas frequentes

## "Apaguei 78 GB de mídia do WhatsApp e só liberou uns 30 GB"

Não é erro. Quando você encaminha o mesmo vídeo pra vários grupos, o macOS (sistema de arquivos
APFS) guarda **cópias que dividem o mesmo espaço** no disco (*clones*). As ferramentas de medição
contam cada cópia inteira, então a pasta "parece" ter 78 GB. Ao apagar, só volta o espaço que
existia de verdade, uma vez.

A Faxina mostra o tamanho medido e, depois de limpar, o ganho real de espaço livre.

## Por que os números não batem com os Ajustes do Sistema?

Os Ajustes contam como "disponível" também o espaço **purgável**: snapshots e caches que o próprio
macOS solta quando precisa. A Faxina mostra separado:

- **Espaço livre**: o que está livre agora (igual ao Finder).
- **O macOS libera sozinho**: o purgável.

## O que é a "atualização do macOS preparada"?

Quando o macOS baixa uma atualização, ele cria um *snapshot* (`com.apple.os.update-MSUPrepareUpdate`)
e reserva espaço até você instalar. Pode passar de 10 GB. Instalar a atualização (ou cancelar e
reiniciar) devolve esse espaço. A Faxina não mexe em snapshots do sistema.

## O que é swap? Dá pra apagar?

É a memória virtual: quando a RAM enche (Lightroom + Chrome + DaVinci…), o macOS escreve parte da
memória no disco. Não dá pra apagar com o Mac ligado e não deve. Ele diminui quando você fecha apps
pesados ou reinicia.

## Limpar cache deixa o Mac mais lento?

Por pouco tempo. Na primeira vez que você abre cada app ou foto depois de limpar, ele refaz o cache.
Por isso a Faxina não limpa sozinha a cada hora: a limpeza automática vem desligada e, se ligada,
só roda quando o espaço passa da sua meta.

## Por que um item fica com cadeado?

O app dele está aberto. Apagar cache com o app usando pode corromper o que ele está fazendo. Feche
o app (ou clique em **Fechar agora**) e o cadeado sai.

## A Faxina substitui o CleanMyMac?

Na parte de espaço em disco, sim: lixo do sistema, arquivos grandes, mapa, desinstalador, sobras de
apps, tarefas de fundo. Ela não tem antivírus, "otimização de RAM" nem limpeza de privacidade.

## É seguro? Ela manda meus dados pra algum lugar?

Não se conecta à internet. Não tem conta, telemetria nem atualização automática. O código é aberto:
dá pra ler tudo em [`Sources/`](../Sources). Tudo que ela apaga fica anotado em
`~/Library/Logs/Faxina.log`.

## Por que o macOS diz que o app "não pode ser aberto"?

Só acontece se você baixou o app pronto (jeito 2). Ele não é assinado com um certificado pago da
Apple. Libere em **Ajustes do Sistema → Privacidade e Segurança → Abrir Mesmo Assim**, ou compile
você mesmo (jeito 1), que não tem esse aviso. Veja [INSTALAR.md](INSTALAR.md).

## Posso mover o catálogo do Lightroom / pastas grandes pra um HD externo?

A Faxina não move pastas (de propósito: mover catálogo errado quebra o Lightroom). Use o próprio
Lightroom (**Arquivo → Exportar como catálogo** ou mover pelo Finder com o Lightroom fechado e abrir
o catálogo no novo lugar).
