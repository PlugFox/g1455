import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../widgets/stage.dart';
import '../widgets/site_icon.dart';

/// Glass cards scrolling under a glass bar, with the bar's [GlassAbove] on a
/// switch: without it the bar shows the page with the cards cut out.
class AboveDemo extends StatefulWidget {
  const AboveDemo({super.key});

  @override
  State<AboveDemo> createState() => _AboveDemoState();
}

const List<(IconData, String, String)> _kMail = <(IconData, String, String)>[
  (SFIcons.sf_airplane_departure, 'Boarding pass', 'Gate B12 · 07:40'),
  (SFIcons.sf_text_page, 'Your receipt', 'Order 4471 is on its way'),
  (SFIcons.sf_calendar, 'Design review', 'Thursday, 15:00'),
  (SFIcons.sf_photo, 'Shared album', '24 new photos from Lisbon'),
  (SFIcons.sf_music_note, 'New release', 'An album you might like'),
  (SFIcons.sf_truck_box, 'Delivered', 'Left at the front door'),
  (SFIcons.sf_heart_fill, 'Reminder', 'Water the plants'),
  (SFIcons.sf_creditcard, 'Payment received', 'From Alex · Dinner'),
];

class _AboveDemoState extends State<AboveDemo> {
  bool _above = true;

  @override
  Widget build(BuildContext context) {
    final Widget bar = GlassBar(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: <Widget>[
          const SiteIcon(SFIcons.sf_tray, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Inbox', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          Text(_above ? 'lifted' : 'not lifted', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
    return DemoStage(
      height: 380,
      knobs: <Widget>[
        KnobSwitch(label: 'GlassAbove on the bar', value: _above, onChanged: (bool v) => setState(() => _above = v)),
      ],
      hint: 'Scroll the cards under the bar. Without GlassAbove the bar refracts the page with the cards cut out.',
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 84, 16, 24),
              itemCount: _kMail.length,
              itemBuilder: (BuildContext context, int i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _card(_kMail[i]),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: _above ? GlassAbove(child: bar) : bar,
          ),
        ],
      ),
    );
  }

  Widget _card((IconData, String, String) mail) {
    final (IconData icon, String title, String line) = mail;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: <Widget>[
          SiteIcon(icon, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
