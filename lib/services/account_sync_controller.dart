import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/mock_exam.dart';
import '../models/study_cycle_subject.dart';
import '../models/study_revision.dart';
import '../models/study_session.dart';
import '../models/study_weekly_goal.dart';
import '../models/task.dart';
import 'app_settings_controller.dart';
import 'study_session_storage.dart';
import 'task_storage.dart';

enum AccountSyncStatus { unavailable, signedOut, syncing, ready, error }

/// Erro já traduzido para ser exibido diretamente na interface do aplicativo.
class AccountSyncException implements Exception {
  const AccountSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mantém uma cópia privada dos dados de estudo em uma conta Firebase.
///
/// O app continua sendo local e offline. Ao entrar em uma conta, as listas são
/// combinadas por identificador e enviadas para a nuvem; assim, usar o mesmo
/// login em celular e tablet não apaga o que já existia em nenhum dos dois.
class AccountSyncController extends ChangeNotifier {
  factory AccountSyncController.firebase({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required TaskStorage taskStorage,
    required StudySessionStorage studyStorage,
    required AppSettingsController settingsController,
  }) => AccountSyncController._(
    auth: auth,
    firestore: firestore,
    taskStorage: taskStorage,
    studyStorage: studyStorage,
    settingsController: settingsController,
    isAvailable: true,
  );

  factory AccountSyncController.unavailable({
    required TaskStorage taskStorage,
    required StudySessionStorage studyStorage,
    required AppSettingsController settingsController,
    String? unavailableReason,
  }) => AccountSyncController._(
    auth: null,
    firestore: null,
    taskStorage: taskStorage,
    studyStorage: studyStorage,
    settingsController: settingsController,
    isAvailable: false,
    unavailableReason: unavailableReason,
  );

  AccountSyncController._({
    required this._auth,
    required this._firestore,
    required this._taskStorage,
    required this._studyStorage,
    required this._settingsController,
    required this._isAvailable,
    this.unavailableReason,
  });

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final TaskStorage _taskStorage;
  final StudySessionStorage _studyStorage;
  final AppSettingsController _settingsController;
  final bool _isAvailable;

  /// Explicação técnica curta usada somente quando o APK ainda não recebeu a
  /// configuração do projeto Firebase.
  final String? unavailableReason;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _documentSubscription;
  User? _user;
  AccountSyncStatus _status = AccountSyncStatus.signedOut;
  DateTime? _lastSyncAt;
  String? _lastError;
  bool _isBusy = false;
  bool _isApplyingRemoteData = false;
  String? _initialSyncUserId;
  int _dataVersion = 0;

  bool get isAvailable => _isAvailable;
  bool get isBusy => _isBusy;
  bool get isSignedIn => _user != null;
  String? get email => _user?.email;
  String? get displayName => _user?.displayName;
  String? get userId => _user?.uid;
  AccountSyncStatus get status => _status;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;

  /// Incrementado quando uma alteração chegou de outro aparelho.
  int get dataVersion => _dataVersion;

  Future<void> initialize() async {
    if (!isAvailable) {
      _status = AccountSyncStatus.unavailable;
      notifyListeners();
      return;
    }

    _user = _auth!.currentUser;
    _authSubscription = _auth.authStateChanges().listen(_onAuthChanged);
    _status = _user == null
        ? AccountSyncStatus.signedOut
        : AccountSyncStatus.syncing;
    notifyListeners();

    if (_user != null) {
      // A sincronização inicial depende da rede e não pode impedir o Flutter
      // de montar a interface. O usuário pode continuar usando os dados
      // locais enquanto a conta é sincronizada em segundo plano.
      unawaited(_syncSilently());
    }
  }

  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    await _authenticate(() {
      return _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    await _authenticate(() {
      return _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    });
  }

  Future<void> sendPasswordReset(String email) async {
    _ensureAvailable();
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw const AccountSyncException('Informe seu e-mail primeiro.');
    }
    try {
      _isBusy = true;
      notifyListeners();
      await _auth!.setLanguageCode('pt-BR');
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    } on Object catch (error) {
      throw AccountSyncException(_friendlyError(error));
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    try {
      _isBusy = true;
      notifyListeners();
      await _auth!.signOut();
      _user = null;
      await _documentSubscription?.cancel();
      _documentSubscription = null;
      _status = AccountSyncStatus.signedOut;
      _lastSyncAt = null;
      _lastError = null;
      _initialSyncUserId = null;
    } on Object catch (error) {
      _lastError = _friendlyError(error);
      _status = AccountSyncStatus.error;
      throw AccountSyncException(_lastError!);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Envia a cópia local e antes incorpora o que já estiver salvo na nuvem.
  Future<void> syncNow() async {
    _ensureAvailable();
    final currentUser = _auth!.currentUser;
    if (currentUser == null) {
      throw const AccountSyncException('Entre na sua conta para sincronizar.');
    }
    if (_isBusy && _status == AccountSyncStatus.syncing) return;

    _user = currentUser;
    _isBusy = true;
    _status = AccountSyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    try {
      final document = _documentFor(currentUser.uid);
      if (_initialSyncUserId != currentUser.uid) {
        final remoteDocument = await document.get();
        if (remoteDocument.exists) {
          final remote = _CloudStudyData.fromDocument(remoteDocument.data());
          await _applyRemoteData(remote, mergeWithLocal: true);
        }
        _initialSyncUserId = currentUser.uid;
      }

      await document.set({
        'schemaVersion': 1,
        'updatedAt': FieldValue.serverTimestamp(),
        'studyData': (await _readLocalData()).toMap(),
      });
      _lastSyncAt = DateTime.now();
      _status = AccountSyncStatus.ready;
      _watchDocument(currentUser.uid);
    } on Object catch (error) {
      _lastError = _friendlyError(error);
      _status = AccountSyncStatus.error;
      throw AccountSyncException(_lastError!);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Pode ser chamado quando o usuário altera uma tarefa, uma meta ou sessão.
  /// Falhas de rede não interrompem o uso normal do aplicativo.
  void syncAfterLocalChange() {
    if (!isAvailable || !isSignedIn || _isApplyingRemoteData || _isBusy) {
      return;
    }
    unawaited(_syncSilently());
  }

  Future<void> _syncSilently() async {
    try {
      await syncNow();
    } on AccountSyncException {
      // O cartão da conta mostrará o estado de erro sem bloquear a tela atual.
    }
  }

  Future<void> _authenticate(
    Future<UserCredential> Function() authenticate,
  ) async {
    _ensureAvailable();
    try {
      _isBusy = true;
      _status = AccountSyncStatus.syncing;
      _lastError = null;
      notifyListeners();
      final credential = await authenticate();
      _user = credential.user;
      if (_user == null) {
        throw const AccountSyncException('Não foi possível abrir esta conta.');
      }
      _isBusy = false;
      await syncNow();
    } on AccountSyncException {
      rethrow;
    } on Object catch (error) {
      _lastError = _friendlyError(error);
      _status = AccountSyncStatus.error;
      throw AccountSyncException(_lastError!);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _onAuthChanged(User? user) {
    if (_user?.uid == user?.uid) return;
    _user = user;
    if (user == null) {
      unawaited(_documentSubscription?.cancel() ?? Future<void>.value());
      _documentSubscription = null;
      _status = AccountSyncStatus.signedOut;
      _lastSyncAt = null;
      _initialSyncUserId = null;
    } else {
      _initialSyncUserId = null;
      _status = AccountSyncStatus.ready;
      unawaited(_syncSilently());
    }
    notifyListeners();
  }

  void _watchDocument(String userId) {
    unawaited(_documentSubscription?.cancel() ?? Future<void>.value());
    _documentSubscription = _documentFor(userId).snapshots().listen((snapshot) {
      if (!snapshot.exists || _isApplyingRemoteData) return;
      final remote = _CloudStudyData.fromDocument(snapshot.data());
      unawaited(_applyRemoteDataSilently(remote));
    });
  }

  Future<void> _applyRemoteDataSilently(_CloudStudyData remote) async {
    try {
      await _applyRemoteData(remote);
      _lastSyncAt = DateTime.now();
      if (_status != AccountSyncStatus.syncing) {
        _status = AccountSyncStatus.ready;
      }
      notifyListeners();
    } catch (_) {
      // Uma atualização recebida não pode deslogar o usuário nem impedir o
      // próximo envio manual. O Firestore tentará entregá-la novamente.
    }
  }

  Future<void> _applyRemoteData(
    _CloudStudyData remote, {
    bool mergeWithLocal = false,
  }) async {
    if (_isApplyingRemoteData) return;
    _isApplyingRemoteData = true;
    try {
      final data = mergeWithLocal
          ? (await _readLocalData()).merge(remote)
          : remote;

      await _taskStorage.replaceAllTasks(data.tasks);
      await _studyStorage.replaceAllStudyData(
        sessions: data.sessions,
        dailyGoalMinutes: data.dailyGoalMinutes,
        weeklyGoals: data.weeklyGoals,
        revisions: data.revisions,
        cycleSubjects: data.cycleSubjects,
        cycleCheckIns: data.cycleCheckIns,
        mockExams: data.mockExams,
      );
      if (data.settings != null) {
        await _settingsController.replaceFromCloud(data.settings!);
      }
      _dataVersion++;
    } finally {
      _isApplyingRemoteData = false;
    }
  }

  Future<_CloudStudyData> _readLocalData() async {
    final values = await Future.wait<Object>([
      _taskStorage.getTasks(),
      _studyStorage.getSessions(),
      _studyStorage.getDailyGoalMinutes(),
      _studyStorage.getWeeklyGoals(),
      _studyStorage.getRevisions(),
      _studyStorage.getCycleSubjects(),
      _studyStorage.getCycleCheckIns(),
      _studyStorage.getMockExams(),
    ]);
    return _CloudStudyData(
      tasks: values[0] as List<Task>,
      sessions: values[1] as List<StudySession>,
      dailyGoalMinutes: values[2] as int,
      weeklyGoals: values[3] as List<StudyWeeklyGoal>,
      revisions: values[4] as List<StudyRevision>,
      cycleSubjects: values[5] as List<StudyCycleSubject>,
      cycleCheckIns: values[6] as List<StudyCycleCheckIn>,
      mockExams: values[7] as List<MockExam>,
      settings: _settingsController.settings,
    );
  }

  DocumentReference<Map<String, dynamic>> _documentFor(String userId) =>
      _firestore!.collection('users').doc(userId);

  void _ensureAvailable() {
    if (!isAvailable) {
      throw const AccountSyncException(
        'A sincronização ainda não foi ativada neste aplicativo.',
      );
    }
  }

  static String _friendlyError(Object error) {
    if (error is AccountSyncException) return error.message;
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Digite um e-mail válido.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'E-mail ou senha incorretos.',
        'email-already-in-use' => 'Este e-mail já possui uma conta.',
        'weak-password' => 'Use uma senha com pelo menos 6 caracteres.',
        'too-many-requests' =>
          'Muitas tentativas. Aguarde alguns minutos e tente novamente.',
        'network-request-failed' => 'Sem internet. Tente novamente mais tarde.',
        _ => error.message ?? 'Não foi possível concluir esta ação.',
      };
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Sua conta não tem permissão para acessar estes dados.',
        'unavailable' => 'Sem conexão com a nuvem. Tente novamente mais tarde.',
        _ => error.message ?? 'Não foi possível sincronizar agora.',
      };
    }
    return 'Não foi possível sincronizar agora. Tente novamente.';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _documentSubscription?.cancel();
    super.dispose();
  }
}

class _CloudStudyData {
  const _CloudStudyData({
    required this.tasks,
    required this.sessions,
    required this.dailyGoalMinutes,
    required this.weeklyGoals,
    required this.revisions,
    required this.cycleSubjects,
    required this.cycleCheckIns,
    required this.mockExams,
    required this.settings,
  });

  final List<Task> tasks;
  final List<StudySession> sessions;
  final int dailyGoalMinutes;
  final List<StudyWeeklyGoal> weeklyGoals;
  final List<StudyRevision> revisions;
  final List<StudyCycleSubject> cycleSubjects;
  final List<StudyCycleCheckIn> cycleCheckIns;
  final List<MockExam> mockExams;
  final AppSettings? settings;

  Map<String, dynamic> toMap() {
    final settingsMap = settings == null
        ? null
        : (Map<String, dynamic>.from(settings!.toMap())
            ..remove('dailyReminderPermissionRequested')
            ..remove('dailyReminderPermissionGranted'));
    return {
      'tasks': tasks.map((task) => task.toMap()).toList(),
      'sessions': sessions.map((session) => session.toMap()).toList(),
      'dailyGoalMinutes': dailyGoalMinutes,
      'weeklyGoals': weeklyGoals.map((goal) => goal.toMap()).toList(),
      'revisions': revisions.map((revision) => revision.toMap()).toList(),
      'cycleSubjects': cycleSubjects.map((subject) => subject.toMap()).toList(),
      'cycleCheckIns': cycleCheckIns.map((checkIn) => checkIn.toMap()).toList(),
      'mockExams': mockExams.map((exam) => exam.toMap()).toList(),
      'settings': settingsMap,
    };
  }

  factory _CloudStudyData.fromDocument(Map<String, dynamic>? document) {
    final raw = document?['studyData'];
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    final rawSettings = data['settings'];
    return _CloudStudyData(
      tasks: _items(data['tasks'], Task.fromMap),
      sessions: _items(data['sessions'], StudySession.fromMap),
      dailyGoalMinutes: _positiveInt(data['dailyGoalMinutes'], fallback: 60),
      weeklyGoals: _items(data['weeklyGoals'], StudyWeeklyGoal.fromMap),
      revisions: _items(data['revisions'], StudyRevision.fromMap),
      cycleSubjects: _items(data['cycleSubjects'], StudyCycleSubject.fromMap),
      cycleCheckIns: _items(data['cycleCheckIns'], StudyCycleCheckIn.fromMap),
      mockExams: _items(data['mockExams'], MockExam.fromMap),
      settings: rawSettings is Map
          ? AppSettings.fromMap(Map<String, dynamic>.from(rawSettings))
          : null,
    );
  }

  _CloudStudyData merge(_CloudStudyData remote) => _CloudStudyData(
    tasks: _mergeById(tasks, remote.tasks, (item) => item.id),
    sessions: _mergeById(sessions, remote.sessions, (item) => item.id),
    dailyGoalMinutes: remote.dailyGoalMinutes,
    weeklyGoals: _mergeById(weeklyGoals, remote.weeklyGoals, (item) => item.id),
    revisions: _mergeById(revisions, remote.revisions, (item) => item.id),
    cycleSubjects: _mergeById(
      cycleSubjects,
      remote.cycleSubjects,
      (item) => item.id,
    ),
    cycleCheckIns: _mergeById(
      cycleCheckIns,
      remote.cycleCheckIns,
      (item) => item.id,
    ),
    mockExams: _mergeById(mockExams, remote.mockExams, (item) => item.id),
    settings: remote.settings ?? settings,
  );

  static List<T> _items<T>(
    Object? raw,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (raw is! Iterable) return const [];
    final items = <T>[];
    for (final value in raw.whereType<Map>()) {
      try {
        items.add(parse(Map<String, dynamic>.from(value)));
      } catch (_) {
        // Um item corrompido não impede recuperar o restante da conta.
      }
    }
    return List.unmodifiable(items);
  }

  static List<T> _mergeById<T>(
    List<T> local,
    List<T> remote,
    String Function(T item) getId,
  ) {
    final combined = <String, T>{
      for (final item in local) getId(item): item,
      // Em conflito, a cópia que já estava na nuvem vence. Isso permite que
      // uma edição feita no tablet apareça no celular ao reconectar.
      for (final item in remote) getId(item): item,
    };
    return List.unmodifiable(combined.values);
  }

  static int _positiveInt(Object? value, {required int fallback}) =>
      value is num && value > 0 ? value.toInt() : fallback;
}
