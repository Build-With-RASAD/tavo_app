// lib/core/animation/shaders/shader_painters.dart

import 'dart:ui' show FragmentProgram, FragmentShader;

import 'package:flutter/material.dart';

import 'shader_program_loader.dart';

/// The asset path of the gooey (metaball) shader.
const String kGooeyShaderAsset = 'lib/core/animation/shaders/gooey.frag';

/// The asset path of the liquid (refraction) shader.
const String kLiquidShaderAsset = 'lib/core/animation/shaders/liquid.frag';

/// The asset path of the aurora (gradient mesh) shader.
const String kAuroraShaderAsset = 'lib/core/animation/shaders/aurora.frag';

/// Builds the painter of a shader surface for the current frame.
typedef ShaderPainterBuilder = CustomPainter Function(
  FragmentProgram? program,
  double time,
  double progress,
);

/// Paints the gooey effect: a signed-distance blend of moving metaballs.
///
/// When [program] is `null` the painter degrades to a plain fill so the
/// surface still renders something useful.
class GooeyPainter extends CustomPainter {
  /// Creates a painter for the gooey effect.
  const GooeyPainter({
    this.program,
    this.color = const Color(0xff1B365D),
    this.accent = const Color(0xff3D5A80),
    this.time = 0.0,
    this.progress = 1.0,
  });

  /// The compiled program, or `null` when it is not available.
  final FragmentProgram? program;

  /// The colour of the plain fill used when [program] is `null`.
  final Color color;

  /// The second colour of the effect.
  final Color accent;

  /// The animation time in seconds, fed to the `iTime` uniform.
  final double time;

  /// The reveal progress, fed to the `uProgress` uniform.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final FragmentProgram? program = this.program;
    if (program == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = color);
      return;
    }
    final FragmentShader shader = program.fragmentShader();
    shader.getUniformFloat('iTime').set(time);
    shader.getUniformVec2('uSize').set(size.width, size.height);
    shader.getUniformFloat('uProgress').set(progress);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant GooeyPainter oldDelegate) =>
      oldDelegate.program != program ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent ||
      oldDelegate.time != time ||
      oldDelegate.progress != progress;
}

/// Paints the liquid effect: a refraction with an animated normal.
///
/// When [program] is `null` the painter degrades to a plain fill so the
/// surface still renders something useful.
class LiquidPainter extends CustomPainter {
  /// Creates a painter for the liquid effect.
  const LiquidPainter({
    this.program,
    this.color = const Color(0xff12315C),
    this.accent = const Color(0xff4C8BF5),
    this.time = 0.0,
    this.progress = 1.0,
  });

  /// The compiled program, or `null` when it is not available.
  final FragmentProgram? program;

  /// The colour of the plain fill used when [program] is `null`.
  final Color color;

  /// The second colour of the effect.
  final Color accent;

  /// The animation time in seconds, fed to the `iTime` uniform.
  final double time;

  /// The reveal progress, fed to the `uProgress` uniform.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final FragmentProgram? program = this.program;
    if (program == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = color);
      return;
    }
    final FragmentShader shader = program.fragmentShader();
    shader.getUniformFloat('iTime').set(time);
    shader.getUniformVec2('uSize').set(size.width, size.height);
    shader.getUniformFloat('uProgress').set(progress);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant LiquidPainter oldDelegate) =>
      oldDelegate.program != program ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent ||
      oldDelegate.time != time ||
      oldDelegate.progress != progress;
}

/// Paints the aurora effect: an animated gradient mesh.
///
/// When [program] is `null` the painter degrades to a plain fill so the
/// surface still renders something useful.
class AuroraPainter extends CustomPainter {
  /// Creates a painter for the aurora effect.
  const AuroraPainter({
    this.program,
    this.color = const Color(0xff1A1040),
    this.accent = const Color(0xff1AD98A),
    this.time = 0.0,
    this.progress = 1.0,
  });

  /// The compiled program, or `null` when it is not available.
  final FragmentProgram? program;

  /// The colour of the plain fill used when [program] is `null`.
  final Color color;

  /// The second colour of the effect.
  final Color accent;

  /// The animation time in seconds, fed to the `iTime` uniform.
  final double time;

  /// The reveal progress, fed to the `uProgress` uniform.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final FragmentProgram? program = this.program;
    if (program == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = color);
      return;
    }
    final FragmentShader shader = program.fragmentShader();
    shader.getUniformFloat('iTime').set(time);
    shader.getUniformVec2('uSize').set(size.width, size.height);
    shader.getUniformFloat('uProgress').set(progress);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant AuroraPainter oldDelegate) =>
      oldDelegate.program != program ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent ||
      oldDelegate.time != time ||
      oldDelegate.progress != progress;
}

/// Renders a fragment-shader effect on a hero surface.
///
/// The widget owns the single [AnimationController] that drives the `iTime`
/// uniform, is wrapped in a [RepaintBoundary] so the effect never repaints
/// the rest of the screen, and is muted by [TickerMode] when it sits in an
/// off-screen tab.
///
/// A shader belongs on a hero surface only: a fragment shader on every card
/// of a dashboard that refreshes every 20 seconds drops frames on mid-range
/// phones.
class ShaderSurface extends StatefulWidget {
  /// Creates a surface that renders the shader at [assetPath].
  const ShaderSurface({
    super.key,
    required this.assetPath,
    required this.painterBuilder,
    this.loader,
    this.fallbackColor = const Color(0xff1B365D),
    this.period = const Duration(seconds: 6),
  });

  /// The asset path of the compiled fragment program.
  final String assetPath;

  /// Builds the painter for the current frame.
  final ShaderPainterBuilder painterBuilder;

  /// Overrides the loader of the enclosing [ShaderProgramLoaderScope].
  final ShaderProgramLoader? loader;

  /// The colour painted while the program is not available yet.
  final Color fallbackColor;

  /// How long one loop of the effect takes.
  final Duration period;

  @override
  State<ShaderSurface> createState() => _ShaderSurfaceState();
}

class _ShaderSurfaceState extends State<ShaderSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  FragmentProgram? _program;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) {
      return;
    }
    _requested = true;
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ShaderProgramLoader loader =
        widget.loader ?? ShaderProgramLoaderScope.of(context);
    final FragmentProgram? program = await loader.load(widget.assetPath);
    if (!mounted) {
      return;
    }
    setState(() {
      _program = program;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double time = _controller.value *
              widget.period.inMilliseconds /
              Duration.millisecondsPerSecond;
          return CustomPaint(
            painter: widget.painterBuilder(_program, time, 1.0),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

/// A hero surface that renders the gooey effect.
class GooeySurface extends StatelessWidget {
  /// Creates a gooey surface.
  const GooeySurface({
    super.key,
    this.loader,
    this.color = const Color(0xff1B365D),
    this.accent = const Color(0xff3D5A80),
    this.period = const Duration(seconds: 6),
  });

  /// Overrides the loader of the enclosing [ShaderProgramLoaderScope].
  final ShaderProgramLoader? loader;

  /// The colour of the plain fill used when the program is not available.
  final Color color;

  /// The second colour of the effect.
  final Color accent;

  /// How long one loop of the effect takes.
  final Duration period;

  @override
  Widget build(BuildContext context) {
    return ShaderSurface(
      assetPath: kGooeyShaderAsset,
      loader: loader,
      fallbackColor: color,
      period: period,
      painterBuilder: (FragmentProgram? program, double time, double progress) {
        return GooeyPainter(
          program: program,
          color: color,
          accent: accent,
          time: time,
          progress: progress,
        );
      },
    );
  }
}

/// A hero surface that renders the liquid effect.
class LiquidSurface extends StatelessWidget {
  /// Creates a liquid surface.
  const LiquidSurface({
    super.key,
    this.loader,
    this.color = const Color(0xff12315C),
    this.accent = const Color(0xff4C8BF5),
    this.period = const Duration(seconds: 6),
  });

  /// Overrides the loader of the enclosing [ShaderProgramLoaderScope].
  final ShaderProgramLoader? loader;

  /// The colour of the plain fill used when the program is not available.
  final Color color;

  /// The second colour of the effect.
  final Color accent;

  /// How long one loop of the effect takes.
  final Duration period;

  @override
  Widget build(BuildContext context) {
    return ShaderSurface(
      assetPath: kLiquidShaderAsset,
      loader: loader,
      fallbackColor: color,
      period: period,
      painterBuilder: (FragmentProgram? program, double time, double progress) {
        return LiquidPainter(
          program: program,
          color: color,
          accent: accent,
          time: time,
          progress: progress,
        );
      },
    );
  }
}

/// A hero surface that renders the aurora effect.
class AuroraSurface extends StatelessWidget {
  /// Creates an aurora surface.
  const AuroraSurface({
    super.key,
    this.loader,
    this.color = const Color(0xff1A1040),
    this.accent = const Color(0xff1AD98A),
    this.period = const Duration(seconds: 6),
  });

  /// Overrides the loader of the enclosing [ShaderProgramLoaderScope].
  final ShaderProgramLoader? loader;

  /// The colour of the plain fill used when the program is not available.
  final Color color;

  /// The second colour of the effect.
  final Color accent;

  /// How long one loop of the effect takes.
  final Duration period;

  @override
  Widget build(BuildContext context) {
    return ShaderSurface(
      assetPath: kAuroraShaderAsset,
      loader: loader,
      fallbackColor: color,
      period: period,
      painterBuilder: (FragmentProgram? program, double time, double progress) {
        return AuroraPainter(
          program: program,
          color: color,
          accent: accent,
          time: time,
          progress: progress,
        );
      },
    );
  }
}
