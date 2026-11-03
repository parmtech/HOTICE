import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'inspiration_catalog.dart';

/// Deliberately user-started preview. Building a card never initializes a
/// decoder or downloads media; the native preview is a bundled H.264 asset.
class MotionStudyPreviewButton extends StatelessWidget {
  const MotionStudyPreviewButton({super.key, required this.template});

  final InspirationTemplate template;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play ${template.title} concept preview. Not AI output.',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            barrierColor: Colors.black,
            builder: (_) => MotionStudyPlaybackDialog(template: template),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'web/public${template.previewUrl!.replaceFirst(RegExp(r'\.webm$'), '.png')}',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF151822),
                    child: Center(child: Icon(Icons.movie_outlined, size: 40)),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x99000000)],
                    ),
                  ),
                ),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(13),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: Text(
                    'Play concept preview · not AI output',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
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

class MotionStudyPlaybackDialog extends StatefulWidget {
  const MotionStudyPlaybackDialog({super.key, required this.template});

  final InspirationTemplate template;

  @override
  State<MotionStudyPlaybackDialog> createState() =>
      _MotionStudyPlaybackDialogState();
}

class _MotionStudyPlaybackDialogState extends State<MotionStudyPlaybackDialog>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (_controller?.value.isPlaying ?? false)) {
      unawaited(_controller?.pause());
    }
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.asset(
      widget.template.nativePreviewAsset,
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      if (!mounted) {
        if (identical(_controller, controller)) {
          _controller = null;
          await controller.dispose();
        }
        return;
      }
      setState(() {
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (identical(_controller, controller)) {
        _controller = null;
        await controller.dispose();
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _retry() async {
    final old = _controller;
    _controller = null;
    if (old != null) await old.dispose();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    await _initialize();
  }

  Future<void> _togglePlayback(VideoPlayerController controller) async {
    if (controller.value.isPlaying) {
      await controller.pause();
      return;
    }
    if (controller.value.duration > Duration.zero &&
        controller.value.position >= controller.value.duration) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF101116),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.template.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
                IconButton(
                  tooltip: 'Close preview',
                  onPressed: () => Navigator.of(context).maybePop(),
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: controller?.value.isInitialized == true
                        ? controller!.value.aspectRatio
                        : 16 / 9,
                    child: _buildVideo(controller),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Silent concept visual · original HOTICE study · not AI output',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            if (controller?.value.isInitialized == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller!,
                  builder: (context, value, _) => Column(
                    children: [
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: Theme.of(context).colorScheme.primary,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          IconButton(
                            tooltip: value.isPlaying
                                ? 'Pause preview'
                                : 'Play preview',
                            onPressed: () =>
                                unawaited(_togglePlayback(controller)),
                            color: Colors.white,
                            icon: Icon(
                              value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                          Text(
                            '${_time(value.position)} / ${_time(value.duration)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.volume_off,
                            color: Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Silent',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo(VideoPlayerController? controller) {
    if (_loading) {
      return const ColoredBox(
        color: Color(0xFF151822),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_failed || controller == null || !controller.value.isInitialized) {
      return ColoredBox(
        color: const Color(0xFF151822),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This preview could not be played.',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => unawaited(_retry()),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry preview'),
              ),
            ],
          ),
        ),
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.hasError) {
          return ColoredBox(
            color: const Color(0xFF151822),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => unawaited(_retry()),
                icon: const Icon(Icons.refresh),
                label: const Text('Preview failed · retry'),
              ),
            ),
          );
        }
        return ColoredBox(
          color: Colors.black,
          child: Center(child: VideoPlayer(controller)),
        );
      },
    );
  }

  static String _time(Duration duration) {
    final seconds = duration.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
