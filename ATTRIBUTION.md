# Asset Attribution

## Illustrations — OpenMoji

Character, mood, and setting illustrations in `assets/story/` are from
[OpenMoji](https://openmoji.org/), the open-source emoji and icon project by
HfG Schwäbisch Gmünd.

- **License:** [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
- **Source:** https://github.com/hfg-gmuend/openmoji (`color/svg/`)
- **Retrieved:** 2026-09-10 from the `master` branch
- **Modifications:** none. Files are used as published and renamed only.

`master` is a moving branch, so the retrieval date alone does not identify the
bytes. The authoritative pin is the vendoring commit in this repository —
`423f4e8` ("feat(story): bundle OpenMoji illustrations and Fredoka/Nunito
fonts") — together with the checksums below. Anyone re-pulling these assets
should verify against them; a future refresh should prefer a tagged OpenMoji
release over `master`.

| Bundled path | Source glyph | SHA-256 |
|---|---|---|
| `assets/story/characters/knight.svg` | `1F6E1` | `d55fb5586b3c9d4fe01972242b58a13b209f0c93abd23fe9d4301b0ec5ead49a` |
| `assets/story/characters/dragon.svg` | `1F409` | `8ab58824843e8d2fb7e43675223133f12904847c59e8956708940c182bafe4f0` |
| `assets/story/characters/fox.svg` | `1F98A` | `b7fe9b1dce87c5e931d7e58ab77bcde8cc6ee7804e41005f199c3097960e225b` |
| `assets/story/characters/fairy.svg` | `1F9DA` | `ce43c50f9b05bb7458d6bd45728e5d33e20311fc9ea9cae1e29706ff9e9c34e4` |
| `assets/story/moods/funny.svg` | `1F604` | `e736c2d0cc0c72781aa4c5f4adf42f74fe99105a14713e29eeb7e1f35343784f` |
| `assets/story/moods/adventurous.svg` | `1F3D5` | `803cbbaac27c051d85e46665d9359f40c13ebc97021430681d13fd36e4e39867` |
| `assets/story/moods/spooky.svg` | `1F47B` | `023a6676ac85148b7f024a105fa72bd43057d9d42d9cf5c6bbdc9f9375dfb09d` |
| `assets/story/moods/calm.svg` | `1F60C` | `97a515ade6092b99626650004dd93565e925dfa198a5e1ee9e207f8c807d6676` |
| `assets/story/settings/forest.svg` | `1F332` | `0d03d0ea7819bf9fd22614a0623b7594d4175a986a18b386adfc6490844c48eb` |
| `assets/story/settings/ocean.svg` | `1F30A` | `ce86414cffcc35efc54fe5427a3d57c3f00acfde9d35b33d664fda483ae1c63b` |
| `assets/story/settings/city.svg` | `1F3D9` | `6f960c58da749f96f0862bff1f5bc5896dc5e2014227e949625f028af959acbe` |
| `assets/story/settings/space.svg` | `1F680` | `2403e0a305f931cf8c2ebd1a06de994c08733d0554eda8c0e52d1b8fe1be7001` |

## Typography — Google Fonts

- **Fredoka** — [SIL Open Font License 1.1](https://openfontlicense.org/).
  Source: https://github.com/google/fonts/tree/main/ofl/fredoka
- **Nunito** — [SIL Open Font License 1.1](https://openfontlicense.org/).
  Source: https://github.com/google/fonts/tree/main/ofl/nunito

Both are bundled as variable TTFs and used unmodified. Retrieved 2026-09-10
from the `main` branch, vendored in the same commit (`423f4e8`), and pinned by
checksum on the same terms as the illustrations above.

| Bundled path | SHA-256 |
|---|---|
| `assets/fonts/Fredoka.ttf` | `2ba02e68b152868aef9ba28e24b3648c7d457fe6f25c761f2c2c53fb61a73fc8` |
| `assets/fonts/Nunito.ttf` | `bb55a5ca5c2042335b3991af27c4d0705d0ef41cac6164ac737fd8f2a1e85207` |

---

All bundled assets are free to use for educational purposes, satisfying the
project SRS requirement that content be public-domain or free-to-use with
documented provenance.
