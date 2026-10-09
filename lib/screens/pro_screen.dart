import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/sultan_decor.dart';
import '../theme/backgammon_themes.dart';

/// Pro screen: Free-vs-Pro comparison, the Pro unlock, and the tip jar.
///
/// Product IDs (created by Wajiha in Play Console):
/// - `backgammonpro` — one-time non-consumable Pro unlock.
/// - `backgammoncoffee` / `backgammonchocolate` — consumable tips.
/// Until the products exist, the screen honestly says "available after
/// store setup" — never a fake buy button.
class ProScreen extends StatefulWidget {
  final SultanAudio audio;
  final SultanSettings settings;
  const ProScreen({super.key, required this.audio, required this.settings});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  final _store = StoreService();
  SultanSettings get s => widget.settings;
  SultanThemeDef get t =>
      SultanThemes.byId(s.themeId, custom: s.customTheme);

  @override
  void initState() {
    super.initState();
    // If the store already knows Pro was purchased, unlock locally.
    _store.proPurchased.addListener(_syncPro);
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _syncPro() {
    if (_store.proPurchased.value && !s.isPro) {
      s.setPro(true);
    }
  }

  @override
  void dispose() {
    _store.proPurchased.removeListener(_syncPro);
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WoodBackdrop(
        theme: t,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: t.accentLight, size: 26),
                      onPressed: () {
                        widget.audio.click();
                        Navigator.pop(context);
                      },
                    ),
                    Text('Sultan Pro',
                        style: Sultan.display(26, theme: t)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  children: [
                    _comparisonCard(),
                    const SizedBox(height: 18),
                    if (s.isPro)
                      LeatherPlaque(
                        theme: t,
                        child: Row(
                          children: [
                            Icon(Icons.workspace_premium,
                                color: t.accentLight),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Pro is unlocked — the whole divan is yours.',
                                style: Sultan.body(14, theme: t),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buySection(),
                    const SizedBox(height: 18),
                    Text('TIP JAR',
                        style: Sultan.label(12, theme: t)
                            .copyWith(letterSpacing: 2.2)),
                    const SizedBox(height: 8),
                    Text(
                      'Backgammon is free forever. Tips keep the candles lit.',
                      style: Sultan.body(13, theme: t).copyWith(
                          color:
                              t.ivory.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 10),
                    _tipSection(),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<String?>(
                      valueListenable: _store.lastThanks,
                      builder: (_, msg, _) => msg == null
                          ? const SizedBox.shrink()
                          : LeatherPlaque(
                              theme: t,
                              child: Text(msg,
                                  textAlign: TextAlign.center,
                                  style: Sultan.body(14, theme: t)),
                            ),
                    ),
                    ValueListenableBuilder<String?>(
                      valueListenable: _store.purchaseError,
                      builder: (_, err, _) => err == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding:
                                  const EdgeInsets.only(top: 8),
                              child: Text(err,
                                  textAlign: TextAlign.center,
                                  style: Sultan.body(13, theme: t)
                                      .copyWith(
                                          color: const Color(
                                              0xFFD98880))),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _comparisonCard() {
    const rows = [
      ('All 20 board themes', false, true),
      ('All 10 checker styles', false, true),
      ('All 6 dice styles', false, true),
      ('Custom theme creator', false, true),
      ('Hard Sultan AI', false, true),
      ('4 free themes', true, true),
      ('3 checker styles', true, true),
      ('2 dice styles', true, true),
      ('Easy & Medium AI', true, true),
      ('Full rules: cube, hits, bear-off', true, true),
    ];
    return LeatherPlaque(
      theme: t,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('FREE  vs  PRO',
              style: Sultan.label(15, theme: t)),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  Center(
                      child: Text('Free',
                          style: Sultan.label(12, theme: t))),
                  Center(
                      child: Text('Pro',
                          style: Sultan.label(12, theme: t))),
                ],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6),
                      child: Text(r.$1,
                          style:
                              Sultan.body(13, theme: t)),
                    ),
                    Center(child: _tick(r.$2)),
                    Center(child: _tick(r.$3)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tick(bool yes) {
    return Icon(
      yes ? Icons.check_circle : Icons.remove_circle_outline,
      size: 18,
      color: yes ? t.accentLight : t.ivory.withValues(alpha: 0.35),
    );
  }

  Widget _buySection() {
    if (!_store.available || !_store.storeReady) {
      return LeatherPlaque(
        theme: t,
        child: Text(
          _store.error ?? 'Contacting the store…',
          textAlign: TextAlign.center,
          style: Sultan.body(14, theme: t).copyWith(
              color: t.ivory.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic),
        ),
      );
    }
    final pro = _store.proProduct;
    return Column(
      children: [
        BrassButton(
          text: pro == null
              ? 'UNLOCK PRO'
              : 'UNLOCK PRO — ${pro.price}',
          theme: t,
          onTap: () {
            widget.audio.click();
            _store.buyPro();
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            widget.audio.click();
            _store.restore();
          },
          child: Text('Restore purchases',
              style: Sultan.label(13, theme: t)
                  .copyWith(color: t.ivory.withValues(alpha: 0.7))),
        ),
      ],
    );
  }

  Widget _tipSection() {
    if (!_store.available || !_store.storeReady) {
      return LeatherPlaque(
        theme: t,
        child: Text(
          _store.error ?? 'Contacting the store…',
          textAlign: TextAlign.center,
          style: Sultan.body(14, theme: t).copyWith(
              color: t.ivory.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic),
        ),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: _store.purchaseInProgress,
      builder: (_, busy, _) => Row(
        children: [
          Expanded(
              child: _tipCard(
                  _store.coffeeProduct, '☕', 'Coffee', busy)),
          const SizedBox(width: 12),
          Expanded(
              child: _tipCard(_store.chocolateProduct, '🍫',
                  'Chocolate', busy)),
        ],
      ),
    );
  }

  Widget _tipCard(
      ProductDetails? product, String emoji, String label, bool busy) {
    return GestureDetector(
      onTap: product == null || busy
          ? null
          : () {
              widget.audio.click();
              _store.buyTip(product);
            },
      child: Opacity(
        opacity: product == null || busy ? 0.5 : 1.0,
        child: LeatherPlaque(
          theme: t,
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 4),
              Text(label, style: Sultan.label(13, theme: t)),
              Text(product?.price ?? '—',
                  style: Sultan.body(13, theme: t).copyWith(
                      color: t.ivory.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}
