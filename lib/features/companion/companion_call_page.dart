import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'companion_call_session.dart';

class CompanionCallPage extends StatefulWidget {
  const CompanionCallPage({
    super.key,
    required this.roomId,
    required this.isHost,
  });

  final String roomId;
  final bool isHost;

  @override
  State<CompanionCallPage> createState() => _CompanionCallPageState();
}

class _CompanionCallPageState extends State<CompanionCallPage> {
  CompanionCallSession? _session;
  bool _starting = true;
  bool _closing = false;
  String? _startError;
  RTCPeerConnectionState _pcState = RTCPeerConnectionState.RTCPeerConnectionStateNew;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final session = CompanionCallSession(
      roomId: widget.roomId,
      isHost: widget.isHost,
      onConnectionState: (s) {
        if (mounted) setState(() => _pcState = s);
      },
      onError: (msg) {
        if (!mounted || _session?.isEnded == true) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      onWalkEnded: () {
        if (!mounted) return;
        _endFromRemote();
      },
    );

    setState(() => _session = session);

    try {
      await session.start();
      if (mounted) setState(() => _starting = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _starting = false;
          _startError = 'Could not start camera or connect. Check permissions and try again.';
        });
      }
    }
  }

  Future<void> _hangUp() async {
    if (_closing) return;
    _closing = true;
    await _session?.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _endFromRemote() async {
    if (_closing) return;
    _closing = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Walk ended by the other participant.')),
    );
    await _session?.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    final s = _session;
    if (s != null && !s.isEnded) {
      s.endCall();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = _session;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.isHost ? 'Walk — Companion call' : 'Joining walk'),
            Text(
              'Room ${widget.roomId.toUpperCase()} · ${_connectionLabel(_pcState)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          if (widget.isHost)
            IconButton(
              tooltip: 'Copy room code',
              icon: const Icon(Icons.copy),
              onPressed: () async {
                final code = widget.roomId.toUpperCase();
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied $code')),
                  );
                }
              },
            ),
        ],
      ),
      body: _startError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off, size: 56, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text(_startError!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Go back')),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: Colors.black,
                            child: session != null && !_starting
                                ? RTCVideoView(
                                    session.remoteRenderer,
                                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                  )
                                : const Center(child: CircularProgressIndicator()),
                          ),
                          if (session != null && !_starting)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 110,
                                    height: 150,
                                    child: RTCVideoView(
                                      session.localRenderer,
                                      mirror: true,
                                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.isHost)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.share, color: theme.colorScheme.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Tell your companion to open this app, choose Join a walk, and enter: '
                                    '${widget.roomId.toUpperCase()}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _hangUp,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.call_end),
                        label: const Text('End walk'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  static String _connectionLabel(RTCPeerConnectionState s) {
    switch (s) {
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        return 'Starting…';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return 'Connecting…';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return 'Connected';
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return 'Disconnected';
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return 'Failed';
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return 'Closed';
    }
  }
}
