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


## Hero characters — Kenney Toon Characters

Heroes are **bundled pictures**, one per character and pose. Nothing is
generated, composed or fetched, which keeps the SRS requirement that core
functionality work offline and removes the whole class of bug that comes with
assembling a figure from recolourable parts.

- **Artwork:** [Toon Characters](https://kenney.nl/assets/toon-characters) by
  Kenney Vleugels
- **License:** [CC0 1.0](http://creativecommons.org/publicdomain/zero/1.0/).
  The pack's own `License.txt`, bundled verbatim at
  `assets/story/toon/License.txt`, reads: *"This content is free to use in
  personal, educational and commercial projects. Support us by crediting
  Kenney or www.kenney.nl (this is not mandatory)."* Credited here anyway.
- **Modifications:** none. The files are the pack's `Poses HD` PNGs, copied
  byte for byte. Only the folder and file names changed, from
  `Female adventurer/PNG/Poses HD/character_femaleAdventurer_idle.png` to
  `assets/story/toon/explorer/idle.png`.
- **Subset:** 60 of the pack's 270 poses — 6 characters × 10 poses. The poses
  left out are fighting (attack, kick, hit, shove), falling, or drawn from
  behind, none of which suit a storybook hero a child is meant to recognise as
  their own.
- **Derived outfit colours:** a further 300 files (`<pose>-<colour>.png`) are
  generated from those 60 originals by `tool/recolour_outfits.py`, which is
  committed so the derivation is reproducible and reviewable. These characters
  have no garment layer to tint, but the art is flat enough that each
  character's clothing occupies a hue band nothing else on the figure shares;
  the tool rotates only that band, in HSV so the anti-aliased edges travel
  with it, and quantises the result back to an indexed PNG as the originals
  are. Skin, hair and boots are untouched. Two characters are worth noting:
  the robot's whole chassis is one blue, so its "outfit" is the robot; and the
  Pal's tan gilet shares the skin hue band, so only the trousers recolour.
  CC0 imposes no condition on derivative works — this is recorded because the
  SRS asks for documented provenance.

The in-app hero names (Explorer, Scout, Friend, Pal, Robot, Monster) are ours.
The pack labels four of its six characters by gender, which is not a sorting a
children's app should do on a child's behalf.

### Bundled pictures

| File | SHA-256 |
| --- | --- |
| `assets/story/toon/explorer/cheer1.png` | `e4ecee40de5572d8b07ca626427f3c52289e34c3ad6864ab39f1830feac488f3` |
| `assets/story/toon/explorer/duck.png` | `b273f3ab5ade789d3c116d8fca61d05c4553942682840dd15930bf698b6e6b24` |
| `assets/story/toon/explorer/hold.png` | `b36cf1f063b153d253c330d988e2ef151ba16f4c199964ca495fd092342b78cc` |
| `assets/story/toon/explorer/idle.png` | `ea2d020b168a5d6d02d66cccd375956db7854b386ee6e153d034cc0b00dff635` |
| `assets/story/toon/explorer/jump.png` | `8a50b5a8240d5a616339bb00a793f0ec944c7d774ba4c382c222923b17ba8b82` |
| `assets/story/toon/explorer/run1.png` | `06d5b6883edfd355a462fe0c5c650e0ef2f730670ba50381cd53f1dc02c477bd` |
| `assets/story/toon/explorer/talk.png` | `cdc42024698ee614d793df6ee7322536175049334aa304a3cb581ff528889788` |
| `assets/story/toon/explorer/think.png` | `5bf1e721a9d7b7a90ba3a16d1c86d025622a3a509ed2c6f07ebc303b963dfa48` |
| `assets/story/toon/explorer/walk1.png` | `d716019d3023f459a26c0c6c52ef06bdb8df910f6739c01c425c4bcd5e534858` |
| `assets/story/toon/explorer/wide.png` | `743eaa038dcd2353578c229110ea683f571959e1bb3ee9979f2b6fcdc374657e` |
| `assets/story/toon/friend/cheer1.png` | `55160bfb6ca860315866cddbbf2b1d1a048a4945e37cbe3e42cb9ca9ddc24be9` |
| `assets/story/toon/friend/duck.png` | `d617524041981d16be2d66a675a9336b447f76c89a9bc43bdab6f5885eb85322` |
| `assets/story/toon/friend/hold.png` | `ee833d5715afe2b1e7ebfd75e3381f73a47749f3658b70632bda33daf0005f87` |
| `assets/story/toon/friend/idle.png` | `9d730e78cfd4a065e613115b55d3c0135e4de3c8993e261230fef18bbbdbc480` |
| `assets/story/toon/friend/jump.png` | `a958b5ba14a4134fb8ab47bb424fba8f5d6f252ec9afa38cada432ed86137a73` |
| `assets/story/toon/friend/run1.png` | `8ff1b57004013ced4da86d320a71d378f0311737a613aa106099f3094d789c5c` |
| `assets/story/toon/friend/talk.png` | `4342faa8f851c3de7226b2d8f1fae3d9a173b6e68f0bb25309d2d2db974ea546` |
| `assets/story/toon/friend/think.png` | `8d3eb94f5d2c898f3adac3126a911425047d1d99a1940d6076045d6f6ca19db3` |
| `assets/story/toon/friend/walk1.png` | `6714fa63d4ff03b664c6e60a5e6e01c1959c8440aa3e7ad57b5dc350962af206` |
| `assets/story/toon/friend/wide.png` | `13d9e92033391b51eb5ae678f5768c8580ed7594817afa4aadbc4b2a2bda47d7` |
| `assets/story/toon/monster/cheer1.png` | `7af299e7eaa812c9a946615a3f7527351313230f66e8983094ba0eb35c546f46` |
| `assets/story/toon/monster/duck.png` | `c813f6506b45e918578f1010e9473709bf78991137ce48c473f34b7f9bb0e724` |
| `assets/story/toon/monster/hold.png` | `c5b972f71724d81eb9cad77c579289798ab526ab2193c88f5dff10969aa854cd` |
| `assets/story/toon/monster/idle.png` | `67e6fb5780f7ec4781689f971931534a906ecd3712c2109692c3df83407b976d` |
| `assets/story/toon/monster/jump.png` | `b100dc60b3ecb8d96ec2c0e6d03abfd3fd15258cfbf453592a9b5bfe9d9335b5` |
| `assets/story/toon/monster/run1.png` | `2f283ac7f6d2e7c459d922cfd555a935b6c5b6f5f320d154c837ad901b764f0e` |
| `assets/story/toon/monster/talk.png` | `11d4cde3725a32ce03ce8d08a0af2196db152d4da348196ef0e637f79004ef85` |
| `assets/story/toon/monster/think.png` | `fdf924f047ccfa45daa0fa94c3a71f7cc6fca26b9d0915cfa3605622d24d18c3` |
| `assets/story/toon/monster/walk1.png` | `112c0003c83026a17ba8d4e2de5860977d3792a68ca53f470c746313ba2566b7` |
| `assets/story/toon/monster/wide.png` | `977a5d9583e49542a79f885e24029ee8ccd53e221489ce00de6287f16210bd27` |
| `assets/story/toon/pal/cheer1.png` | `2e1d0235870eba486ecfbad1bd3751a80c8f6845422c7bf7040c342e5a9bbdc5` |
| `assets/story/toon/pal/duck.png` | `c79e7d76fbdeeed476d4190d22d6db215d7d813166ee6ced00c7a6ee6e670f85` |
| `assets/story/toon/pal/hold.png` | `2e36c0f07febe60bef5d71dad831673d661fe8b17d77016c3141e5901e02bb99` |
| `assets/story/toon/pal/idle.png` | `291c5c37e85491e50efa58ec5f11ca93f9e36c48a54e7d32b202d69954a3b67a` |
| `assets/story/toon/pal/jump.png` | `73d693c58c642a53e7d5dfeb7d2f265518a956fc41e8161c9d97399b7e0b42c9` |
| `assets/story/toon/pal/run1.png` | `f505bdf8a8ac56afd747a437bc76bcfc3f2621eb0af00f05cc97bb91ff45d47e` |
| `assets/story/toon/pal/talk.png` | `fad25909b843d1853fd026ada4994a35bc11cbeb88f6434e1311058e780827b1` |
| `assets/story/toon/pal/think.png` | `c0cdad1b7280d1d1202b663f08088ff702640929b646dfa14f0999479964fd13` |
| `assets/story/toon/pal/walk1.png` | `214bde378e9b183ac775a389045b37b81e0187b1c1127dbab54bce909697e5d6` |
| `assets/story/toon/pal/wide.png` | `c16a73ed920672880c4932638d90f0108a53a0d035ba6be4220c7cedd9410818` |
| `assets/story/toon/robot/cheer1.png` | `ec2e6554724e17948981fbca2701c12ed24d24c92e12f8b13ca5520997be454a` |
| `assets/story/toon/robot/duck.png` | `5d2d81fbaf3735800a6ff3115b8ec639eb434b68707958e496459c39c9396735` |
| `assets/story/toon/robot/hold.png` | `e91b345d827bc9883ca5c0683ef802e2c2391a19d764a6b7bd6a7bf3a71e9107` |
| `assets/story/toon/robot/idle.png` | `7858549240f335a7c9e2a23380298f99d1805ed3b9c478df02f9c8c8870943ba` |
| `assets/story/toon/robot/jump.png` | `8b9aae9166830e2eead03194da70280955f7854f41d744d9992dee908f118ace` |
| `assets/story/toon/robot/run1.png` | `33070ce9a09efe89598a75fdb793dd5909e8396e548a1fee7ea1a7e371ed04e6` |
| `assets/story/toon/robot/talk.png` | `3227fb46bb2e771e83abe25a082b9dc2742a94542f21a25c875db7041bb8433b` |
| `assets/story/toon/robot/think.png` | `5e22c1c91b849ba66e15d25211e779b19c62d702acabc71200c9435fd8f00e8f` |
| `assets/story/toon/robot/walk1.png` | `9dd2b3d98a6b474e10acd82492fbef728888b6d1cba088392958829afc478031` |
| `assets/story/toon/robot/wide.png` | `18dc0d06511e0cba6efb0d0a85e95c0843a0e028f6f43fc99b256f52ffe68c26` |
| `assets/story/toon/scout/cheer1.png` | `9898c5f045d09078fdafa4362d7fab6a9991e544257496fc06b637ec1d2cfdcc` |
| `assets/story/toon/scout/duck.png` | `7772262afc12415b0f90820ffdf59aa8de2b1ebef9661fb2ae8b0c951e28cd21` |
| `assets/story/toon/scout/hold.png` | `31361b3daad4fe66e9f9c3b65ed585976509e608f5181537e0887d3603257b6a` |
| `assets/story/toon/scout/idle.png` | `b89c1b41ec1fd043d542749e1966100787d3b31f5b593c7075b9aa2922a72281` |
| `assets/story/toon/scout/jump.png` | `e3ef48616fad776fe2dc664acfc30c0e24158c95ff4789702b5353a333714b2f` |
| `assets/story/toon/scout/run1.png` | `8bfb90b1afc6245d5b1d982da79eb2189fe639379db4b09d95844925777ceeee` |
| `assets/story/toon/scout/talk.png` | `e9d665ec9bf74f0a0627afce0ddd843648373e79074b1461e908db4702bb1156` |
| `assets/story/toon/scout/think.png` | `ac8e15b8837f059e3cfdc6ea0f0e48fef3a75d6afd05095795111c68f391a5c6` |
| `assets/story/toon/scout/walk1.png` | `bb6350f71a4258d58ea0dd56ed3d6920673d174597247b12e3ab09c00386797f` |
| `assets/story/toon/scout/wide.png` | `2660850e839589e5e2345cc87fd3d97507525ff177cb881f17c80284b7790dab` |

## Companions — Kenney Monster Builder Pack

The hero's companion in `assets/story/pets/` is a little monster, composed from
[Monster Builder Pack](https://kenney.nl/assets/monster-builder-pack) by Kenney
Vleugels.

- **License:** [CC0 1.0](http://creativecommons.org/publicdomain/zero/1.0/).
  The pack's own `License.txt` is bundled verbatim at
  `assets/story/pets/License.txt`.
- **Modifications:** the pack ships parts rather than finished creatures, so
  each companion is composed once by `tool/build_buddies.py` — body, arms,
  legs, eyes, mouth and a pair of horns, ears or antennae — and saved as a
  single picture. The tool is committed, downloads the pack itself, and names
  the parts each companion is built from, so every one is reproducible. No
  part was redrawn.
- **Why monsters and not animals:** these stand beside the hero head to foot.
  Kenney's animal packs are head-and-shoulders portraits in a circle, which
  read as a face floating next to a whole person, and there is no full-body
  animal set in the flat-vector style the heroes are drawn in. The Monster
  Builder Pack is by the same artist in the same register.
- **Faces:** chosen from the pack's cheerful half. It also ships angry, dead
  and "psycho" eyes, which are not what should follow a four-year-old's hero
  around.

| File | SHA-256 |
| --- | --- |
| `assets/story/pets/berry.png` | `35bb13bb9904cd5e0e54bb69c343300205012344d6722a4dddbda75667c34a93` |
| `assets/story/pets/bloop.png` | `aef5c1ec3f56acaf30ad1f5150194fbe06b775055ec4f84f06ef75dc978149b6` |
| `assets/story/pets/cloud.png` | `f8960286175ad0ea771d8db757a9fc68e2bbae6ad24d4211cb3f567ba267ae7d` |
| `assets/story/pets/mint.png` | `2bbe20c42ea8257d89ced1b780760452a830f031f3c38d634231c2b7c1d355a8` |
| `assets/story/pets/pip.png` | `99bfe94e0904610a894987604c29ca84fb4f378256735dfcd67c19f5473b2f60` |
| `assets/story/pets/rusty.png` | `00047439d85f48230e3837408f9953765a2c8a8918f4f8d396ff20309d183653` |
| `assets/story/pets/shadow.png` | `b69fb11a8f2ae32e38f98d80e8359cc232ed0afaf278f07389f3d10533fda89a` |
| `assets/story/pets/sky.png` | `f1b5c5dc75cb67fea39bf38df4038eb71ffa0e9264d655929f37b89018039661` |
| `assets/story/pets/snow.png` | `3fa39eec6b8ca34becb3e7e8239ae0ecd0f1100f6332f96909529f60ded17c2d` |
| `assets/story/pets/sunny.png` | `7b1f239ad78a99b87d5412549246465abe9c52b87d8f672f6cb5dc4338aa31c3` |

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
