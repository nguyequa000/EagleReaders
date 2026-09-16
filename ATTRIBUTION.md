# Asset Attribution

## Illustrations — OpenMoji

Mood and setting illustrations in `assets/story/` are from
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

**The checksums below are taken over LF bytes.** This repository sets
`core.autocrlf=true` and ships no `.gitattributes`, so a Windows checkout writes
these SVGs to disk with CRLF line endings and hashing them as-is will not match.
Normalise before verifying:

```sh
tr -d '\r' < assets/story/moods/funny.svg | sha256sum
```

Adding a `.gitattributes` marking `*.svg` and `*.ttf` as `-text` would remove the
need for that step, at the cost of showing every already-committed asset as
modified once.

| Bundled path | Source glyph | SHA-256 |
|---|---|---|
| `assets/story/moods/funny.svg` | `1F604` | `e736c2d0cc0c72781aa4c5f4adf42f74fe99105a14713e29eeb7e1f35343784f` |
| `assets/story/moods/adventurous.svg` | `1F3D5` | `803cbbaac27c051d85e46665d9359f40c13ebc97021430681d13fd36e4e39867` |
| `assets/story/moods/spooky.svg` | `1F47B` | `023a6676ac85148b7f024a105fa72bd43057d9d42d9cf5c6bbdc9f9375dfb09d` |
| `assets/story/moods/calm.svg` | `1F60C` | `97a515ade6092b99626650004dd93565e925dfa198a5e1ee9e207f8c807d6676` |
| `assets/story/settings/forest.svg` | `1F332` | `0d03d0ea7819bf9fd22614a0623b7594d4175a986a18b386adfc6490844c48eb` |
| `assets/story/settings/ocean.svg` | `1F30A` | `ce86414cffcc35efc54fe5427a3d57c3f00acfde9d35b33d664fda483ae1c63b` |
| `assets/story/settings/city.svg` | `1F3D9` | `6f960c58da749f96f0862bff1f5bc5896dc5e2014227e949625f028af959acbe` |
| `assets/story/settings/space.svg` | `1F680` | `2403e0a305f931cf8c2ebd1a06de994c08733d0554eda8c0e52d1b8fe1be7001` |


## Hero avatars — Avataaars via DiceBear

Heroes are **generated at runtime, not bundled**. The app calls `dicebear_core`
locally, so no avatar artwork ships in `assets/` and nothing is fetched over the
network — which is what keeps the SRS requirement that core functionality work
offline.

- **Artwork:** [Avataaars](https://avataaars.com/) by Pablo Stanley
- **License:** the artist's own terms — free for personal and commercial use,
  with no attribution clause
- **Delivered by:** [DiceBear](https://www.dicebear.com/) `dicebear_core`
  10.7.0 and `dicebear_styles` 10.6.0, both published by dicebear.com
- **Modifications:** none to the artwork. Component variants and colours are
  selected through the documented options API.

**A caveat worth recording:** `avataaars.com` currently serves an expired TLS
certificate, so the canonical licence page does not load. The terms above are as
restated by DiceBear, which distributes the style. Every generated avatar also
embeds its own RDF provenance block naming Pablo Stanley, the source and the
licence, so each rendered hero carries its attribution with it regardless of
whether the original site is reachable.

## Pets — Kenney

Animal portraits in `assets/story/pets/` are from the
[Animal Pack](https://kenney.nl/assets/animal-pack) by Kenney Vleugels.

- **License:** [CC0 1.0](http://creativecommons.org/publicdomain/zero/1.0/).
  The pack's own `License.txt` reads: *"You may use these graphics in personal
  and commercial projects. Credit (Kenney or www.kenney.nl) would be nice but is
  not mandatory."* Credited here anyway.
- **Retrieved:** 2026-09-14
- **Modifications:** none. The `PNG/Round` variants are used as published.

| Bundled path | SHA-256 |
|---|---|
| `assets/story/pets/panda.png` | `894617bfebaba8c90d1479097142ca7e65e5f4090d92adf9f28d5deeacb33525` |
| `assets/story/pets/monkey.png` | `19cc15ff41c3627e28c3d95dae58783ee89b457add34bec96d60ff19a7df3335` |
| `assets/story/pets/rabbit.png` | `90e3d19e2882d00b5807dde100d42acbb964f4611dd52bf51d8addecf59c4977` |
| `assets/story/pets/penguin.png` | `bb6f7730fe008b9186ab377f5b2b5c696cee6dedb6d1ac1a96e1e18a62827b7d` |
| `assets/story/pets/pig.png` | `a66df1eefe99bd1434618e1af2a453e74e7d0d403f9d8f84c96b27a55b09438e` |
| `assets/story/pets/giraffe.png` | `121f720e2e280fe4f619ec4638f748959c3850789ce86923898555a0d303c4a9` |
| `assets/story/pets/elephant.png` | `507548c5c0a58e0abb5b1960e299b0c51b118a794a311b1adb0c23895ac0cf8d` |
| `assets/story/pets/parrot.png` | `0ff2e8c39413781773f46d40d918f4c0516012e6ed4d3736c2b0a875fd06c7f5` |

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
