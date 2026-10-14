import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_strings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoggingOut = false;

  String? _fullName;
  String? _nativeLanguage;
  String? _learningLanguage;

  final List<String> _languages = [
    AppStrings.languageMalagasy,
    AppStrings.languageFrench,
    AppStrings.languageEnglish,
    AppStrings.languageSpanish,
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Charge les informations du profil depuis Supabase.
  Future<void> _loadProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      final profile = await client
          .from('profiles')
          .select(
            'full_name, native_language, learning_language',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _fullName = profile?['full_name'] as String?;
        _nativeLanguage =
            profile?['native_language'] as String?;
        _learningLanguage =
            profile?['learning_language'] as String?;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.profileLoadError),
        ),
      );
    }
  }

  /// Enregistre les langues choisies dans Supabase.
  Future<void> _saveProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    // Vérifie que les deux langues sont sélectionnées.
    if (_nativeLanguage == null ||
        _learningLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.selectLanguage),
        ),
      );
      return;
    }

    // Empêche de choisir la même langue deux fois.
    if (_nativeLanguage == _learningLanguage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            AppStrings.differentLanguagesError,
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await client.from('profiles').upsert({
        'id': user.id,
        'full_name': _fullName ??
            user.userMetadata?['full_name'] as String?,
        'native_language': _nativeLanguage,
        'learning_language': _learningLanguage,
        'updated_at': DateTime.now()
            .toUtc()
            .toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            AppStrings.profileSaveSuccess,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            AppStrings.profileSaveError,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Déconnecte l'utilisateur de Supabase.
  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      context.go('/login');
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.logoutErrorPrefix}'
            '${error.message}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            AppStrings.logoutUnexpectedError,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;

    // Affiche un indicateur pendant le chargement.
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profileTitle),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 480,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar du profil.
                CircleAvatar(
                  radius: 44,
                  backgroundColor:
                      theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_rounded,
                    size: 48,
                    color: theme
                        .colorScheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(height: 20),

                // Titre du profil.
                Text(
                  AppStrings.myProfile,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 24),

                // Nom complet.
                Text(
                  AppStrings.profileName,
                  style: theme.textTheme.labelLarge,
                ),

                const SizedBox(height: 6),

                Text(_fullName ?? '—'),

                const SizedBox(height: 16),

                // Adresse e-mail.
                Text(
                  AppStrings.profileEmail,
                  style: theme.textTheme.labelLarge,
                ),

                const SizedBox(height: 6),

                Text(user?.email ?? '—'),

                const SizedBox(height: 24),

                // Sélection de la langue maternelle.
                DropdownButtonFormField<String>(
                  initialValue:
                      _languages.contains(_nativeLanguage)
                          ? _nativeLanguage
                          : null,
                  decoration: const InputDecoration(
                    labelText: AppStrings.nativeLanguage,
                    border: OutlineInputBorder(),
                  ),
                  items: _languages.map((language) {
                    return DropdownMenuItem<String>(
                      value: language,
                      child: Text(language),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _nativeLanguage = value;
                    });
                  },
                ),

                const SizedBox(height: 16),

                // Sélection de la langue à apprendre.
                DropdownButtonFormField<String>(
                  initialValue:
                      _languages.contains(_learningLanguage)
                          ? _learningLanguage
                          : null,
                  decoration: const InputDecoration(
                    labelText: AppStrings.learningLanguage,
                    border: OutlineInputBorder(),
                  ),
                  items: _languages.map((language) {
                    return DropdownMenuItem<String>(
                      value: language,
                      child: Text(language),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _learningLanguage = value;
                    });
                  },
                ),

                const SizedBox(height: 24),

                // Bouton d'enregistrement.
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSaving
                        ? AppStrings.savingProfile
                        : AppStrings.saveProfile,
                  ),
                ),

                const SizedBox(height: 16),

                // Bouton de déconnexion.
                OutlinedButton.icon(
                  onPressed:
                      _isLoggingOut ? null : _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(
                    _isLoggingOut
                        ? AppStrings.loggingOut
                        : AppStrings.logout,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
