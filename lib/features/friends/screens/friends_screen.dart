import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _profiles = [];

  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Charge les profils des autres utilisateurs.
  Future<void> _loadProfiles() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await client
          .from('profiles')
          .select(
            'id, full_name, native_language, learning_language',
          )
          .neq('id', user.id)
          .order('full_name');

      if (!mounted) return;

      setState(() {
        _profiles = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[FRIENDS] Erreur de chargement : $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Impossible de charger les profils. '
            'Vérifie ta connexion et les permissions Supabase.';
        _isLoading = false;
      });
    }
  }

  /// Filtre les profils selon le nom ou les langues.
  List<Map<String, dynamic>> get _filteredProfiles {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _profiles;
    }

    return _profiles.where((profile) {
      final name =
          (profile['full_name'] as String? ?? '').toLowerCase();

      final nativeLanguage =
          (profile['native_language'] as String? ?? '')
              .toLowerCase();

      final learningLanguage =
          (profile['learning_language'] as String? ?? '')
              .toLowerCase();

      return name.contains(query) ||
          nativeLanguage.contains(query) ||
          learningLanguage.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profiles = _filteredProfiles;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Découvrir des amis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _isLoading ? null : _loadProfiles,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Présentation de la page.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fais de nouvelles rencontres !',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Découvre des personnes avec qui pratiquer '
                    'les langues que tu apprends.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Barre de recherche.
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Nom ou langue...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              tooltip: 'Effacer la recherche',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            )
                          : null,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenu de la liste.
            Expanded(
              child: _buildContent(
                context,
                theme,
                profiles,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    List<Map<String, dynamic>> profiles,
  ) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadProfiles,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (profiles.isEmpty) {
      final hasSearch = _searchQuery.trim().isNotEmpty;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasSearch
                    ? Icons.search_off_rounded
                    : Icons.people_outline_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                hasSearch
                    ? 'Aucun résultat'
                    : 'Pas encore de profils',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasSearch
                    ? 'Essaie un autre nom ou une autre langue.'
                    : 'Les profils des autres utilisateurs '
                        'apparaîtront ici.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfiles,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: profiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildProfileCard(
            context,
            theme,
            profiles[index],
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> profile,
  ) {
    final colors = theme.colorScheme;

    final name =
        (profile['full_name'] as String?)?.trim();

    final displayName =
        name == null || name.isEmpty ? 'Utilisateur' : name;

    final nativeLanguage =
        profile['native_language'] as String?;

    final learningLanguage =
        profile['learning_language'] as String?;

    final initials = displayName.characters.first.toUpperCase();

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: colors.primaryContainer,
              child: Text(
                initials,
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (nativeLanguage != null &&
                      nativeLanguage.isNotEmpty)
                    _buildLanguageRow(
                      icon: Icons.record_voice_over_rounded,
                      label: 'Parle : $nativeLanguage',
                      color: colors,
                    ),
                  if (nativeLanguage != null &&
                      nativeLanguage.isNotEmpty &&
                      learningLanguage != null &&
                      learningLanguage.isNotEmpty)
                    const SizedBox(height: 8),
                  if (learningLanguage != null &&
                      learningLanguage.isNotEmpty)
                    _buildLanguageRow(
                      icon: Icons.school_rounded,
                      label: 'Apprend : $learningLanguage',
                      color: colors,
                    ),
                  if ((nativeLanguage == null ||
                          nativeLanguage.isEmpty) &&
                      (learningLanguage == null ||
                          learningLanguage.isEmpty))
                    Text(
                      'Langues non renseignées',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
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

  Widget _buildLanguageRow({
    required IconData icon,
    required String label,
    required ColorScheme color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: color.primary,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
