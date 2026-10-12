import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'widget/colors.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.authService,
    required this.onAuthenticated,
    super.key,
  });

  final AuthService authService;
  final ValueChanged<String> onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isSignUp = false;
  bool _isBusy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final userId = _isSignUp
          ? await widget.authService.signUp(
              username: _usernameController.text,
              password: _passwordController.text,
            )
          : await widget.authService.signIn(
              username: _usernameController.text,
              password: _passwordController.text,
            );
      if (mounted) widget.onAuthenticated(userId);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('FormatException: ', '');
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/icon.png',
                          width: 88,
                          height: 88,
                          fit: BoxFit.contain,
                          semanticLabel: 'Logo FeedFlow',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isSignUp
                              ? 'Criar conta local'
                              : 'Entrar no FeedFlow',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Crie um usuário para manter seus feeds neste dispositivo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: FeedFlowColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _usernameController,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Usuário',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                            helperText:
                                '3 a 24 letras, números, ponto, hífen ou _',
                          ),
                          validator: (value) {
                            if (value == null ||
                                !RegExp(r'^[a-zA-Z0-9_.-]{3,24}$')
                                    .hasMatch(value.trim())) {
                              return 'Informe um usuário válido (3 a 24 caracteres).';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: _isSignUp
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onFieldSubmitted: _isSignUp ? null : (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            helperText: _isSignUp
                                ? 'Pelo menos 8 caracteres'
                                : null,
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              tooltip: _obscurePassword
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Informe sua senha.';
                            }
                            if (_isSignUp && value.length < 8) {
                              return 'A senha deve ter pelo menos 8 caracteres.';
                            }
                            return null;
                          },
                        ),
                        if (_isSignUp) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmationController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Confirmar senha',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            validator: (value) =>
                                value != _passwordController.text
                                ? 'As senhas não correspondem.'
                                : null,
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _isBusy ? null : _submit,
                          child: _isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_isSignUp ? 'Criar conta' : 'Entrar'),
                        ),
                        TextButton(
                          onPressed: _isBusy
                              ? null
                              : () => setState(() {
                                  _isSignUp = !_isSignUp;
                                  _error = null;
                                }),
                          child: Text(
                            _isSignUp
                                ? 'Já tenho uma conta'
                                : 'Criar conta local',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
