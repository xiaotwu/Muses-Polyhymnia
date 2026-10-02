# Muses UI/UX visual samples

This catalog illustrates every option in `../ui-ux-audit-options.json`: 64 areas, four alternatives each, 256 independent SVG samples. These are concept diagrams with fictional content, not production screenshots or native Liquid Glass renders. They show differences in layout, hierarchy, controls, state, and workflows; implementation choices with similar appearance are illustrated through their user-visible consequences.

Open `../ui-ux-design-selector.html` to compare alternatives, enlarge previews, switch appearance, inspect supported secondary states, select combinations, and export JSON. `overview.html` shows all samples together. Files work offline when this directory remains beside the selector. A local server is optional:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory docs
```

Choices retain the previous `muses-ui-ux-choices-v1` local storage key and export schema. Storage is scoped to the browser origin; opening the file or using another port does not transfer choices. Export before switching origins. No selections are automatically applied to the application.

Regenerate the static previews and embedded catalog with:

```sh
node docs/ui-ux-visuals/build.cjs
```

`render.js` defines the component-specific SVG compositions. The selector renders dark and secondary states on demand. Original abstract cover illustrations and lyric examples avoid any dependency on user library data or remote assets. Production macOS appearance, native controls, accessibility, motion, and performance require separate runtime verification.

Verification: catalog coverage and XML validity passed for all 256 distinct SVG assets. The in-app browser loaded all 256 images. Search, component navigation, enlarged previews, dark appearance, secondary states, multi-selection, notes, reload persistence, and JSON file contents were checked. Temporary verification choices were cleared. Browser error logs were empty. App builds/tests were not repeated because this change only creates documentation and concept previews.
