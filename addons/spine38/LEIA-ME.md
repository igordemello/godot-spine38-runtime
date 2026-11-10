# Spine 3.8 Runtime para Godot 4

Toca no Godot 4 os personagens animados no **Spine 3.8**, exportados em JSON.
Não precisa do runtime oficial nem de compilar nada: é GDScript puro.

## 1. Instalar

1. Copie a pasta `addons/spine38` para dentro do seu projeto, para ficar em `res://addons/spine38/`.
   Também dá para usar a aba **AssetLib → Importar…** e escolher o `.zip`.
2. Vá em **Projeto → Configurações do Projeto → Plugins** e ative **Spine 3.8 Runtime**.
3. Aparece a aba **Spine38** no canto superior esquerdo do editor, ao lado de **Cena** e **Importar**.

## 2. Exportar do Spine 3.8

1. No Spine, abra **Exportar** (Ctrl+E) e escolha **JSON**.
2. Deixe **Texture Atlas** desmarcado, porque o addon usa as imagens soltas.
3. Dica: salve o `.json` na mesma pasta do arquivo `.spine`. Assim o addon encontra as imagens sozinho.

## 3. Importar no Godot

1. No painel **Spine38**, clique em **Importar personagem do Spine…** e escolha o `.json`.
2. Se o addon não encontrar as imagens, ele pergunta onde está a pasta.
3. Ele cria a pasta `res://spine/<nome>/` com o JSON, as imagens e a cena `<nome>.tscn`, e abre a cena.

O painel mostra cada passo e avisa (⚠) se o rig usa algo que o addon não suporta.

**Mudou a animação no Spine?** Exporte de novo e importe o mesmo `.json`.
A cena que já existe é mantida, com as suas mudanças. Só o JSON e as imagens são trocados.

## 4. Usar

- Arraste o `<nome>.tscn` para a sua fase. Outra opção: adicione um nó **Spine38Sprite** e arraste o `.json` para **Skeleton Json**.
- No Inspector você ajusta **Animation** (uma lista com as animações), **Loop**, **Speed** e **Playing**. A prévia toca dentro do editor.
- Pelo código:

```gdscript
$Chibi.play("Idle")             # toca em loop
$Chibi.play("Ataque", false)    # toca uma vez
await $Chibi.animation_finished # espera terminar
$Chibi.speed = 1.5
print($Chibi.get_animations())
```

## O que funciona

| Recurso do Spine | Suporte |
|---|---|
| Ossos com rotate, translate, scale e shear, incluindo curvas e stepped | ✔ |
| Imagens (region) e meshes, com ou sem pesos | ✔ |
| Cor do slot na pose de setup | ✔ |
| IK, transform e path constraints | ✖ |
| Deform (animar vértices da mesh) | ✖ |
| Trocar imagem, cor ou ordem de desenho durante a animação | ✖ |
| Eventos, skins além da default, blend modes e clipping | ✖ |
| Transição suave entre animações | ✖ |

Se o personagem usar algo marcado com ✖, aparece um ⚠ no nó e no painel dizendo o quê.

## Problemas comuns

- **O personagem não aparece / "Imagem não encontrada":** as imagens não estão na pasta `images/` ao lado do JSON. Importe de novo e indique a pasta, ou preencha **Images Dir** no nó.
- **O personagem ficou enorme:** o Spine trabalha no tamanho da arte. Diminua o **Scale** do nó.
- **"Exportado pelo Spine 4.x":** este addon é só para o Spine 3.8. Para o 4.x, use o runtime oficial spine-godot.
