// The three things a pass over somebody else's tree may not change.
//
// The risk the proxy pass carries is that we execute foreign `paint()` methods
// outside the pipeline. These invariants are not formality: they are the condition under
// which that is allowed at all, and the first violation is what sends the
// subtree back to a plain `toImageSync`.
//
// All three are debug-only reads (`debugLayer`, `debugNeedsPaint`), which is
// why this is a headless test and not a device one. In profile the assertions
// that would explain a violation are gone, so the guard has to
// be here or nowhere.

import 'package:flutter/rendering.dart';

/// The state of a render tree and its layers at one instant.
class TreeSnapshot {
  TreeSnapshot._(this.layerOf, this.needsPaint, this.layerChildren, this.disposed);

  /// Walks the render tree from [root] and the layer tree from every layer it
  /// finds, so a layer that is only reachable through a `LayerHandle` a render
  /// object keeps privately still shows up through its parent.
  factory TreeSnapshot.of(RenderObject root) {
    final layerOf = <RenderObject, Layer?>{};
    final needsPaint = <RenderObject, bool>{};
    final layerChildren = <Layer, List<Layer>>{};
    final disposed = <Layer, bool>{};

    void visitLayer(Layer layer) {
      if (layerChildren.containsKey(layer)) {
        return;
      }
      disposed[layer] = layer.debugDisposed;
      final children = <Layer>[];
      if (layer is ContainerLayer) {
        for (Layer? c = layer.firstChild; c != null; c = c.nextSibling) {
          children.add(c);
        }
      }
      layerChildren[layer] = children;
      for (final Layer child in children) {
        visitLayer(child);
      }
    }

    void visitRender(RenderObject node) {
      final Layer? layer = node.debugLayer;
      layerOf[node] = layer;
      needsPaint[node] = node.debugNeedsPaint;
      if (layer != null) {
        visitLayer(layer);
      }
      node.visitChildren(visitRender);
    }

    visitRender(root);
    return TreeSnapshot._(layerOf, needsPaint, layerChildren, disposed);
  }

  final Map<RenderObject, Layer?> layerOf;
  final Map<RenderObject, bool> needsPaint;
  final Map<Layer, List<Layer>> layerChildren;
  final Map<Layer, bool> disposed;

  /// Differences from [before] to this snapshot, as sentences naming the node,
  /// the expected value and the observed one.
  ///
  /// Naming the observed value is the point. The capture-area check spent a
  /// fortnight reporting "one capture in eight came back at the wrong area" and
  /// took ten minutes to fix once it also printed which pass and what size.
  List<String> diffFrom(TreeSnapshot before) {
    final out = <String>[];

    for (final MapEntry<RenderObject, Layer?> e in before.layerOf.entries) {
      if (!layerOf.containsKey(e.key)) {
        out.add('${e.key.runtimeType}: left the render tree during the pass');
        continue;
      }
      final Layer? now = layerOf[e.key];
      if (!identical(now, e.value)) {
        out.add(
          '${e.key.runtimeType}.layer: was ${_id(e.value)}, is ${_id(now)} '
          '— a push* override returned something other than its oldLayer',
        );
      }
    }
    for (final RenderObject node in layerOf.keys) {
      if (!before.layerOf.containsKey(node)) {
        out.add('${node.runtimeType}: appeared in the render tree during the pass');
      }
    }

    for (final MapEntry<RenderObject, bool> e in before.needsPaint.entries) {
      final bool? now = needsPaint[e.key];
      if (now != null && now != e.value) {
        out.add(
          '${e.key.runtimeType}.debugNeedsPaint: was ${e.value}, is $now '
          '— the pass ${e.value ? 'cleared' : 'set'} a pipeline flag',
        );
      }
    }

    for (final MapEntry<Layer, List<Layer>> e in before.layerChildren.entries) {
      final List<Layer>? now = layerChildren[e.key];
      if (now == null) {
        // Not a violation on its own: a layer can leave the tree because its
        // owner left it. It is one when the owner is still there, which the
        // render-object checks above already report.
        continue;
      }
      if (now.length != e.value.length) {
        out.add(
          '${e.key.runtimeType} children: was ${e.value.length}, is ${now.length} '
          '— pushLayer stripped a retained subtree',
        );
        continue;
      }
      for (var i = 0; i < now.length; i++) {
        if (!identical(now[i], e.value[i])) {
          out.add(
            '${e.key.runtimeType} child $i: was ${_id(e.value[i])}, is ${_id(now[i])}',
          );
        }
      }
    }

    for (final MapEntry<Layer, bool> e in before.disposed.entries) {
      final bool now = disposed[e.key] ?? e.key.debugDisposed;
      if (now && !e.value) {
        out.add('${e.key.runtimeType}: disposed during the pass');
      }
    }

    return out;
  }

  static String _id(Layer? layer) => layer == null ? 'null' : '${layer.runtimeType}#${identityHashCode(layer)}';
}
