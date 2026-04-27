import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../src/ui.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = context.read<AuthService>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        final User? signedInUser = snapshot.data ?? authService.currentUser;

        if (snapshot.connectionState == ConnectionState.waiting &&
            signedInUser == null) {
          return const _AuthLoadingScreen();
        }

        if (signedInUser != null) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final String? message = context
          .read<AuthService>()
          .takePendingSuccessMessage();
      if (message == null) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Color(0xFF1E7A46)),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MusixAuthenticatedHome();
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF160905),
              Color(0xFF281109),
              Color(0xFF0C0402),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E0D07),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF4A2112)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.settings_applications_rounded,
                        size: 52,
                        color: Color(0xFFFF9A47),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Firebase Setup Required',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This auth flow is ready, but Firebase is not connected to this app yet.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFDAB09B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '1. Create a Firebase project.\n'
                        '2. Enable Email/Password sign-in.\n'
                        '3. Run "flutterfire configure".\n'
                        '4. Add the generated Firebase files to this project.\n'
                        '5. Run the app again.',
                        style: TextStyle(color: Colors.white, height: 1.6),
                      ),
                      if (errorMessage != null) ...<Widget>[
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFFFC4B2)),
                        ),
                      ],
                    ],
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

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF160905),
              Color(0xFF281109),
              Color(0xFF0C0402),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.asset(
                'assets/icons/Musix - Full.png',
                width: 96,
                height: 96,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text(
                'MUSIX',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
