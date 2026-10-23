## 0.4.0 - 2026-10-24

### Breaking changes

Constructor calls build unchanged; code that reads these fields back needs
a change.

- Colour parameters are nullable, and null means iOS's colour for the
  appearance of the glass: `GlassSwitch.activeColor` and `trackColor`,
  `GlassSlider.activeColor` and `trackColor`,
  `GlassSegmentedControl.trackColor` and `thumbColor`,
  `GlassTabBar.activeColor`, `GlassTextField.cursorColor` (and
  `GlassTextField.search`), `GlassSearchBar.cancelColor` and
  `GlassBadge.color`. A colour you
  pass is drawn as before; reading one back needs a fallback (`??`).
- `GlassBar.padding`, `GlassCard.padding`, `GlassButton.padding` and
  `GlassScaffold.barMargin` are `EdgeInsetsGeometry`, resolved with the
  ambient `Directionality`, so `EdgeInsetsDirectional` mirrors under right
  to left. Code that reads them as `EdgeInsets` calls `resolve` first.
- `kGlassFieldHeight` is the field's minimum height, not its fixed height:
  see the text size changes below.

### Added

- `GlassHost.appearance`: an app whose theme does not follow the phone's
  declares the appearance it is in. Before, a dark-themed app on a phone in
  the light appearance got light `.regular` glass over its dark content.
  Unlike naming a finish, it keeps adaptive glass and the declared backdrop
  in play. A `GlassScaffold` that mounts its own host takes the defaults,
  so declare it on a host of your own.
- `GlassScaffold.resizeToAvoidBottomInset`, true by default, as
  `Scaffold`'s: the body ends at the keyboard's top and is told no bottom
  inset, so a focused field in a scroll view is scrolled into sight, and the
  floating action stands on the keyboard. The bottom bar stays under it.
  Before, the body ran under the keyboard; `false` keeps that.
- `ShadowFilter` is exported from `package:g1455/g1455.dart`, so
  `GlassHost.shadowFilter` can be given one without a `src/` import. Its
  counters (`dropped`, `picturesForwarded`, `paragraphsForwarded`) say what
  it left out of the capture and what it could not look into.
- `WalkLog` is exported from `package:g1455/glass_diagnostics.dart`: what
  the capture walk observed on a frame, read as `GlassProxyHandle.frame?.log`.
  Diagnostics only; nothing falls back to the stock capture on what it
  counts.

### Changed

- Colours on dark glass are the dark appearance's, as on iOS:
  - the default colours of the switch, slider, segmented control, a
    selected tab, a field's caret and selection, and Cancel;
  - the tab bar's resting capsule and an alert's action capsules
    (`systemFill`);
  - the destructive red in alerts and menus, and a badge's red
    (`systemRed`);
  - a sheet's grabber (`tertiaryLabel` of the sheet's appearance; it was
    1.18 : 1 against a dark sheet).
  The slider's default blue in the light appearance is the light
  `systemBlue` (`0xFF007AFF`), not the dark one.
- Large text sizes:
  - `GlassTabBar` and `GlassSegmentedControl` keep their labels at no more
    than the default text size, as UIKit does; at twice the size labels were
    cut mid-word. A screen reader still gets every label whole.
  - `GlassTextField` and `GlassSearchBar` grow with their line from 44 pt,
    keeping 11 pt above and below it, as a `UITextField` under Dynamic Type.
- A held segment's label fades from the capsule's ink to the page's as the
  capsule fades into the drop; on a dark control it was black on the dark
  track.
- A disabled `GlassSwitch` or `GlassSlider` exposes no tap or scroll action
  to a screen reader.
- The dim behind a sheet fades as the sheet is dragged down to close, and
  comes back if it is let go short of closing.

### Fixed

- Right to left:
  - `GlassTabBar` maps touches, its resting capsule and its held drop from
    the start edge: a tap selected the mirrored tab (thanks to @sb-dor).
  - A menu row's inset is at its start edge.
  - `GlassSegmentedControl` places its capsule correctly when segments are
    added or removed, and a press held while the direction flips selects
    the segment it was held over.
- Held presses:
  - `GlassSegmentedControl` and `GlassTabBar` held while their segments or
    items are added or removed end the press selecting nothing. The release
    selected the index held, which could be past the last one.
  - Disabled while held, both put their capsule back under the selected
    item, and the tab bar's drop no longer stays lifted.
- `GlassTabBar` no longer clips its held drop at device pixel ratios other
  than 2, and its accessory no longer clips its capsule's end (thanks to
  @akoflacko).
- A `GlassTabBar` rebuilt with nothing changed, by a `setState` around it,
  is no longer a capture where the bar is lifted, as in a `GlassScaffold`:
  it keeps what it built. A new `onSelected` alone is taken without a
  rebuild.
- An open `GlassMenuAnchor` or `GlassPopoverAnchor` follows its anchor when
  the anchor moves by layout alone, such as a list scrolled under it.
- The capture of glass on glass matches the engine in more cases:
  - an opacity at full alpha opens no layer, so a child that clears or
    blends reaches the page;
  - a `ShaderMask` away from the origin draws its mask from its own corner;
  - a composited image filter at an offset is applied about that offset;
  - a changed colour filter marks its whole clip dirty, so a held capture
    no longer goes stale;
  - `ShadowFilter.dropMaskFiltered` keeps vertices, atlases and
    nine-patches, which Skia and Impeller draw sharp anyway.

### Documentation

- The README, the site and the agent skill say what the shadow filter cannot
  see into (a cached `Picture`, a text's `TextStyle.shadows`), and that on
  Skia a resampling image filter samples slightly differently in the
  capture than on screen.
- "What the app declares" on the site covers `GlassHost.appearance`.

## 0.3.0 - 2026-10-19

### Changed

- Under an adaptive host, a tab bar's `bottomAccessory` wears the bar's
  verdict instead of reading its own backdrop, so the two always cross
  between the light and dark branches together.
- `GlassLedger.read` leaves glass that draws nothing out of the load: a
  control's drop at rest (`materialize` 0) is counted in the new
  `GlassLoad.restingSurfaceCount` and in none of the other counts or areas.
  Twenty resting switches no longer read as twenty captured surfaces.

### Added

- `GlassSurfaceRecord.draws` and `GlassSurfaceRecord.captured`: the one test
  the host's capture and the ledger both use.

### Fixed

- A `GlassSurface` removed under a held finger no longer asserts on the rest
  of the gesture (thanks to @melo936).
- `GlassTabBar` and `GlassSegmentedControl` removed under a held finger (a
  route popped, a list recycled the row) ignore the rest of the gesture
  instead of moving disposed animation controllers.
- A tab bar's accessory beside the collapsed circle keeps its lower rim: it
  was 2 px taller than the bar and clipped.
- A surface that replaces another at the same rect draws immediately; before,
  it drew nothing until something else on the screen changed. The same fix
  covers glass that returns to the top rung at the rects it left.
- The capture walk counts a colour filter under an `OpacityLayer` that
  arrives through `pushLayer`, and sends that subtree to the stock capture.
- `FilteringCanvas` drops a mask-filtered paint on every draw that takes a
  paint (points, images, vertices, atlases), not only on shapes.
- `GlassMenuAnchor`, `GlassPopoverAnchor` and a `GlassPageControl` with a
  `PageController` create their animation controller in `initState`, not
  for the first time in `dispose`.
- A `GlassMenuController` given to a `GlassMenuAnchor` or `GlassPopoverAnchor`
  in a rebuild drives it; taken away, the anchor's own controller takes
  over and an open panel stays open.
- A `GlassPageControl` whose `PageController` is taken away shows
  `currentPage`.
- The capture walk restores its count of open opacities when a painter
  throws inside `pushOpacity`; every later colour filter in the pass went to
  the stock capture.
- `GlassBadge`, `GlassScaffold` and `GlassTabBar` build without an ambient
  `Directionality`.

### Documentation

- The `GlassBackdropReading` example, the site and the agent skill pick a
  colour for content on glass with
  `GlassTheme.of(context).legibility().label`, not `reading.brightness`,
  which switches at a different level from the glass.
- The guide, the tab bar page and the README say the tab bar adapts as one
  control.

## 0.2.0 - 2026-10-10

### Changed

- A pressed `GlassButton` swells (`GlassPress`); `GlassPress.none` turns it
  off.
- A sheet stands on the keyboard instead of under it: 8 px above it at the
  medium detent, on it at large. Its content sees no bottom `viewInsets`.
- The switch, the slider and the segmented control take the drag from
  touch-down: inside a horizontal scrollable such as a `PageView`, a
  horizontal drag that starts on them moves the control, not the page. A
  vertical swipe still scrolls the list around them.
- The ripple shader's uniforms moved: `count`, `reach` and `light` now come
  after its arrays. Only code that writes the uniforms by hand is affected.

### Added

- `GlassBackdrop`: declare what is behind the glass in a subtree
  (`GlassBackdrop.color`, `.image`, `.texture`, `.gradient`, `.painter`), and
  the glass samples a texture made from the declaration instead of a capture
  of the screen. A screen whose glass is all declared takes no snapshot.
  `GlassBackdrop.live` hands part of the subtree back to the capture.
  Diagnostics: `RenderGlassSurface.paintsWithDeclaredBackdrop`,
  `RenderGlassGroup.paintsWithDeclaredBackdrop`,
  `RenderGlassSurface.readsDeclaredBackdrop`,
  `GlassBackdropDeclaration.renders`, `GlassSurfaceRecord.declared` and
  `GlassSurfaceRecord.readsCapture`.
- `GlassStepper`: a minus and a plus in one glass capsule, as `UIStepper`,
  with press-and-hold repeat (`kGlassStepperRepeatDelay`,
  `kGlassStepperRepeatInterval`) and `wraps`.
- `GlassPageControl`: page dots on a glass capsule, as `UIPageControl`. It
  follows and drives a `PageController`; a tap moves one page, a drag
  scrubs.
- `GlassSearchBar`: a glass search field with a clear button and a Cancel
  that slides in while it has the focus.
- `GlassBadge`: a count, a label or a dot on the corner of an icon or a tab.
- Size constants: `kGlassStepperSize`, `kGlassPageDot`, `kGlassPageDotGap`,
  `kGlassPageControlHeight`, `kGlassBadgeHeight`, `kGlassBadgeDot`.
- Sheet detents: `showGlassSheet(detents:, initialDetent:, onDetentChanged:)`
  with `GlassSheetDetent.medium` and `GlassSheetDetent.large`. A large sheet
  draws `largeFinish` (by default opaque) and, once fully up, reads no
  backdrop.
- `GlassTabBar(minimizeBehavior: GlassTabBarMinimizeBehavior.onScrollDown)`:
  the bar collapses to a circle on scroll down and expands on scroll up or a
  tap. The scroll is read by a `GlassTabBarMinimizer` (`GlassScaffold` is
  one); `notificationPredicate` and
  `GlassScaffold.minimizeNotificationPredicate` let a nested list drive it.
- `GlassTabBar.bottomAccessory`: a glass capsule
  (`kGlassTabAccessoryHeight`, 48) above the bar that moves beside the
  collapsed circle.
- `GlassPress`, declared on `GlassHost.press`, `GlassThemeData.press` or
  `GlassButton.press`.
- `GlassSlider.divisions`.
- Keyboard support: the button, switch, slider, segmented control, stepper,
  page control and toolbar cells take the focus (`focusNode`, `autofocus`);
  Space and Enter activate, the arrows step. The focus ring is
  `kGlassFocusRingColor`, `kGlassFocusRingWidth` and `kGlassFocusRingGap`.
- Right-to-left layout for the switch, slider, segmented control, toolbar,
  stepper and page control. `SliderGeometry.fillEnd` takes a
  `textDirection`.
- `GlassConcentric`: concentric corner radii as arithmetic.

### Fixed

- A dismissible sheet follows the finger (a 116 px drag moved it about
  4.5 px), closes past a third of its height or on a flick, and costs one
  capture per drag instead of 16.
- Under right to left, the segmented control's capsule sat under the wrong
  label, and `GlassButtonGroup` brightened the wrong cell.
- A sheet popped while a finger drags it no longer pops the page under it
  when the finger lifts; a drag down from large after the content or the
  window changed no longer jumps.
- `GlassSlider` sends exactly one `onChangeStart` before its changes and one
  `onChangeEnd` after, for every kind of gesture.
- A segmented control in a vertical list no longer selects a segment after
  the list scrolled away under the finger.
- `GlassButtonGroup` no longer throws, or keeps its focus ring on a missing
  cell, when the focused or held item is removed.

### Performance

- The shaders' uniforms are packed into `vec4`s (19 slots to 9 for a surface
  and a group, 24 to 12 for the ripple): 0.9–1.8 µs less raster time per
  draw on Impeller/Metal, with byte-identical pixels.

### Platforms

- The minimum is Flutter 3.47.0 (Dart 3.13.0); `sdk: ^3.13.1` had excluded
  3.47.0 by mistake. CI tests that exact version.

### Documentation

- "Misuse and common errors" in the README and on the site.
- Site pages with live demos of the new components and behaviours; a README
  pattern for a tab bar that collapses on scroll; the agent skill covers
  them all.

## 0.1.4 - 2026-10-05

### Fixed

- `showGlassSheet(barrierDismissible: false)` is a sheet only its content
  closes, as UIKit's `isModalInPresentation`: a drag or a flick closed it
  regardless of the flag. A pull now gives a little and springs back.

### Documentation

- The API reference is grouped into topics, every public name has a doc
  comment, and `dart doc` reports no unresolved reference.
- `GlassProxy` is documented in the README and on the site's Capture control
  page.
- Every measured number says where it comes from.
- An agent skill for Claude Code, Codex, Cursor, Antigravity, Gemini CLI and
  Copilot in `skills/g1455/`: `npx skills add PlugFox/g1455`. The site
  publishes it at `/.well-known/agent-skills/`, with `llms.txt` and every
  page as markdown.
- pub.dev shows the package icon first among the screenshots.

## 0.1.3 - 2026-10-04

### Fixed

- The README's images show on pub.dev again: 0.1.2 linked them by relative
  path, which pub.dev drops.

## 0.1.2 - 2026-10-04

### Breaking changes

- `GlassTabItem.icon` is nullable: code that reads `item.icon` as an
  `IconData` needs a null check.

### Added

- Adaptive glass: `GlassHost(adaptive: GlassAdaptive())` reads the captured
  backdrop under each `GlassBar`, `GlassCard` and `GlassButton`, and picks
  the light or dark branch of `.regular` and its label from it, with
  hysteresis and a tween between branches. Off by default and free when
  off. `GlassTheme.of(context).reading` hands the verdict to content on the
  glass.
- `GlassMorph`: swap the child and the glass flows to its new size, as a
  button becomes its menu (`GlassMorphMotion.fluid`, `.calm`).
- `GlassDropMotion`: the held drop of the switch, slider, segmented control
  and tab bar stretches as it sets off and squashes as it stops. Set on
  `GlassHost.dropMotion`, `GlassThemeData.dropMotion` or each control's
  `dropMotion`; `GlassDropMotion.none` turns it off.
- `GlassTabItem.iconBuilder` and `labelBuilder`, given the colour the bar
  draws the item in.
- `GlassHost.precache()` compiles the shaders before the first frame.
- `GlassScaffold`: a screen wired the recommended way: a host, a top bar in
  a soft `GlassScrollEdge`, an optional bottom bar and floating action, and
  a body that scrolls under the bars.

### Fixed

- A shader that fails to load is reported through `FlutterError` instead of
  escaping as an uncaught error, and the next load tries again.
- On the web, a painter that throws while a glass layer records no longer
  leaks shaders.

### Documentation

- The README opens with a whole-app loop, has a runnable quick start, the
  values of every `GlassFinish` preset, common patterns, and what the
  package does not do and why.

## 0.1.1 - 2026-10-04

### Added

- `GlassSwitch.semanticLabel` and `GlassSlider.semanticLabel`; a screen
  reader steps `GlassSlider` by `semanticStep`.
- `GlassButton.semanticLabel`, read in place of the child.
- `barrierLabel` on `showGlassSheet`, `GlassMenuAnchor` and
  `GlassPopoverAnchor`, so a screen reader can close them.
- `showGlassSheet(constraints:)`, as `showModalBottomSheet`.

### Changed

- The labels of `GlassButton`, `GlassSegmentedControl` and `GlassTabBar` are
  not selectable under a `SelectionArea`.

### Fixed

- Glass draws correctly on CanvasKit (Safari and every browser without
  WasmGC): shaders were released before the picture was rasterized, and it
  drew from freed memory.
- Glass standing on glass no longer shifts what is under the lower glass
  when a `CompositedTransformTarget` (such as a `SelectionArea`'s) is among
  it.
- A `GlassGroup` drawn in tiles no longer loses members on the web.
- A platform view or a `Texture` is a hole in the capture of an upper level
  instead of a grey stub.

### Documentation

- The README covers the cost of glass on the web outside Chromium and what
  to do about it.

## 0.1.0 - 2026-10-03

First release on pub.dev, as `g1455`.

### Breaking changes

- The package was `glass`: the library is now `package:g1455/g1455.dart`
  and the shader asset keys are `packages/g1455/shaders/...`.
- `GlassFinish.regular` is now `GlassFinish.regularDark` (damage-table key
  `'regularDark'`). The light branch is the new `GlassFinish.regularLight`,
  and `GlassFinish.regular(appearance:, backdrop:)` picks between them as
  Apple's material does.
- `GlassHost.finish` is optional: null picks the `.regular` branch from the
  declared `backdrop` and the platform's appearance.

### Added

- `GlassScrollEdge`: the scroll edge effect under a bar, soft or hard, top
  or bottom.
- `GlassAbove`: raises glass over the glass beside it.
- `GlassSegmentedControl`, `GlassButtonGroup`, `GlassTextField` and
  `GlassTextField.search`.
- `showGlassDialog` with `GlassAlert`, `showGlassSheet`, `GlassMenuAnchor`
  and `GlassPopoverAnchor`. A menu grows out of its anchor and shrinks back.
- `GlassSurface.fade` (`GlassFade`).
- `GlassRipple`: an optional viscous wave from the touch point, on
  `GlassHost.ripple`, `GlassThemeData.ripple` or `GlassSurface.ripple`.

### Changed

- Drops, lone panels, the alert and the menu come and go through
  `materialize`, as Apple's do, instead of `presence`.
- `showGlassDialog` and `showGlassSheet` carry the caller's
  `InheritedTheme`s to the overlay, as `showDialog` does.

### Fixed

- The slider's fill ends in a capsule, not a square cut.
- A screen whose only glass is a resting drop no longer redraws every frame.
- Glass on glass no longer re-records a still screen every frame when the
  lower glass holds content outside a `RepaintBoundary`.
- With two finishes on one screen, each blur class blurs only its own slots.
- Closing a menu over an anchor with its own semantics node no longer trips
  `!semantics.parentDataDirty`.

## 0.1.0-dev.1

Not published. The first cut, moved out of the benchmark application that
measured it.

- Shaders live under `lib/shaders/`.
- `glass_diagnostics.dart` holds the benchmark switches and the host's proxy
  handle (`debugGlassFusedSplit`, `debugGlassFoldCull`,
  `debugGlassShaderAntiAlias`, `fusedDrawTiles`, `GlassFusedTile`,
  `kMaxFusedTiles`, the shader asset keys, `GlassProxyHandle`,
  `GlassProxyScope`).
- `GlassPlatformSignals` and `GlassSignals` were removed: the package ships
  no platform code. `GlassThermalState` stays.
- `GlassSurface.labelled`, `GlassGroup.labelled` and `GlassUnion.labelled`:
  unlabelled glass is exempt from the `minLabelContrast` dim.
- `GlassButton` no longer fills the width it is offered.
- Disabled controls look disabled, as on iOS 26 (`kGlassDisabledOpacity`,
  `kGlassDisabledDarkLabel`, `kGlassDisabledLightLabel`), and a control
  disabled mid-gesture lets go.
- The host's debug check for missed repaints no longer fires on glass content
  or on a boundary that repainted nothing of its own.
