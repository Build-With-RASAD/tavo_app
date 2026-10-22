// lib/core/animation/shaders/shader_program_loader.dart

import 'dart:ui' show FragmentProgram;

import 'package:flutter/widgets.dart';

/// Loads the compiled fragment programs used by the shader surfaces.
///
/// The loader is an interface on purpose: a widget test can inject a loader
/// that returns `null` and never needs a GPU context, a real program or the
/// `shaders:` block of `pubspec.yaml`.
abstract class ShaderProgramLoader {
  /// Creates a loader.
  const ShaderProgramLoader();

  /// Loads the program stored at [assetPath].
  ///
  /// Returns `null` when the program is not available — the shader surfaces
  /// fall back to a plain fill instead of crashing.
  Future<FragmentProgram?> load(String assetPath);
}

/// Loads fragment programs from the app's asset bundle.
class AssetShaderProgramLoader extends ShaderProgramLoader {
  /// Creates a loader that reads from the asset bundle.
  const AssetShaderProgramLoader();

  @override
  Future<FragmentProgram?> load(String assetPath) async {
    try {
      return await FragmentProgram.fromAsset(assetPath);
    } on Object {
      // The program is not bundled (or the platform cannot compile it):
      // the surface degrades to its plain fill.
      return null;
    }
  }
}

/// Provides a [ShaderProgramLoader] to a subtree.
///
/// Wrap a surface in this scope to inject a loader — a fake one in a test,
/// the asset bundle one in the app.
class ShaderProgramLoaderScope extends InheritedWidget {
  /// Creates a scope that hands [loader] to the shader surfaces below it.
  const ShaderProgramLoaderScope({
    super.key,
    required this.loader,
    required super.child,
  });

  /// The loader handed to the shader surfaces below this scope.
  final ShaderProgramLoader loader;

  /// The loader of the closest [ShaderProgramLoaderScope], or the asset
  /// bundle loader when there is none.
  static ShaderProgramLoader of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ShaderProgramLoaderScope>()
            ?.loader ??
        const AssetShaderProgramLoader();
  }

  @override
  bool updateShouldNotify(ShaderProgramLoaderScope oldWidget) =>
      oldWidget.loader != loader;
}
