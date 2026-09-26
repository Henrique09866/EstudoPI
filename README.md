# Curujão Estudos

Aplicativo Flutter offline para organizar tarefas e acompanhar estudos.

## Recursos

- tarefas com matérias, categorias, prioridades e lembretes locais;
- busca, filtros, calendário e recorrência;
- Área de estudos independente das tarefas, com Pomodoro 25/5, cronômetro livre e entrada rápida por matéria;
- escolha de objetivo de estudo (ENEM, EsPCEx, EFOMM, EEAR, concurso público ou personalizado) e matéria em cada sessão;
- painel de horas por matéria, com filtro por objetivo/período e gráficos de pizza ou barras;
- plano semanal por objetivo e matéria, comparando o tempo estudado com a meta definida;
- ciclo de estudos flexível: matérias livres, marcação semanal por dia e histórico anual em quadradinhos;
- revisão inteligente de matérias estudadas após 1, 7 e 30 dias;
- sessões e cronômetro em andamento persistidos, meta diária e acompanhamento de progresso;
- sequência de estudos, planejamento diário com prioridades e resumo semanal;
- contagem regressiva para prova, ENEM ou concurso;
- notas rápidas em cada sessão e reagendamento de tarefas atrasadas;
- Modo Corujão, controles de acessibilidade e Pomodoro personalizável;
- lembretes configuráveis por horário e dia da semana;
- notificações com sino para o tempo em andamento do cronômetro e alarmes do Pomodoro;
- funcionamento local com Hive, sem conta ou conexão com internet;
- conta opcional por e-mail e senha para sincronizar tarefas, sessões,
  metas, revisões, ciclo de estudos e simulados entre celular e tablet.

## Plataformas

- Android;
- Windows;
- Linux.

No Android, lembretes são agendados com notificações locais. No Windows, o suporte depende das capacidades oficiais do plugin e pode ter limitações de empacotamento. No Linux, o app mostra notificações imediatas — incluindo o andamento do cronômetro —, mas alarmes agendados para o futuro dependem das limitações do sistema.

## Executar

```bash
flutter pub get
flutter run
```

## Baixar/instalar no Linux

Para gerar a versão de PC em Linux, sem criar APK, execute:

```bash
sudo apt-get install -y cmake ninja-build pkg-config libgtk-3-dev clang
./scripts/build_linux_release.sh
```

O arquivo para distribuir ficará em `dist/curujao-estudos-linux-x64-<versão>.tar.gz`.
No computador que receber o pacote, extraia-o e execute `bundle/taskflow`.

## Versão web

Para testar no navegador:

```bash
flutter run -d chrome
```

Para publicar, o site precisa ser ligado a um projeto Firebase, pois é o
Firebase que cria as contas por e-mail e guarda os dados de cada pessoa.

1. No Firebase Console, crie ou selecione o projeto e adicione um app **Web**.
2. Ative **Authentication > Email/Password** e crie o banco **Cloud
   Firestore**.
3. Em **Authentication > Settings > Authorized domains**, adicione o domínio
   onde o site ficará hospedado.
4. Instale a FlutterFire CLI, entre na conta e gere a configuração web:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --platforms=web
   ```

   Isso substitui `lib/firebase_options.dart` pelas chaves públicas do seu
   projeto. Sem essa etapa, o site abre, mas o cadastro e o login ficam
   desativados de propósito.
5. Publique as regras de [firebase/firestore.rules](firebase/firestore.rules),
   gere o site e envie para o Firebase Hosting:

   ```bash
   flutter build web --release
   firebase deploy --only firestore:rules,hosting
   ```

O arquivo [firebase.json](firebase.json) já está pronto para o Hosting.

## Ativar conta e sincronização

O aplicativo continua funcionando offline, mas a sincronização requer um
projeto Firebase próprio. Crie um projeto no console do Firebase e registre o
app Android com o identificador `com.taskflow.app` e/ou o app Web.

1. Ative **Authentication > Email/Password**.
2. Crie um banco **Cloud Firestore**.
3. Publique as regras de [firebase/firestore.rules](firebase/firestore.rules).
   Elas impedem que uma conta acesse os dados de outra.
4. Instale a Firebase CLI, faça login e execute no diretório deste projeto:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

5. Gere a versão correspondente à sua plataforma. Para Linux, use
   `./scripts/build_linux_release.sh`; nenhum APK é necessário. Em
   **Configurações > Conta e sincronização**, crie uma conta e entre com o
   mesmo e-mail nos seus dispositivos.

O arquivo `android/app/google-services.json` é particular do projeto e não é
versionado. Sem essa configuração, o app mostra a área de conta, mas continua
em modo local e não envia dados para a nuvem.

## Testes

```bash
flutter analyze
flutter test
```
