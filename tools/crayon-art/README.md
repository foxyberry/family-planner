# crayon-art

Generates the public crayon kit pictures used as v0 of every drawing slot.

```bash
npm ci
node kit.js . ../../ios/KitArt/Resources/KitArt.xcassets [shapes.json]
```

- The optional third argument also writes the style-free shape definitions (paths, colours, hatch angles per layer) plus the crayon style's parameters as JSON. An app-side renderer can use it to draw every picture in another style without a new SVG set.

- The first argument is the folder that holds `node_modules/roughjs`, which is this folder after `npm ci`.
- Needs Node 22.12 or newer: outlines use `points-on-path` (installed with roughjs), which is an ES module loaded with `require()`.
- Each picture is written as `<KitSlot raw value>.imageset/` with `preserves-vector-representation: true`.
- Each picture gets its own seed, derived from its slot name.
  - Adding, removing or reordering pictures never changes another picture.
  - The same input always produces the same files, so re-running leaves `git status` clean.
- Style rules: one bold freehand marker outline (long straight runs bow a little and every edge drifts slowly), crayon hatching with the paper showing, colour spilling slightly past the line, plain dot eyes, a one-line smile.
- Do not add pictures of real places, schools or people here, because this folder is public.
  - Private overrides (the school mascot for `actSchool`, the real home for `home`) live in git-ignored `ios/KitArt/Private/<slot>.svg`.
