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
  List<Map<String, dynamic>> _friendRequests = [];

  final Set<String> _processingIds = {};

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

  /// Charge les profils et les demandes d'amis.
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
      // 1. Charger les profils des autres utilisateurs.
      final profilesResponse = await client
          .from('profiles')
          .select('id, full_name, native_language, learning_language')
          .neq('id', user.id)
          .order('full_name');

      // 2. Charger les demandes envoyées et reçues.
      final requestsResponse = await client
          .from('friend_requests')
          .select('id, sender_id, receiver_id, status, created_at')
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}');

      if (!mounted) return;

      setState(() {
        _profiles = List<Map<String, dynamic>>.from(profilesResponse);
        _friendRequests = List<Map<String, dynamic>>.from(requestsResponse);
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[FRIENDS] Erreur de chargement : $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Impossible de charger les profils ou les demandes. '
            'Vérifie ta connexion et les permissions Supabase.';
        _isLoading = false;
      });
    }
  }

  /// Recherche une demande entre l'utilisateur connecté et un profil.
  Map<String, dynamic>? _getRequestForProfile(
    String profileId,
    String currentUserId,
  ) {
    for (final request in _friendRequests) {
      final senderId = request['sender_id'] as String;
      final receiverId = request['receiver_id'] as String;

      final samePair =
          (senderId == currentUserId && receiverId == profileId) ||
          (senderId == profileId && receiverId == currentUserId);

      if (samePair) {
        return request;
      }
    }

    return null;
  }

  /// Filtre les profils par nom ou par langue.
  List<Map<String, dynamic>> get _filteredProfiles {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _profiles;
    }

    return _profiles.where((profile) {
      final name = (profile['full_name'] as String? ?? '').toLowerCase();

      final nativeLanguage = (profile['native_language'] as String? ?? '')
          .toLowerCase();

      final learningLanguage = (profile['learning_language'] as String? ?? '')
          .toLowerCase();

      return name.contains(query) ||
          nativeLanguage.contains(query) ||
          learningLanguage.contains(query);
    }).toList();
  }

  /// Affiche un message à l'utilisateur.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Envoie une demande d'ami.
  Future<void> _sendFriendRequest(String receiverId) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    if (_processingIds.contains(receiverId)) return;

    final existingRequest = _getRequestForProfile(receiverId, user.id);

    // On ne crée pas une nouvelle demande si une demande
    // est déjà en attente ou si les utilisateurs sont amis.
    if (existingRequest != null) {
      final status = existingRequest['status'] as String;

      if (status == 'pending') {
        _showMessage('Une demande est déjà en attente entre vous.');
        return;
      }

      if (status == 'accepted') {
        _showMessage('Vous êtes déjà amis.');
        return;
      }

      if (status == 'rejected') {
        _showMessage(
          'Une demande précédente a été refusée. '
          'Une nouvelle demande nécessite une gestion spécifique.',
        );
        return;
      }
    }

    setState(() {
      _processingIds.add(receiverId);
    });

    try {
      await client.from('friend_requests').insert({
        'sender_id': user.id,
        'receiver_id': receiverId,
        'status': 'pending',
      });

      await _loadProfiles();

      if (!mounted) return;

      _showMessage('Demande d’ami envoyée !');
    } on PostgrestException catch (error) {
      debugPrint('[FRIENDS] Erreur Supabase : ${error.message}');

      if (!mounted) return;

      _showMessage(
        'Impossible d’envoyer la demande. '
        'Vérifie les permissions ou réessaie.',
      );
    } catch (error, stackTrace) {
      debugPrint('[FRIENDS] Erreur inattendue : $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showMessage('Une erreur inattendue est survenue.');
    } finally {
      if (mounted) {
        setState(() {
          _processingIds.remove(receiverId);
        });
      }
    }
  }

  /// Accepte ou refuse une demande reçue.
  Future<void> _respondToFriendRequest({
    required String requestId,
    required String status,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    if (status != 'accepted' && status != 'rejected') {
      return;
    }

    if (_processingIds.contains(requestId)) return;

    setState(() {
      _processingIds.add(requestId);
    });

    try {
      // La condition receiver_id protège aussi contre
      // une tentative de réponse à la demande d'un autre.
      final response = await client
          .from('friend_requests')
          .update({
            'status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('receiver_id', user.id)
          .eq('status', 'pending')
          .select('id')
          .maybeSingle();

      if (!mounted) return;

      if (response == null) {
        _showMessage(
          'La demande a déjà été traitée ou tu ne peux pas '
          'la modifier.',
        );
        await _loadProfiles();
        return;
      }

      await _loadProfiles();

      if (!mounted) return;

      _showMessage(
        status == 'accepted' ? 'Demande acceptée !' : 'Demande refusée.',
      );
    } on PostgrestException catch (error) {
      debugPrint('[FRIENDS] Erreur de réponse : ${error.message}');

      if (!mounted) return;

      _showMessage(
        'Impossible de traiter la demande. '
        'Vérifie les permissions Supabase.',
      );
    } catch (error, stackTrace) {
      debugPrint('[FRIENDS] Erreur inattendue : $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showMessage('Une erreur inattendue est survenue.');
    } finally {
      if (mounted) {
        setState(() {
          _processingIds.remove(requestId);
        });
      }
    }
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
            Expanded(child: _buildContent(context, theme, profiles)),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 52),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
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
                hasSearch ? 'Aucun résultat' : 'Pas encore de profils',
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
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildProfileCard(context, theme, profiles[index]);
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
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final profileId = profile['id'] as String;

    final name = (profile['full_name'] as String?)?.trim();
    final displayName = name == null || name.isEmpty ? 'Utilisateur' : name;

    final nativeLanguage = profile['native_language'] as String?;
    final learningLanguage = profile['learning_language'] as String?;

    final initials = displayName.characters.first.toUpperCase();

    final request = currentUserId == null
        ? null
        : _getRequestForProfile(profileId, currentUserId);

    final requestStatus = request?['status'] as String?;

    final isOutgoing = request != null && request['sender_id'] == currentUserId;

    final isIncoming =
        request != null && request['receiver_id'] == currentUserId;

    final requestId = request?['id'] as String?;

    final processingId = isIncoming ? requestId : profileId;
    final isProcessing =
        processingId != null && _processingIds.contains(processingId);

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
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
                  if (nativeLanguage != null && nativeLanguage.isNotEmpty)
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
                  if (learningLanguage != null && learningLanguage.isNotEmpty)
                    _buildLanguageRow(
                      icon: Icons.school_rounded,
                      label: 'Apprend : $learningLanguage',
                      color: colors,
                    ),
                  if ((nativeLanguage == null || nativeLanguage.isEmpty) &&
                      (learningLanguage == null || learningLanguage.isEmpty))
                    Text(
                      'Langues non renseignées',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 14),
                  _buildRequestActions(
                    profileId: profileId,
                    request: request,
                    requestStatus: requestStatus,
                    isOutgoing: isOutgoing,
                    isIncoming: isIncoming,
                    isProcessing: isProcessing,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestActions({
    required String profileId,
    required Map<String, dynamic>? request,
    required String? requestStatus,
    required bool isOutgoing,
    required bool isIncoming,
    required bool isProcessing,
  }) {
    if (request == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: isProcessing ? null : () => _sendFriendRequest(profileId),
          icon: isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Ajouter'),
        ),
      );
    }

    if (requestStatus == 'accepted') {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_alt_rounded, size: 19),
          SizedBox(width: 6),
          Text('Amis'),
        ],
      );
    }

    if (requestStatus == 'pending' && isOutgoing) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_top_rounded, size: 19),
          SizedBox(width: 6),
          Flexible(child: Text('Demande envoyée')),
        ],
      );
    }

    if (requestStatus == 'pending' && isIncoming) {
      final requestId = request['id'] as String;

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: isProcessing
                ? null
                : () => _respondToFriendRequest(
                    requestId: requestId,
                    status: 'accepted',
                  ),
            child: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Accepter'),
          ),
          OutlinedButton(
            onPressed: isProcessing
                ? null
                : () => _respondToFriendRequest(
                    requestId: requestId,
                    status: 'rejected',
                  ),
            child: const Text('Refuser'),
          ),
        ],
      );
    }

    if (requestStatus == 'rejected') {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined, size: 19),
          SizedBox(width: 6),
          Flexible(child: Text('Demande refusée')),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLanguageRow({
    required IconData icon,
    required String label,
    required ColorScheme color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color.onSurfaceVariant, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
