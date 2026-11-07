import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../util/format.dart';

/// idle: waiting to start a set; running: set timer (blue); stopped: set just stopped,
/// time held while I enter reps etc.; resting: rest timer (orange).
enum TimerMode { idle, running, stopped, resting }

/// The big tap target. The ring fills once per minute, then starts a new lap.
class TimerCircle extends StatelessWidget {
  const TimerCircle({super.key, required this.mode, required this.seconds, required this.idleLabel, required this.onTap});

  static const size = 260.0;

  final TimerMode mode;
  final double seconds;
  final String idleLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ring = mode == TimerMode.resting ? c.warning : c.primary;
    final s = seconds < 0 ? 0.0 : seconds;
    final progress = mode == TimerMode.idle ? 0.0 : (s % 60) / 60;

    return Semantics(
      button: true,
      label: switch (mode) {
        TimerMode.idle => idleLabel,
        TimerMode.running => 'Stop set',
        TimerMode.stopped => 'Set stopped',
        TimerMode.resting => 'Start next set',
      },
      child: Center(
        child: SizedBox.square(
          dimension: size,
          child: Material(
            color: c.element,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: mode == TimerMode.stopped ? null : onTap,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: progress,
                  ringColor: ring,
                  trackColor: mode == TimerMode.idle ? c.primary : c.border,
                  showProgress: mode != TimerMode.idle,
                ),
                child: Center(child: _label(c, s)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(AppColors c, double s) {
    if (mode == TimerMode.idle) {
      return Text(idleLabel, style: TextStyle(color: c.primary, fontSize: 24, fontWeight: FontWeight.w600));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mode == TimerMode.resting)
          Text('Rest', style: TextStyle(color: c.warning, fontSize: 18, fontWeight: FontWeight.w600)),
        Text(
          formatClock(s),
          style: TextStyle(
            color: c.text,
            fontSize: 56,
            fontWeight: FontWeight.w300,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.ringColor, required this.trackColor, required this.showProgress});

  final double progress;
  final Color ringColor;
  final Color trackColor;
  final bool showProgress;

  static const stroke = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawOval(rect, track);
    if (showProgress && progress > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = ringColor;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor || old.trackColor != trackColor || old.showProgress != showProgress;
}
