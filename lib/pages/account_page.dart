import 'package:flutter/material.dart';

import '../services/account_sync_controller.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.controller});

  final AccountSyncController controller;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _creatingAccount = false;
  var _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _emailController.text = widget.controller.email ?? '';
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      if (_creatingAccount) {
        await widget.controller.createAccount(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.controller.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (!mounted) return;
      _passwordController.clear();
      _showMessage(
        'Conta conectada. Seus dados já podem aparecer no outro aparelho.',
      );
    } on AccountSyncException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Digite seu e-mail para recuperar a senha.', isError: true);
      return;
    }
    try {
      await widget.controller.sendPasswordReset(email);
      if (mounted) {
        _showMessage('Enviamos um link de recuperação para $email.');
      }
    } on AccountSyncException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    }
  }

  Future<void> _syncNow() async {
    try {
      await widget.controller.syncNow();
      if (mounted) _showMessage('Dados sincronizados com sucesso.');
    } on AccountSyncException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Sair desta conta?'),
        content: const Text(
          'Os dados que já estão neste aparelho continuam salvos. Você poderá entrar novamente quando quiser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.controller.signOut();
    } on AccountSyncException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Conta e sincronização')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                _IntroCard(isAvailable: controller.isAvailable),
                const SizedBox(height: 16),
                if (!controller.isAvailable)
                  _UnavailableCard(reason: controller.unavailableReason)
                else if (controller.isSignedIn)
                  _ConnectedAccount(
                    controller: controller,
                    onSyncNow: _syncNow,
                    onSignOut: _signOut,
                  )
                else
                  _SignInForm(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    creatingAccount: _creatingAccount,
                    obscurePassword: _obscurePassword,
                    isBusy: controller.isBusy,
                    onModeChanged: (creating) {
                      setState(() => _creatingAccount = creating);
                    },
                    onObscureChanged: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    onSubmit: _submit,
                    onForgotPassword: _sendPasswordReset,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.isAvailable});

  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isAvailable
                  ? Icons.cloud_sync_outlined
                  : Icons.cloud_off_outlined,
              color: colors.onPrimaryContainer,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estude no celular e continue no tablet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Entre com o mesmo e-mail nos dois aparelhos para sincronizar tarefas, sessões, metas, revisões e simulados.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sincronização ainda não ativada',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            reason ??
                'Este aplicativo ainda precisa ser conectado ao projeto Firebase. Enquanto isso, seus dados continuam protegidos neste aparelho.',
          ),
        ],
      ),
    ),
  );
}

class _ConnectedAccount extends StatelessWidget {
  const _ConnectedAccount({
    required this.controller,
    required this.onSyncNow,
    required this.onSignOut,
  });

  final AccountSyncController controller;
  final Future<void> Function() onSyncNow;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final isBusy = controller.isBusy;
    final subtitle = switch (controller.status) {
      AccountSyncStatus.syncing => 'Sincronizando seus dados…',
      AccountSyncStatus.error =>
        controller.lastError ?? 'Não foi possível sincronizar.',
      _ =>
        controller.lastSyncAt == null
            ? 'Conta conectada.'
            : 'Sincronizado às ${_timeLabel(controller.lastSyncAt!)}.',
    };
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
            title: Text(controller.email ?? 'Conta conectada'),
            subtitle: Text(subtitle),
          ),
          const Divider(height: 1),
          ListTile(
            key: const ValueKey('sync-now-button'),
            leading: const Icon(Icons.sync_rounded),
            title: const Text('Sincronizar agora'),
            subtitle: const Text('Atualiza esta cópia com a nuvem.'),
            trailing: isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: isBusy ? null : onSyncNow,
          ),
          const Divider(height: 1),
          ListTile(
            key: const ValueKey('sign-out-button'),
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sair da conta'),
            onTap: isBusy ? null : onSignOut,
          ),
        ],
      ),
    );
  }

  static String _timeLabel(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.creatingAccount,
    required this.obscurePassword,
    required this.isBusy,
    required this.onModeChanged,
    required this.onObscureChanged,
    required this.onSubmit,
    required this.onForgotPassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool creatingAccount;
  final bool obscurePassword;
  final bool isBusy;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onObscureChanged;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onForgotPassword;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              creatingAccount ? 'Criar minha conta' : 'Entrar na minha conta',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              creatingAccount
                  ? 'Use este mesmo e-mail também no tablet.'
                  : 'Use o mesmo e-mail que você cadastrou no outro aparelho.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('account-email-field'),
              controller: emailController,
              enabled: !isBusy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return 'Digite um e-mail válido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('account-password-field'),
              controller: passwordController,
              enabled: !isBusy,
              obscureText: obscurePassword,
              autofillHints: creatingAccount
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: isBusy ? null : onObscureChanged,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if ((value?.length ?? 0) < 6) {
                  return 'A senha precisa ter ao menos 6 caracteres.';
                }
                return null;
              },
              onFieldSubmitted: (_) => onSubmit(),
            ),
            if (!creatingAccount)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isBusy ? null : onForgotPassword,
                  child: const Text('Esqueci minha senha'),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('account-submit-button'),
              onPressed: isBusy ? null : onSubmit,
              icon: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      creatingAccount
                          ? Icons.person_add_alt_1_rounded
                          : Icons.login_rounded,
                    ),
              label: Text(creatingAccount ? 'Criar conta' : 'Entrar'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: isBusy ? null : () => onModeChanged(!creatingAccount),
              child: Text(
                creatingAccount
                    ? 'Já tenho uma conta'
                    : 'Ainda não tenho conta',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
