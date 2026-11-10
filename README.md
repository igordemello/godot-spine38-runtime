# Spine 3.8 Runtime para Godot 4

Addon em GDScript puro que toca no Godot 4 personagens animados no **Spine 3.8** e exportados em JSON.
Não precisa do runtime oficial nem de compilar nada.

Ele traz duas coisas:

- o nó **Spine38Sprite**, que toca a animação, com a lista de animações no Inspector e prévia dentro do editor;
- o painel **Spine38**, que importa um personagem com um clique: copia o JSON e as imagens para o projeto e cria a cena pronta.

> Projeto independente e não oficial, sem ligação com a Esoteric Software. Spine é uma marca da Esoteric Software.
> Para o Spine 4.x, use o runtime oficial [spine-godot](https://esotericsoftware.com/spine-godot).

## Download

1. Baixe o `spine38-addon.zip` da [última release](https://github.com/igordemello/godot-spine38-runtime/releases/latest).
2. Extraia e copie a pasta `addons` para dentro do seu projeto Godot.
3. Ative **Spine 3.8 Runtime** em **Projeto → Configurações do Projeto → Plugins**.

Testado no Godot 4.7.2 com exports do Spine 3.8.75.

## Documentação

O passo a passo de exportação e importação, o uso pelo código e a lista do que é suportado estão em
[addons/spine38/LEIA-ME.md](addons/spine38/LEIA-ME.md).

## Licença

[MIT](LICENSE)
