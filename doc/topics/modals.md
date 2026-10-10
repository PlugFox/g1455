Alerts, sheets, menus and popovers on glass. They are built in the navigator's
overlay, so the [GlassHost](../g1455/GlassHost-class.html) has to be **above the navigator**
(`MaterialApp.builder`) for them to see the screen they open over.

| API | What it is |
|---|---|
| [showGlassDialog](../g1455/showGlassDialog.html), [GlassAlert](../g1455/GlassAlert-class.html), [GlassAlertAction](../g1455/GlassAlertAction-class.html) | An alert that materializes over the screen: blur first, tint last. |
| [showGlassSheet](../g1455/showGlassSheet.html), [GlassSheetDetent](../g1455/GlassSheetDetent.html) | A sheet from the bottom edge that follows the finger, dragged down to close (unless it is not barrier-dismissible), and pulled up to the whole height with a large detent. |
| [GlassMenuAnchor](../g1455/GlassMenuAnchor-class.html), [GlassMenuItem](../g1455/GlassMenuItem-class.html), [GlassMenuController](../g1455/GlassMenuController-class.html) | A menu that grows out of the button that opened it. |
| [GlassPopoverAnchor](../g1455/GlassPopoverAnchor-class.html) | A panel of any content that grows out of its anchor. |

## An alert

```dart
showGlassDialog<void>(
  context: context,
  builder: (BuildContext context) => GlassAlert(
    title: const Text('Delete all notes?'),
    message: const Text('This cannot be undone.'),
    actions: <GlassAlertAction>[
      GlassAlertAction(label: 'Cancel', isDefault: true, onPressed: () => Navigator.pop(context)),
      GlassAlertAction(label: 'Delete', isDestructive: true, onPressed: () => Navigator.pop(context)),
    ],
  ),
);
```

## A sheet only its own buttons close

```dart
showGlassSheet<void>(
  context: context,
  barrierDismissible: false, // not the dim, not Escape, not a drag
  showGrabber: false,
  builder: (BuildContext context) => const SignInForm(),
);
```

## A sheet that pulls up to the whole height

```dart
showGlassSheet<void>(
  context: context,
  detents: const <GlassSheetDetent>[GlassSheetDetent.medium, GlassSheetDetent.large],
  builder: (BuildContext context) => const NotesList(),
);
```

At the large detent the sheet is its finish laid on opaquely, by default, and it
reads no backdrop: one surface fewer in the capture, and its area out of the
atlas. A change inside it is then a retake for the glass around it; a
translucent `largeFinish` keeps it glass.

## A menu

```dart
GlassMenuAnchor(
  items: <GlassMenuItem>[
    GlassMenuItem(label: 'Rename', onPressed: rename),
    GlassMenuItem(label: 'Delete', isDestructive: true, onPressed: delete),
  ],
  builder: (BuildContext context, GlassMenuController menu) =>
      GlassButton(onPressed: menu.open, child: const Icon(Icons.more_horiz)),
)
```
