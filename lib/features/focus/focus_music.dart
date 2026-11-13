import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/focus_engine.dart';
import '../../data/focus_models.dart';
import '../../data/models.dart' show newId;
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import 'focus_kit.dart';

enum MusicKind { spotify, youtube, ytmusic, link }

MusicKind musicKindOf(String url) {
  final u = url.toLowerCase();
  if (u.startsWith('spotify:') || u.contains('spotify.com') || u.contains('spotify.link')) return MusicKind.spotify;
  if (u.contains('music.youtube.com')) return MusicKind.ytmusic;
  if (u.contains('youtube.com') || u.contains('youtu.be')) return MusicKind.youtube;
  return MusicKind.link;
}

String musicKindLabel(MusicKind k) => switch (k) {
      MusicKind.spotify => 'Spotify',
      MusicKind.youtube => 'YouTube',
      MusicKind.ytmusic => 'YouTube Music',
      MusicKind.link => 'Link',
    };

Color musicKindColor(MusicKind k) => switch (k) {
      MusicKind.spotify => const Color(0xFF1ED760),
      MusicKind.youtube => const Color(0xFFFF2D2D),
      MusicKind.ytmusic => const Color(0xFFFF4E45),
      MusicKind.link => FocusColors.muted,
    };

IconData musicKindIcon(MusicKind k) => switch (k) {
      MusicKind.spotify => CupertinoIcons.music_note_2,
      MusicKind.youtube => CupertinoIcons.play_rectangle_fill,
      MusicKind.ytmusic => CupertinoIcons.music_note,
      MusicKind.link => CupertinoIcons.link,
    };

/// A few well-known focus playlists to start with. You can remove them.
const _starters = [
  {'name': 'Deep Focus', 'url': 'https://open.spotify.com/playlist/37i9dQZF1DWZeKCadgRdKQ'},
  {'name': 'Peaceful Piano', 'url': 'https://open.spotify.com/playlist/37i9dQZF1DX4sWSpwq3LiO'},
  {'name': 'lofi hip hop radio', 'url': 'https://www.youtube.com/watch?v=jfKfPfyJRdk'},
];

/// Headphone-style media buttons for whatever app is playing (Android).
class MediaKeys {
  static const _ch = MethodChannel('life_os/media');

  static bool get available => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> _call(String m) async {
    if (!available) return false;
    try {
      return (await _ch.invokeMethod<bool>(m)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> play() => _call('play');
  static Future<bool> pause() => _call('pause');
  static Future<bool> toggle() => _call('toggle');
  static Future<bool> next() => _call('next');
  static Future<bool> previous() => _call('previous');
  static Future<bool> isPlaying() => _call('isPlaying');
}

/// Set by main() on devices.
FocusMusic? focusMusic;

/// Opens your focus music and keeps it in step with the timer:
/// it plays when focus starts and pauses on pause and during breaks.
class FocusMusic extends ChangeNotifier with WidgetsBindingObserver {
  FocusMusic(this.engine) {
    if (!engine.store.musicSeeded) {
      engine.store.musicSources = [for (final s in _starters) {'id': newId(), 'name': s['name']!, 'url': s['url']!}];
      engine.store.musicId = engine.store.musicSources.first['id'];
      engine.store.musicSeeded = true;
    }
    _sub = engine.events.listen(_onEvent);
  }

  final FocusEngine engine;
  StreamSubscription<FocusEvent>? _sub;

  /// True once you've started music from Life OS this session, so the timer
  /// never starts music you didn't ask for.
  bool active = false;
  bool playing = false;

  Map<String, String>? get current {
    final list = engine.store.musicSources;
    final id = engine.store.musicId;
    return list.where((m) => m['id'] == id).firstOrNull ?? list.firstOrNull;
  }

  void attach() => WidgetsBinding.instance.addObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (!MediaKeys.available) return;
    final p = await MediaKeys.isPlaying();
    if (p != playing) {
      playing = p;
      if (p) active = true;
      notifyListeners();
    }
  }

  /// Opens the current source in Spotify or YouTube.
  Future<bool> open([Map<String, String>? source]) async {
    final s = source ?? current;
    if (s == null) return false;
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(s['url']!), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (ok) {
      active = true;
      playing = true;
      notifyListeners();
    }
    return ok;
  }

  /// The big play button: opens the music the first time, then plays and pauses it.
  Future<void> playPause() async {
    if (!active || !MediaKeys.available) {
      await open();
      return;
    }
    playing ? await MediaKeys.pause() : await MediaKeys.play();
    playing = !playing;
    notifyListeners();
    unawaited(Future<void>.delayed(const Duration(milliseconds: 900), refresh));
  }

  Future<void> next() async {
    await MediaKeys.next();
    unawaited(Future<void>.delayed(const Duration(milliseconds: 900), refresh));
  }

  Future<void> previous() async {
    await MediaKeys.previous();
    unawaited(Future<void>.delayed(const Duration(milliseconds: 900), refresh));
  }

  void _onEvent(FocusEvent e) {
    if (!active || !engine.store.musicFollows || !MediaKeys.available) return;
    switch (e.kind) {
      case FocusEventKind.started:
        if (engine.phase == FocusPhase.focus) _set(true);
      case FocusEventKind.paused:
      case FocusEventKind.focusDone:
        _set(false);
      case FocusEventKind.breakDone:
      case FocusEventKind.skipped:
        if (engine.running && engine.phase == FocusPhase.focus) _set(true);
      case FocusEventKind.broken:
        break;
    }
  }

  Future<void> _set(bool on) async {
    on ? await MediaKeys.play() : await MediaKeys.pause();
    playing = on;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    super.dispose();
  }
}

/// The music row on the Focus screen.
class MusicCard extends StatelessWidget {
  const MusicCard({super.key});

  @override
  Widget build(BuildContext context) {
    final music = focusMusic;
    final store = FocusEngineScope.of(context).store;
    final list = store.musicSources;
    if (music == null) {
      return _shell(context, null, list.isEmpty ? null : list.first, false, store.musicFollows);
    }
    return ListenableBuilder(
      listenable: music,
      builder: (context, _) => _shell(context, music, music.current, music.playing, store.musicFollows),
    );
  }

  Widget _shell(BuildContext context, FocusMusic? music, Map<String, String>? s, bool playing, bool follows) {
    if (s == null) {
      return Pressable(
        onTap: () => showMusicSheet(context),
        scale: 0.98,
        label: 'Add focus music',
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
          decoration: BoxDecoration(color: FocusColors.panel, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: FocusColors.line)),
          child: Row(children: [
            const Icon(CupertinoIcons.music_note_2, size: 18, color: FocusColors.muted),
            const SizedBox(width: 12),
            Expanded(child: Text('Add focus music from Spotify or YouTube', style: AppText.sans(14.5, color: FocusColors.muted))),
            const Icon(AppIcons.add, size: 17, color: FocusColors.muted),
          ]),
        ),
      );
    }
    final kind = musicKindOf(s['url']!);
    final keys = MediaKeys.available && (music?.active ?? false);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(color: FocusColors.panel, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: FocusColors.line)),
      child: Row(children: [
        Expanded(
          child: Pressable(
            onTap: () => showMusicSheet(context),
            scale: 0.98,
            label: 'Focus music: ${s['name']}',
            child: Row(children: [
              _KindBadge(kind: kind, playing: playing),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['name']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(14.5, weight: FontWeight.w600, color: FocusColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                    '${musicKindLabel(kind)}${follows && MediaKeys.available ? ' · follows the timer' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(12, color: FocusColors.muted),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        if (keys) _Mini(icon: CupertinoIcons.backward_fill, label: 'Previous track', onTap: () => music!.previous()),
        _Mini(
          icon: !keys ? CupertinoIcons.arrow_up_right : (playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill),
          label: !keys ? 'Open in ${musicKindLabel(kind)}' : (playing ? 'Pause music' : 'Play music'),
          strong: true,
          onTap: () => music == null ? null : music.playPause(),
        ),
        if (keys) _Mini(icon: CupertinoIcons.forward_fill, label: 'Next track', onTap: () => music!.next()),
      ]),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, required this.playing});
  final MusicKind kind;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final color = musicKindColor(kind);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: playing ? 1 : 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(musicKindIcon(kind), size: 19, color: playing ? Colors.black : color),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.label, required this.onTap, this.strong = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Pressable(
          onTap: onTap,
          label: label,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: strong ? FocusColors.ink : FocusColors.panelHigh, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: strong ? FocusColors.ground : FocusColors.ink),
          ),
        ),
      );
}

/// Pick, add or remove focus music.
Future<void> showMusicSheet(BuildContext context) {
  return showFocusSheet<void>(context, builder: (_) => const _MusicSheet());
}

class _MusicSheet extends StatefulWidget {
  const _MusicSheet();

  @override
  State<_MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends State<_MusicSheet> {
  final _url = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  void _add() {
    final store = FocusEngineScope.read(context).store;
    final url = _url.text.trim();
    final link = RegExp(r'(https?://\S+|spotify:\S+)').firstMatch(url)?.group(0);
    if (link == null) {
      showToast(context, 'Paste a Spotify or YouTube link');
      return;
    }
    final kind = musicKindOf(link);
    final name = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : switch (kind) {
            MusicKind.spotify => link.contains('/album/') ? 'Spotify album' : (link.contains('/track/') ? 'Spotify track' : 'Spotify playlist'),
            MusicKind.youtube => link.contains('list=') ? 'YouTube playlist' : 'YouTube video',
            MusicKind.ytmusic => 'YouTube Music',
            MusicKind.link => 'Music link',
          };
    final id = newId();
    store.musicSources = [...store.musicSources, {'id': id, 'name': name, 'url': link}];
    store.musicId = id;
    _url.clear();
    _name.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final store = FocusEngineScope.of(context).store;
    final list = store.musicSources;
    final selected = focusMusic?.current?['id'] ?? store.musicId;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const FocusSheetTitle('Focus music', subtitle: 'Pick what plays while you focus. It opens in Spotify or YouTube, and Life OS keeps it in step with the timer.'),
      const SizedBox(height: 12),
      for (final s in list)
        Builder(builder: (context) {
          final kind = musicKindOf(s['url']!);
          final on = s['id'] == selected;
          return Pressable(
            onTap: () => store.musicId = s['id'],
            scale: 0.98,
            label: s['name'],
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              decoration: BoxDecoration(
                color: on ? FocusColors.panelHigh : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.s),
                border: Border.all(color: on ? FocusColors.muted : FocusColors.line),
              ),
              child: Row(children: [
                _KindBadge(kind: kind, playing: on),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['name']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(15, weight: FontWeight.w600, color: FocusColors.ink)),
                    Text(musicKindLabel(kind), style: AppText.sans(12, color: FocusColors.muted)),
                  ]),
                ),
                RoundIconButton(
                  icon: CupertinoIcons.arrow_up_right,
                  label: 'Open ${s['name']}',
                  size: 34,
                  background: FocusColors.panelHigh,
                  foreground: FocusColors.ink,
                  onTap: () {
                    store.musicId = s['id'];
                    focusMusic?.open(s);
                  },
                ),
                const SizedBox(width: 6),
                RoundIconButton(
                  icon: AppIcons.trash,
                  label: 'Remove ${s['name']}',
                  size: 34,
                  background: FocusColors.panelHigh,
                  foreground: FocusColors.muted,
                  onTap: () {
                    store.musicSources = [for (final x in list) if (x['id'] != s['id']) x];
                    if (store.musicId == s['id']) store.musicId = store.musicSources.firstOrNull?['id'];
                  },
                ),
              ]),
            ),
          );
        }),
      const FocusLabel('Add a link'),
      FocusField(controller: _url, hint: 'Paste a Spotify or YouTube link', keyboard: TextInputType.url, onSubmitted: (_) => _add()),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: FocusField(controller: _name, hint: 'Name (optional)')),
        const SizedBox(width: 8),
        SizedBox(width: 96, child: FocusButton(label: 'Add', onTap: _add, height: 50)),
      ]),
      if (MediaKeys.available) ...[
        const SizedBox(height: 10),
        FocusToggle(
          title: 'Music follows the timer',
          subtitle: 'Plays when focus starts and pauses on pause and breaks. Works with Spotify, YouTube Music and most players.',
          value: store.musicFollows,
          onChanged: (v) => store.musicFollows = v,
        ),
      ],
      const SizedBox(height: 6),
      Text(
        'Tip: the YouTube app stops in the background without Premium. Spotify and YouTube Music keep playing.',
        style: AppText.sans(12, color: FocusColors.dim, height: 1.4),
      ),
    ]);
  }
}
