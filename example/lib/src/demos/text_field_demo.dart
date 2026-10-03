import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';

/// A search field filtering a few places over a photograph, and a plain field
/// under it; what was submitted is read out underneath.
class TextFieldDemo extends StatefulWidget {
  const TextFieldDemo({super.key});

  @override
  State<TextFieldDemo> createState() => _TextFieldDemoState();
}

const List<String> _kPlaces = <String>[
  'Lisbon',
  'Porto',
  'Kyoto',
  'Reykjavík',
  'Lima',
  'Oslo',
  'Tbilisi',
  'Bergen',
];

class _TextFieldDemoState extends State<TextFieldDemo> {
  final TextEditingController _query = TextEditingController();
  String _submitted = 'nothing yet';
  String _finish = 'Theme';
  bool _clearButton = true;
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(_changed);
  }

  @override
  void dispose() {
    _query
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  GlassFinish? get _glass => switch (_finish) {
    'Clear' => GlassFinish.clear,
    'Frosted' => GlassFinish.frosted,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final String q = _query.text.trim().toLowerCase();
    final List<String> matches = _kPlaces.where((String p) => p.toLowerCase().contains(q)).toList();
    return DemoStage(
      height: 340,
      background: const PhotoBackdrop(seed: 11),
      knobs: <Widget>[
        KnobChoice<String>(
          label: 'Finish',
          values: const <String>['Theme', 'Clear', 'Frosted'],
          selected: _finish,
          onChanged: (String v) => setState(() => _finish = v),
        ),
        KnobSwitch(label: 'Clear button', value: _clearButton, onChanged: (bool v) => setState(() => _clearButton = v)),
        KnobSwitch(label: 'Password', value: _obscure, onChanged: (bool v) => setState(() => _obscure = v)),
      ],
      hint: 'Type in the search field to filter the places, then press Enter. Typing costs no capture.',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                GlassTextField.search(
                  controller: _query,
                  finish: _glass,
                  placeholder: 'Search places',
                  onSubmitted: (String v) => setState(() => _submitted = 'search "$v"'),
                  trailing: _clearButton && _query.text.isNotEmpty
                      ? Semantics(
                          button: true,
                          label: 'Clear',
                          child: GestureDetector(onTap: _query.clear, child: const Icon(Icons.cancel)),
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 76,
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        if (matches.isEmpty) const _Chip('No places match'),
                        for (final String p in matches) _Chip(p),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GlassTextField(
                  // A new field when the kind changes, so the keyboard follows.
                  key: ValueKey<bool>(_obscure),
                  finish: _glass,
                  placeholder: _obscure ? 'Password' : 'Add a caption',
                  leading: Icon(_obscure ? Icons.lock_outline : Icons.edit_outlined),
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (String v) =>
                      setState(() => _submitted = _obscure ? 'a password of ${v.length} characters' : 'caption "$v"'),
                ),
                const SizedBox(height: 14),
                Center(child: _Chip('Submitted: $_submitted', strong: true)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain content, not glass: a label on a dark pill.
class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      shape: const StadiumBorder(),
      color: strong ? const Color(0x99000000) : const Color(0x55000000),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: strong ? FontWeight.w600 : FontWeight.w400),
      ),
    ),
  );
}
