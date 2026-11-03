import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';

/// Gold Star screen: a single cosmetic badge. It changes nothing in the
/// game and nothing in the game depends on it.
class ProScreen extends StatefulWidget {
  final SultanAudio audio;
  final SultanSettings settings;
  const ProScreen({super.key, required this.audio, required this.settings});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  final _store = StoreService();

  @override
  void initState() {
    super.initState();
    _store.starOwned.addListener(_refresh);
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.starOwned.removeListener(_refresh);
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gold Star')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            const Text(
              'A Gold Star is a small cosmetic badge shown on this screen. '
              'It changes nothing in the game — just a little shine.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!_store.available || !_store.storeReady)
              Text(
                _store.error ?? 'Contacting the store…',
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic),
              )
            else if (_store.starOwned.value)
              const Column(
                children: [
                  Text('⭐', style: TextStyle(fontSize: 64)),
                  SizedBox(height: 8),
                  Text('Gold Star earned!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              )
            else
              ValueListenableBuilder<bool>(
                valueListenable: _store.purchaseInProgress,
                builder: (_, busy, child) => Column(
                  children: [
                    ElevatedButton(
                      onPressed: busy || _store.starProduct == null
                          ? null
                          : () => _store.buyStar(_store.starProduct!),
                      child: Text(
                          '⭐ Gold Star${_store.starProduct == null ? '' : ' — ${_store.starProduct!.price}'}'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _store.restore(),
                      child: const Text('Restore purchases'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ValueListenableBuilder<String?>(
              valueListenable: _store.lastThanks,
              builder: (_, msg, child) => msg == null
                  ? const SizedBox.shrink()
                  : Text(msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15)),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: _store.purchaseError,
              builder: (_, err, child) => err == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(err,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
