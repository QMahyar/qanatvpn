import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/amnezia_values.dart';
import '../repositories/endpoints_controller.dart';
import '../repositories/ingestion/normalized_endpoint.dart';
import 'awg_config.dart';

/// AWG profile editor: 3 presets + random draw up front, the obfuscation
/// knobs behind an Advanced disclosure, live invariant validation
/// (H1∩H2=∅, S1+56≠S2, Jmax<MTU, 32B keys) shown all at once.
class AwgProfileSheet extends ConsumerStatefulWidget {
  const AwgProfileSheet({super.key});

  @override
  ConsumerState<AwgProfileSheet> createState() => _AwgProfileSheetState();
}

class _AwgProfileSheetState extends ConsumerState<AwgProfileSheet> {
  final TextEditingController _tag = TextEditingController();
  final TextEditingController _privateKey = TextEditingController();
  final TextEditingController _peerKey = TextEditingController();
  final TextEditingController _endpoint = TextEditingController();
  final TextEditingController _address = TextEditingController(
    text: '10.7.0.2/32',
  );
  final TextEditingController _mtu = TextEditingController(text: '1408');
  bool _advanced = false;
  AwgValues _values = const AwgValues();
  String _presetLabel = 'Balanced';

  @override
  void dispose() {
    _tag.dispose();
    _privateKey.dispose();
    _peerKey.dispose();
    _endpoint.dispose();
    _address.dispose();
    _mtu.dispose();
    super.dispose();
  }

  AwgConfig get _config => awgConfigForTest(
    values: _values,
    privateKey: _privateKey.text.trim(),
    peerPublicKey: _peerKey.text.trim(),
    peerEndpoint: _endpoint.text.trim(),
    addresses: _address.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    mtu: int.tryParse(_mtu.text.trim()) ?? 1408,
  );

  void _applyPreset(AwgProfile profile) {
    setState(() {
      _values = profile.presetValues;
      _presetLabel = profile.label;
    });
  }

  void _applyRandom() {
    setState(() {
      _values = generateRandom();
      _presetLabel = 'Random';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> errors = _config.validate();
    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('New AWG profile', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _field(_tag, 'Tag', 'awg-hkg-02'),
            _field(_privateKey, 'Private key (32-byte base64)', ''),
            _field(_peerKey, 'Peer public key (32-byte base64)', ''),
            _field(_endpoint, 'Peer endpoint', 'vpn.example.com:51820'),
            _field(
              _address,
              'Tunnel addresses (comma separated)',
              '10.7.0.2/32',
            ),
            _field(_mtu, 'MTU', '1408'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final profile in AwgProfile.values)
                  ChoiceChip(
                    label: Text(profile.label),
                    selected: _presetLabel == profile.label,
                    onSelected: (_) => _applyPreset(profile),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.casino, size: 18),
                  label: const Text('Random'),
                  onPressed: _applyRandom,
                ),
                ActionChip(
                  avatar: const Icon(Icons.tune, size: 18),
                  label: const Text('Custom'),
                  onPressed: () => setState(() => _advanced = !_advanced),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Advanced obfuscation'),
              subtitle: Text('current: $_presetLabel'),
              value: _advanced,
              onChanged: (bool value) => setState(() => _advanced = value),
            ),
            if (_advanced) ..._advancedFields(theme),
            if (errors.isNotEmpty)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Validation errors',
                        style: theme.textTheme.titleSmall,
                      ),
                      for (final error in errors)
                        Text(error, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _tag.text.trim().isEmpty || errors.isNotEmpty
                      ? null
                      : () async {
                          final config = _config;
                          final endpoint = WireGuardEndpoint(
                            tag: _tag.text.trim(),
                            privateKey: config.privateKey,
                            addresses: config.addresses,
                            mtu: config.mtu,
                            awg: _values,
                            peers: <WireGuardPeer>[
                              WireGuardPeer(
                                publicKey: config.peerPublicKey,
                                endpoint: config.peerEndpoint,
                                allowedIps: const <String>['0.0.0.0/0', '::/0'],
                                presharedKey: config.peerPresharedKey,
                                persistentKeepalive: config.persistentKeepalive,
                              ),
                            ],
                          );
                          await ref
                              .read(endpointsControllerProvider.notifier)
                              .saveManual(endpoint);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _advancedFields(ThemeData theme) {
    String? s(int? v) => v?.toString();
    return <Widget>[
      const Divider(),
      Text('Junk packets', style: theme.textTheme.titleSmall),
      Row(
        children: <Widget>[
          Expanded(
            child: _numField(
              'Jc',
              _values.jc?.toString() ?? '',
              (v) => setState(() => _values = _copyWith(jc: v)),
            ),
          ),
          Expanded(
            child: _numField(
              'Jmin',
              _values.jmin?.toString() ?? '',
              (v) => setState(() => _values = _copyWith(jmin: v)),
            ),
          ),
          Expanded(
            child: _numField(
              'Jmax',
              _values.jmax?.toString() ?? '',
              (v) => setState(() => _values = _copyWith(jmax: v)),
            ),
          ),
        ],
      ),
      Text('Message padding (S1+56 ≠ S2)', style: theme.textTheme.titleSmall),
      Row(
        children: <Widget>[
          Expanded(
            child: _numField(
              'S1',
              _values.s1?.toString() ?? '',
              (v) => setState(() => _values = _copyWith(s1: v)),
            ),
          ),
          Expanded(
            child: _numField(
              'S2',
              _values.s2?.toString() ?? '',
              (v) => setState(() => _values = _copyWith(s2: v)),
            ),
          ),
          Expanded(
            child: _numField(
              'S3',
              _values.s3?.toString() ?? '',
              (v) => setState(() => _values = _copyWith(s3: v)),
            ),
          ),
          Expanded(
            child: _numField(
              'S4',
              _values.s4?.toString() ?? '',
              (v) => setState(() => _values = _copyWith(s4: v)),
            ),
          ),
        ],
      ),
      Text('Magic headers (H1∩H2=∅)', style: theme.textTheme.titleSmall),
      Row(
        children: <Widget>[
          for (final (index, label) in const ['H1', 'H2', 'H3', 'H4'].indexed)
            Expanded(
              child: _numField(
                label,
                switch (index) {
                      0 => _values.h1,
                      1 => _values.h2,
                      2 => _values.h3,
                      _ => _values.h4,
                    } ??
                    '',
                (v) => setState(() {
                  final h = s(v);
                  _values = switch (index) {
                    0 => _copyWith(h1: h),
                    1 => _copyWith(h2: h),
                    2 => _copyWith(h3: h),
                    _ => _copyWith(h4: h),
                  };
                }),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ];
  }

  AwgValues _copyWith({
    int? jc,
    int? jmin,
    int? jmax,
    int? s1,
    int? s2,
    int? s3,
    int? s4,
    String? h1,
    String? h2,
    String? h3,
    String? h4,
  }) {
    return AwgValues(
      jc: jc ?? _values.jc,
      jmin: jmin ?? _values.jmin,
      jmax: jmax ?? _values.jmax,
      s1: s1 ?? _values.s1,
      s2: s2 ?? _values.s2,
      s3: s3 ?? _values.s3,
      s4: s4 ?? _values.s4,
      h1: h1 ?? _values.h1,
      h2: h2 ?? _values.h2,
      h3: h3 ?? _values.h3,
      h4: h4 ?? _values.h4,
      i1: _values.i1,
      i2: _values.i2,
      i3: _values.i3,
      i4: _values.i4,
      i5: _values.i5,
    );
  }

  Widget _numField(String label, String initial, ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6, bottom: 8),
      child: TextField(
        controller: TextEditingController(text: initial),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (String text) => onChanged(int.tryParse(text.trim())),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
