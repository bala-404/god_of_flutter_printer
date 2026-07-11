import 'glyph_bitmap.dart';

/// Built-in glyph definitions used when font assets are unavailable.
///
/// These are compact dot-matrix patterns for common Tamil/Hindi characters.
/// For production quality, add Noto fonts under `assets/fonts/` and use
/// [GlyphRasterizer].
class EmbeddedGlyphCatalog {
  EmbeddedGlyphCatalog._();

  static final Map<int, GlyphBitmap> _glyphs = {
    // Tamil — வ (va)
    0x0BB5: GlyphBitmap.fromAsciiArt([
      '....#....',
      '...###...',
      '..#...#..',
      '.#.....#.',
      '...###...',
      '...#.#...',
      '..#...#..',
    ]),
    // Tamil — ண (nn)
    0x0BA3: GlyphBitmap.fromAsciiArt([
      '..#...#..',
      '.#.....#.',
      '...###...',
      '...#.#...',
      '..#...#..',
      '.#.....#.',
      '..#...#..',
    ]),
    // Tamil — க (ka)
    0x0B95: GlyphBitmap.fromAsciiArt([
      '...###...',
      '..#...#..',
      '.#.....#.',
      '.#...#...',
      '..#...#..',
      '...###...',
      '.....#...',
    ]),
    // Tamil — ம (ma)
    0x0BAE: GlyphBitmap.fromAsciiArt([
      '.#.....#.',
      '.#.....#.',
      '.#######.',
      '.#.....#.',
      '.#.....#.',
      '.#.....#.',
      '.#.....#.',
    ]),
    // Tamil — ் (virama / pulli)
    0x0BCD: GlyphBitmap.fromAsciiArt([
      '.........',
      '.........',
      '.........',
      '....#....',
      '.........',
      '.........',
      '.........',
    ]),
    // Hindi — न (na)
    0x0928: GlyphBitmap.fromAsciiArt([
      '.#######.',
      '.......#.',
      '......#..',
      '.....#...',
      '....#....',
      '...#.....',
      '..#......',
    ]),
    // Hindi — म (ma)
    0x092E: GlyphBitmap.fromAsciiArt([
      '.#.....#.',
      '.##...##.',
      '.#.#.#.#.',
      '.#..#..#.',
      '.#.....#.',
      '.#.....#.',
      '.#.....#.',
    ]),
    // Hindi — स (sa)
    0x0938: GlyphBitmap.fromAsciiArt([
      '...###...',
      '..#...#..',
      '...###...',
      '.....#...',
      '....#....',
      '...#.....',
      '..####...',
    ]),
    // Hindi — त (ta)
    0x0924: GlyphBitmap.fromAsciiArt([
      '.#######.',
      '.....#...',
      '....#....',
      '....#....',
      '....#....',
      '....#....',
      '....#....',
    ]),
    // Hindi — ् (virama / halant)
    0x094D: GlyphBitmap.fromAsciiArt([
      '.........',
      '.........',
      '....#....',
      '.........',
      '.........',
      '.........',
      '.........',
    ]),
    // Hindi — े (e vowel sign)
    0x0947: GlyphBitmap.fromAsciiArt([
      '....##...',
      '...#..#..',
      '..#....#.',
      '.#......#',
      '.........',
      '.........',
      '.........',
    ]),
    // Tamil — அ (a) sample
    0x0B85: GlyphBitmap.fromAsciiArt([
      '...###...',
      '..#...#..',
      '.#.....#.',
      '.#######.',
      '.#.....#.',
      '..#...#..',
      '...###...',
    ]),
    // Hindi — अ (a) sample
    0x0905: GlyphBitmap.fromAsciiArt([
      '...###...',
      '..#...#..',
      '.#.....#.',
      '.#.....#.',
      '.#######.',
      '.#.....#.',
      '..#...#..',
    ]),
  };

  static GlyphBitmap? find(int codePoint) => _glyphs[codePoint];

  static bool contains(int codePoint) => _glyphs.containsKey(codePoint);
}
