# crayon-art

Generates the public crayon kit pictures used as v0 of every drawing slot.

```bash
npm ci
node kit.js . ../../ios/KitArt/Resources/KitArt.xcassets
```

- The first argument is the folder that holds `node_modules/roughjs`, which is this folder after `npm ci`.
- Each picture is written as `<KitSlot raw value>.imageset/` with `preserves-vector-representation: true`.
- Each picture gets its own seed, derived from its slot name.
  - Adding, removing or reordering pictures never changes another picture.
  - The same input always produces the same files, so re-running leaves `git status` clean.
- Style rules: one bold marker outline, crayon hatching with the paper showing, colour spilling slightly past the line, plain dot eyes, a one-line smile.
- Do not add pictures of real places, schools or people here, because this folder is public.
  - Private overrides (the school mascot for `actSchool`, the real home for `home`) live in git-ignored `ios/KitArt/Private/<slot>.svg`.
