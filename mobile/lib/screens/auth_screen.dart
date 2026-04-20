import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../providers/auth_controller_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _registerName = TextEditingController();
  final _registerEmail = TextEditingController();
  final _registerPassword = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _registerName.dispose();
    _registerEmail.dispose();
    _registerPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      if (next.hasError && mounted) {
        final error = next.error;
        String message = error.toString();
        if (error is DioException) {
          final response = error.response?.data;
          if (response is Map && response['message'] != null) {
            message = response['message'].toString();
          } else if (error.response?.statusCode == 400) {
            message = 'Invalid input or credentials. Password must be at least 6 characters.';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });

    final state = ref.watch(authControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                'Offline Wallet',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('Phase 1 + Phase 2 foundation app'),
              const SizedBox(height: 24),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Login'),
                  Tab(text: 'Register'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _AuthForm(
                      children: [
                        TextField(
                          controller: _loginEmail,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _loginPassword,
                          decoration: const InputDecoration(labelText: 'Password'),
                          obscureText: true,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!_isValidEmail(_loginEmail.text.trim()) ||
                                      _loginPassword.text.length < 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Enter a valid email and password (min 6 chars).'),
                                      ),
                                    );
                                    return;
                                  }

                                  await ref.read(authControllerProvider.notifier).login(
                                        email: _loginEmail.text.trim(),
                                        password: _loginPassword.text,
                                      );
                                },
                          child: Text(isLoading ? 'Please wait...' : 'Login'),
                        ),
                      ],
                    ),
                    _AuthForm(
                      children: [
                        TextField(
                          controller: _registerName,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _registerEmail,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _registerPassword,
                          decoration: const InputDecoration(labelText: 'Password'),
                          obscureText: true,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (_registerName.text.trim().isEmpty ||
                                      !_isValidEmail(_registerEmail.text.trim()) ||
                                      _registerPassword.text.length < 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Enter name, valid email, and password (min 6 chars).'),
                                      ),
                                    );
                                    return;
                                  }

                                  await ref.read(authControllerProvider.notifier).register(
                                        name: _registerName.text.trim(),
                                        email: _registerEmail.text.trim(),
                                        password: _registerPassword.text,
                                      );
                                },
                          child: Text(isLoading ? 'Please wait...' : 'Create Account'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}