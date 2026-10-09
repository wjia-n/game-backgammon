import 'package:flutter/material.dart';

/// Theme, checker-style and dice-style catalog for Backgammon.
///
/// Every theme stays inside the Tavla Sultani material world (deep walnut,
/// aged brass, mother-of-pearl, tan leather) — the variety comes from
/// different woods, metal accents, felt linings and checker materials.
/// No neon, no cyberpunk, nothing synthetic.
class SultanThemeDef {
  final String id;
  final String name;
  final Color woodDark; // table / board frame
  final Color woodMid;
  final Color woodDeep; // vignette
  final Color accent; // aged brass
  final Color accentLight;
  final Color accentDark;
  final Color ivory; // text on dark
  final Color felt; // board bed
  final Color pointLight;
  final Color pointDark;
  final Color checkerWhite;
  final Color checkerBlack;

  const SultanThemeDef({
    required this.id,
    required this.name,
    required this.woodDark,
    required this.woodMid,
    required this.woodDeep,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.ivory,
    required this.felt,
    required this.pointLight,
    required this.pointDark,
    required this.checkerWhite,
    required this.checkerBlack,
  });
}

class SultanThemes {
  /// First 4 are the FREE starter themes. The rest are PRO (plus 'custom').
  static const List<String> freeThemeIds = [
    'walnut',
    'ebony',
    'mahogany',
    'emerald',
  ];

  static const List<SultanThemeDef> all = [
    SultanThemeDef(
      id: 'walnut',
      name: 'Sultan Walnut',
      woodDark: Color(0xFF3B2417),
      woodMid: Color(0xFF5C3A21),
      woodDeep: Color(0xFF1A0F08),
      accent: Color(0xFFB08D3E),
      accentLight: Color(0xFFD9B96A),
      accentDark: Color(0xFF7A6128),
      ivory: Color(0xFFEDE4D3),
      felt: Color(0xFF2E4030),
      pointLight: Color(0xFFE8D9B8),
      pointDark: Color(0xFF7A4A2E),
      checkerWhite: Color(0xFFEDE4D3),
      checkerBlack: Color(0xFF3A2418),
    ),
    SultanThemeDef(
      id: 'ebony',
      name: 'Ebony Night',
      woodDark: Color(0xFF1C1A18),
      woodMid: Color(0xFF2E2A26),
      woodDeep: Color(0xFF0B0A09),
      accent: Color(0xFFC0C6D4),
      accentLight: Color(0xFFE8ECF5),
      accentDark: Color(0xFF7E8698),
      ivory: Color(0xFFF2EEE4),
      felt: Color(0xFF232326),
      pointLight: Color(0xFFE4DCC8),
      pointDark: Color(0xFF5E4A36),
      checkerWhite: Color(0xFFF2EEE4),
      checkerBlack: Color(0xFF17130F),
    ),
    SultanThemeDef(
      id: 'mahogany',
      name: 'Mahogany Court',
      woodDark: Color(0xFF4A1F14),
      woodMid: Color(0xFF6E2F1C),
      woodDeep: Color(0xFF200C06),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF3DC8E),
      accentDark: Color(0xFF96702A),
      ivory: Color(0xFFF8F1E2),
      felt: Color(0xFF3D2430),
      pointLight: Color(0xFFF0DFC0),
      pointDark: Color(0xFF8A4A2E),
      checkerWhite: Color(0xFFF8F1E2),
      checkerBlack: Color(0xFF3F1D16),
    ),
    SultanThemeDef(
      id: 'emerald',
      name: 'Emerald Divan',
      woodDark: Color(0xFF2E3B22),
      woodMid: Color(0xFF4A5A34),
      woodDeep: Color(0xFF141B0D),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF1E4D3B),
      pointLight: Color(0xFFEFE0BE),
      pointDark: Color(0xFF6E4A2E),
      checkerWhite: Color(0xFFF5EFE0),
      checkerBlack: Color(0xFF2E3B22),
    ),
    SultanThemeDef(
      id: 'ivorygold',
      name: 'Ivory & Gold',
      woodDark: Color(0xFFEFE3C8),
      woodMid: Color(0xFFE2D0A6),
      woodDeep: Color(0xFFB89F6E),
      accent: Color(0xFF9A7B1E),
      accentLight: Color(0xFFD4AF37),
      accentDark: Color(0xFF6E5514),
      ivory: Color(0xFF2E2118),
      felt: Color(0xFF2E5A44),
      pointLight: Color(0xFFFBF6E9),
      pointDark: Color(0xFF8A5A2E),
      checkerWhite: Color(0xFF2E2118),
      checkerBlack: Color(0xFF7A2E1E),
    ),
    SultanThemeDef(
      id: 'cherry',
      name: 'Cherry Harem',
      woodDark: Color(0xFF5A2A1A),
      woodMid: Color(0xFF7C3F24),
      woodDeep: Color(0xFF2A0F06),
      accent: Color(0xFFB08D3E),
      accentLight: Color(0xFFDFC084),
      accentDark: Color(0xFF7A6128),
      ivory: Color(0xFFF7EFE0),
      felt: Color(0xFF4A2E3F),
      pointLight: Color(0xFFF0E4C8),
      pointDark: Color(0xFF7C3F24),
      checkerWhite: Color(0xFFF7EFE0),
      checkerBlack: Color(0xFF4A2418),
    ),
    SultanThemeDef(
      id: 'copper',
      name: 'Copper Bazaar',
      woodDark: Color(0xFF3B2416),
      woodMid: Color(0xFF5C3A21),
      woodDeep: Color(0xFF1A0F08),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE09E5A),
      accentDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF3F2B1F),
      pointLight: Color(0xFFEFE0BC),
      pointDark: Color(0xFF6E3F26),
      checkerWhite: Color(0xFFF5EFE0),
      checkerBlack: Color(0xFF332016),
    ),
    SultanThemeDef(
      id: 'midnight',
      name: 'Midnight Caravan',
      woodDark: Color(0xFF1C2438),
      woodMid: Color(0xFF2C3A55),
      woodDeep: Color(0xFF0C1120),
      accent: Color(0xFFC0C6D4),
      accentLight: Color(0xFFE8ECF5),
      accentDark: Color(0xFF7E8698),
      ivory: Color(0xFFF2EEE4),
      felt: Color(0xFF1B2A4A),
      pointLight: Color(0xFFE9E4D2),
      pointDark: Color(0xFF4A3A5E),
      checkerWhite: Color(0xFFF2EEE4),
      checkerBlack: Color(0xFF1C2438),
    ),
    SultanThemeDef(
      id: 'rosewood',
      name: 'Rosewood',
      woodDark: Color(0xFF3F1D24),
      woodMid: Color(0xFF5E2C36),
      woodDeep: Color(0xFF1E0C12),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE09E5A),
      accentDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF4A2430),
      pointLight: Color(0xFFEFE0C6),
      pointDark: Color(0xFF6E3428),
      checkerWhite: Color(0xFFF5EFE0),
      checkerBlack: Color(0xFF3F1D24),
    ),
    SultanThemeDef(
      id: 'teal',
      name: 'Teal Atelier',
      woodDark: Color(0xFF1E3A38),
      woodMid: Color(0xFF2E5654),
      woodDeep: Color(0xFF0D1C1B),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF0EDE2),
      felt: Color(0xFF0F3D3A),
      pointLight: Color(0xFFEAE4CC),
      pointDark: Color(0xFF4A5E3A),
      checkerWhite: Color(0xFFF0EDE2),
      checkerBlack: Color(0xFF1E3A38),
    ),
    SultanThemeDef(
      id: 'burgundy',
      name: 'Burgundy Velvet',
      woodDark: Color(0xFF3A1A2E),
      woodMid: Color(0xFF552842),
      woodDeep: Color(0xFF1C0B16),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF3DC8E),
      accentDark: Color(0xFF96702A),
      ivory: Color(0xFFF8F1E2),
      felt: Color(0xFF4A1A38),
      pointLight: Color(0xFFF0E2CE),
      pointDark: Color(0xFF6E3A4A),
      checkerWhite: Color(0xFFF8F1E2),
      checkerBlack: Color(0xFF3A1A2E),
    ),
    SultanThemeDef(
      id: 'sandalwood',
      name: 'Sandalwood',
      woodDark: Color(0xFF8A6A42),
      woodMid: Color(0xFFAA8757),
      woodDeep: Color(0xFF4A3620),
      accent: Color(0xFF7A5A2E),
      accentLight: Color(0xFFC49A5A),
      accentDark: Color(0xFF54401E),
      ivory: Color(0xFF2E2118),
      felt: Color(0xFF5A6E3A),
      pointLight: Color(0xFFF8ECD2),
      pointDark: Color(0xFF8A5A2E),
      checkerWhite: Color(0xFF2E2118),
      checkerBlack: Color(0xFF6E2C14),
    ),
    SultanThemeDef(
      id: 'slate',
      name: 'Slate & Brass',
      woodDark: Color(0xFF2E3440),
      woodMid: Color(0xFF434C5E),
      woodDeep: Color(0xFF14171D),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFECEFF4),
      felt: Color(0xFF3B4252),
      pointLight: Color(0xFFE5E9F0),
      pointDark: Color(0xFF5E4A3A),
      checkerWhite: Color(0xFFECEFF4),
      checkerBlack: Color(0xFF2E3440),
    ),
    SultanThemeDef(
      id: 'honeymaple',
      name: 'Honey Maple',
      woodDark: Color(0xFF9A6E34),
      woodMid: Color(0xFFB8894A),
      woodDeep: Color(0xFF54401E),
      accent: Color(0xFF6E4A1E),
      accentLight: Color(0xFFB98A4A),
      accentDark: Color(0xFF4A3012),
      ivory: Color(0xFF2E2118),
      felt: Color(0xFF6E7E3A),
      pointLight: Color(0xFFFAEED4),
      pointDark: Color(0xFF8A5A2E),
      checkerWhite: Color(0xFF2E2118),
      checkerBlack: Color(0xFF5E2E14),
    ),
    SultanThemeDef(
      id: 'winecellar',
      name: 'Wine Cellar',
      woodDark: Color(0xFF2E1A2E),
      woodMid: Color(0xFF462844),
      woodDeep: Color(0xFF140B14),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF3E1E3E),
      pointLight: Color(0xFFEFE2CE),
      pointDark: Color(0xFF5E3A5E),
      checkerWhite: Color(0xFFF5EFE0),
      checkerBlack: Color(0xFF2E1A2E),
    ),
    SultanThemeDef(
      id: 'olive',
      name: 'Olive Grove',
      woodDark: Color(0xFF3F4226),
      woodMid: Color(0xFF5E6238),
      woodDeep: Color(0xFF1E2012),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF1EAD8),
      felt: Color(0xFF4A5228),
      pointLight: Color(0xFFEDE4C6),
      pointDark: Color(0xFF6E5A2E),
      checkerWhite: Color(0xFFF1EAD8),
      checkerBlack: Color(0xFF3F4226),
    ),
    SultanThemeDef(
      id: 'porcelain',
      name: 'Porcelain Parlor',
      woodDark: Color(0xFFE8E0D0),
      woodMid: Color(0xFFF2EAD8),
      woodDeep: Color(0xFFBFAE8A),
      accent: Color(0xFF2E5A88),
      accentLight: Color(0xFF5E8AC0),
      accentDark: Color(0xFF1E3A5C),
      ivory: Color(0xFF2A2118),
      felt: Color(0xFFDCE8F0),
      pointLight: Color(0xFFFFFFFF),
      pointDark: Color(0xFF7A8A9A),
      checkerWhite: Color(0xFF2A2118),
      checkerBlack: Color(0xFF8A1E1E),
    ),
    SultanThemeDef(
      id: 'charcoal',
      name: 'Charcoal Club',
      woodDark: Color(0xFF242424),
      woodMid: Color(0xFF383838),
      woodDeep: Color(0xFF0E0E0E),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE09E5A),
      accentDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF0EBE0),
      felt: Color(0xFF33302A),
      pointLight: Color(0xFFE8E0D0),
      pointDark: Color(0xFF5E4A36),
      checkerWhite: Color(0xFFF0EBE0),
      checkerBlack: Color(0xFF1E1A16),
    ),
    SultanThemeDef(
      id: 'topkapi',
      name: 'Topkapi Gold',
      woodDark: Color(0xFF2A1A10),
      woodMid: Color(0xFF4A2E18),
      woodDeep: Color(0xFF120A05),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFFFE9A8),
      accentDark: Color(0xFF96702A),
      ivory: Color(0xFFF8F1E2),
      felt: Color(0xFF1E3A5F),
      pointLight: Color(0xFFF0DFC0),
      pointDark: Color(0xFF2E5A88),
      checkerWhite: Color(0xFFF8F1E2),
      checkerBlack: Color(0xFF2A1A10),
    ),
    SultanThemeDef(
      id: 'sahara',
      name: 'Sahara Dune',
      woodDark: Color(0xFF6E4A2A),
      woodMid: Color(0xFF8A5E36),
      woodDeep: Color(0xFF3A2412),
      accent: Color(0xFFB08D3E),
      accentLight: Color(0xFFDFC084),
      accentDark: Color(0xFF7A6128),
      ivory: Color(0xFF2E2118),
      felt: Color(0xFF8A6A3A),
      pointLight: Color(0xFFF5E8C8),
      pointDark: Color(0xFF6E4A2A),
      checkerWhite: Color(0xFF2E2118),
      checkerBlack: Color(0xFF7A2E1E),
    ),
  ];

  static SultanThemeDef byId(String id, {SultanThemeDef? custom}) {
    if (id == 'custom') return custom ?? all.first;
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }

  static bool isProTheme(String id) =>
      !freeThemeIds.contains(id) && id != 'custom';
}

/// Checker piece styles. 0-2 = FREE, 3+ = PRO.
class CheckerStyles {
  static const int count = 10;
  static const names = [
    'Sultan Disc',
    'Pearl Ring',
    'Brass Rim',
    'Engraved Star',
    'Domed Jewel',
    'Hex Token',
    'Minted Coin',
    'Rose Carve',
    'Onyx Dome',
    'Mother Pearl',
  ];
  static const descriptions = [
    'Turned ivory disc, beveled edge',
    'Pearl ring inlaid in the face',
    'Dark wood disc with brass rim',
    'Eight-point star engraved center',
    'Domed cabochon jewel finish',
    'Six-sided turned token',
    'Minted coin with reeded edge',
    'Carved rose medallion',
    'Black onyx dome, silver ring',
    'Full mother-of-pearl face',
  ];
  static const freeCount = 3;
  static bool isPro(int index) => index >= freeCount;
}

/// Dice styles. 0-1 = FREE, 2+ = PRO.
class DiceStyles {
  static const int count = 6;
  static const names = [
    'Ivory Classic',
    'Brass Noble',
    'Oak',
    'Marble Vein',
    'Obsidian',
    'Rose Copper',
  ];
  static const descriptions = [
    'Cold-cast ivory, engraved pips',
    'Dark bronze die, brass pips',
    'Oiled oak die, burned pips',
    'White marble, slate veins',
    'Black glass, silver pips',
    'Rose copper, dark pips',
  ];
  /// [face, pip] colors per style.
  static List<List<Color>> colors(SultanThemeDef t) => [
        [const Color(0xFFF5EFE0), const Color(0xFF2E2118)], // ivory
        [const Color(0xFF4A3A22), t.accentLight], // brass noble
        [const Color(0xFF8A5E36), const Color(0xFF2E1A10)], // oak
        [const Color(0xFFF0EDE8), const Color(0xFF3A4A5E)], // marble
        [const Color(0xFF1E1E24), const Color(0xFFC0C6D4)], // obsidian
        [const Color(0xFFB87333), const Color(0xFF3A1E10)], // rose copper
      ];
  static const freeCount = 2;
  static bool isPro(int index) => index >= freeCount;
}

/// Board point (triangle) styles.
class PointStyles {
  static const names = ['Classic', 'Inlaid', 'Pearl'];
  static const descriptions = [
    'Rosewood triangles',
    'Triangles with brass border inlay',
    'Mother-of-pearl triangles',
  ];
}
