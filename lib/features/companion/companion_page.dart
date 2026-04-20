import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'companion_call_page.dart';
import 'companion_room_service.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({
    super.key,
    this.initialRoomCode,
    this.autoJoinFromNotification = false,
  });

  final String? initialRoomCode;
  final bool autoJoinFromNotification;

  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  final TextEditingController _joinCodeController = TextEditingController();

  bool _creatingRoom = false;
  bool _joining = false;
  bool _showCodeJoin = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRoomCode?.trim();
    if (initial != null && initial.isNotEmpty) {
      _joinCodeController.text = initial.toUpperCase();
      _showCodeJoin = true;
      if (widget.autoJoinFromNotification) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _joinWalk();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  void _showAuthConfigurationDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fix Firebase Auth (CONFIGURATION_NOT_FOUND)'),
        content: const SingleChildScrollView(
          child: Text(CompanionRoomService.authConfigurationHelp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureMediaPermissions() async {
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera and microphone access are required for the video walk.',
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _startWalk() async {
    if (!await _ensureMediaPermissions()) return;
    if (!mounted) return;

    setState(() => _creatingRoom = true);
    try {
      final code = await CompanionRoomService.createWalkRoom();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => CompanionCallPage(roomId: code, isHost: true),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (CompanionRoomService.isAuthConfigurationMissing(e)) {
          _showAuthConfigurationDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign-in failed: ${e.message ?? e.code}')),
          );
        }
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_firestoreMessage('create room', e))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not create room: $e')));
      }
    } finally {
      if (mounted) setState(() => _creatingRoom = false);
    }
  }

  Future<void> _answerOpenRequest(String roomCode) async {
    final claim = await CompanionRoomService.tryClaimOpenRequest(roomCode);
    if (!mounted) return;

    switch (claim) {
      case CompanionClaimResult.notFound:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That request is no longer available.')),
        );
        return;
      case CompanionClaimResult.taken:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Someone else already joined this walk.'),
          ),
        );
        return;
      case CompanionClaimResult.ownRequest:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That is your own walk request.')),
        );
        return;
      case CompanionClaimResult.ok:
        break;
    }

    final check = await CompanionRoomService.checkJoinable(roomCode);
    if (!mounted) return;
    switch (check) {
      case CompanionJoinCheck.notFound:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room was removed. Try another request.'),
          ),
        );
        return;
      case CompanionJoinCheck.alreadyEnded:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That walk has already ended.')),
        );
        return;
      case CompanionJoinCheck.ok:
        break;
    }

    if (!await _ensureMediaPermissions()) return;
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            CompanionCallPage(roomId: roomCode, isHost: false),
      ),
    );
  }

  Future<void> _joinWalk() async {
    final raw = _joinCodeController.text.trim();
    if (raw.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-character room code.')),
      );
      return;
    }

    final code = raw.toUpperCase();
    if (!await _ensureMediaPermissions()) return;
    if (!mounted) return;

    setState(() => _joining = true);
    try {
      final check = await CompanionRoomService.checkJoinable(code);
      if (!mounted) return;
      switch (check) {
        case CompanionJoinCheck.notFound:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No walk found with that code. Check and try again.',
              ),
            ),
          );
          return;
        case CompanionJoinCheck.alreadyEnded:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('That walk has already ended. Ask for a new code.'),
            ),
          );
          return;
        case CompanionJoinCheck.ok:
          break;
      }

      final claim = await CompanionRoomService.tryClaimOpenRequest(code);
      if (!mounted) return;
      if (claim == CompanionClaimResult.ownRequest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You started this walk — stay on the host screen.'),
          ),
        );
        return;
      }
      if (claim == CompanionClaimResult.taken) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Another companion already joined. Ask for a new walk if needed.',
            ),
          ),
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => CompanionCallPage(roomId: code, isHost: false),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (CompanionRoomService.isAuthConfigurationMissing(e)) {
          _showAuthConfigurationDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign-in failed: ${e.message ?? e.code}')),
          );
        }
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_firestoreMessage('join walk', e))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not join: $e')));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFFE7EAF2) : colorScheme.surface;
    final headingColor = isDark
        ? const Color(0xFF14213D)
        : colorScheme.onSurface;
    final bodyColor = isDark
        ? const Color(0xFF425466)
        : colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('The Companion'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 4,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.groups_2,
                        size: 32,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'The Companion',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: headingColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'One student requests a virtual walk-home. Another verified student can answer '
                    'from the list below or join with the room code. Video uses WebRTC; signaling uses Firebase.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'I need a companion',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your walk is published so helpers can see it. You still get a room code to share if you prefer.',
            style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _creatingRoom ? null : _startWalk,
            icon: _creatingRoom
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.directions_walk),
            label: Text(
              _creatingRoom ? 'Starting…' : 'Request virtual walk-home',
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'I can help — open requests',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap Answer on a request to join as their companion. First tap wins.',
            style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: CompanionRoomService.openWalkRequestsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Card(
                  color: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not load requests. Check Firestore rules and your connection.\n${snapshot.error}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final filtered =
                  docs.where((d) {
                    final host = d.data()['hostUid'] as String?;
                    if (myUid != null && host == myUid) return false;
                    return true;
                  }).toList()..sort((a, b) {
                    final ta = a.data()['createdAt'];
                    final tb = b.data()['createdAt'];
                    if (ta is Timestamp && tb is Timestamp) {
                      return tb.compareTo(ta);
                    }
                    return 0;
                  });

              if (filtered.isEmpty) {
                return Card(
                  color: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No open walk requests right now. Pull to refresh is automatic — try again soon.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: bodyColor,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: filtered.map((doc) {
                  final data = doc.data();
                  final code = (data['roomCode'] as String? ?? doc.id)
                      .toUpperCase();
                  final created = data['createdAt'];
                  final subtitle = created is Timestamp
                      ? _relativeTime(created.toDate())
                      : 'Just now';

                  return Card(
                    color: cardBg,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person_search,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: const Text('Walk request'),
                      subtitle: Text(
                        '$code · $subtitle',
                        style: TextStyle(color: bodyColor),
                      ),
                      trailing: FilledButton(
                        onPressed: () => _answerOpenRequest(code),
                        child: const Text('Answer'),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          ExpansionTile(
            initiallyExpanded: _showCodeJoin,
            onExpansionChanged: (v) => setState(() => _showCodeJoin = v),
            title: Text(
              'Join with room code',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text('If you already have a code from the walker'),
            children: [
              TextField(
                controller: _joinCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Room code',
                  hintText: 'e.g. AB3K9Z',
                  border: OutlineInputBorder(),
                ),
                maxLength: 8,
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _joining ? null : _joinWalk,
                icon: _joining
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_call),
                label: Text(_joining ? 'Joining…' : 'Join video walk'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Moments ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  static String _firestoreMessage(String action, FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'Permission denied ($action). Check Firestore rules and that sign-in is enabled.';
    }
    return 'Could not $action: ${e.message ?? e.code}';
  }
}
