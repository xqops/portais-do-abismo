# Portais do Abismo

RPG de masmorras cooperativo para Roblox. Você entra no lobby, escolhe um portal, monta uma party de até 4 jogadores e enfrenta ondas de inimigos até chegar no chefe.

Dentro da masmorra, cada level up mostra 3 cartas (no estilo de *20 Minutes Till Dawn*): um poder novo, a evolução de um poder que você já tem ou um bônus de atributo.

## Gameplay

- **Party de até 4 jogadores**, com XP compartilhado entre o grupo e cartas escolhidas individualmente, sem pausar o jogo.
- **19 poderes**, cada um com 4 níveis. Os níveis 1 a 3 disparam sozinhos no inimigo mais próximo e o nível 4 é uma **ultimate** ativada manualmente.
- **Combo de espada** de 3 golpes (o último em área) e esquiva.
- **Inimigos com papéis diferentes** (perseguidor, corredor, arqueiro, brutamontes) e chefes com habilidades próprias.
- **Progressão salva**: nível de conta, ouro e masmorras concluídas. Para entrar na masmorra N é preciso vencer o chefe da N-1.
- **Efeitos visuais próprios**: partículas, rastros, espadas fantasmas caindo, meteoros, raios, tremor de câmera e números de dano.

## Controles

| Tecla | Ação |
|---|---|
| Clique (segurar) | Combo de espada |
| Q | Esquiva |
| 1 a 4 | Ultimate do poder no slot correspondente (poder no nível 4) |
| Clique na carta | Escolher upgrade |

## Arquitetura

O código fica separado em serviços no servidor e controllers no cliente, e todo o conteúdo do jogo é configurado em arquivos de dados. Dá para criar um poder, uma masmorra ou um inimigo novo sem mexer na lógica.

```
src/
  shared/
    Net.luau                  remotes
    Config/                   Game, Powers, Dungeons, Enemies, Progression
  server/
    Services/
      WorldBuilder.luau       gera o lobby e as arenas por código
      LobbyService.luau       fila dos portais e party
      DungeonService.luau     ondas, chefe, XP, cartas e recompensas
      PowerService.luau       executa os tipos de habilidade
      EnemyService.luau       IA, dano, status e habilidades de chefe
      DataService.luau        progresso salvo (DataStore)
      Projectiles, Effects, Registry, WeaponService
  client/
    Controllers/
      UI.luau                 HUD, cartas e avisos
      Input.luau              controles
      VFX.luau                efeitos, tremor de câmera, contador de abates
      Animator.luau           golpes de espada e animação dos monstros
      Feedback.luau           números de dano
assets/import/                modelos 3D prontos para importar no Studio
```

### Adicionando conteúdo

- **Poder novo:** uma entrada em `Config/Powers.luau` usando um dos tipos já existentes.
- **Tipo de habilidade novo:** uma função nova em `PowerService.luau`.
- **Masmorra nova:** uma entrada em `Config/Dungeons.luau`. O portal aparece sozinho no lobby.

## Como rodar

O projeto já vem com o place pronto: abra o `PortaisDoAbismo.rbxlx` no Roblox Studio e aperte **Play**.

- Para salvar progresso no Studio: *Game Settings → Security → Enable Studio Access to API Services*.
- Para testar o co-op: *Test → Clients and Servers → 2 jogadores → Start*.

### Modelos 3D

O jogo funciona sem nenhum asset (espada e monstros de blocos como reserva). Para usar os modelos de verdade, importe os arquivos de `assets/import/` no Studio para `ReplicatedStorage/Assets`:

```
ReplicatedStorage
└── Assets
    ├── Weapons    modelo "Sword"
    ├── Monsters   Skeleton_Minion, Skeleton_Rogue, Skeleton_Mage, Skeleton_Warrior
    └── VFX        packs de efeito opcionais
```

Ajustes sem mexer em código: atributo `Yaw = 180` para monstro andando de costas e `HeightScale` para o tamanho.

## Próximos passos

- Classes com bônus de atributo no início da run
- Armas e armaduras compradas com ouro
- Animações publicadas para os modelos importados
- Controles para celular
- Lobby e masmorras em places separados com `TeleportService`

## Tecnologias

Luau e Roblox Studio (DataStore, RemoteEvents, ParticleEmitters, TweenService).

## Créditos

Modelos de esqueletos e armas: [KayKit](https://kaylousberg.itch.io/) (CC0).
