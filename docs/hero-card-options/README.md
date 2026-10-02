# Hero card refinement options

The user's latest decision is to retain the collection hero cards as a distinctive Muses design. Their imported choices are saved without alteration in `../ui-ux-selected-choices.json`. Choice 12B retains the focus strip with a shorter stage; 13A preserves its activation continuity. Earlier recommendations to replace the default deck with a table do not override this decision.

Six concepts are available in `index.html`: H0 preserves the current hero-card structure; H1 reduces visual noise; H2 strengthens center-card hierarchy; H3 adds a wide-window information region; H4 relocates focus information below the covers; H5 preserves the deck while increasing list-preview space. H1 and H5 are conservative starting points. No option is automatically selected or implemented.

H0 is grounded in `Sources/Muses/Features/Shared/CollectionSongDeck.swift`: square artwork, an 86pt information footer, overlapping equal-sized cards, alternating -4/+3 degree tilts, zero tilt for the focused card, one canonical focus, and centered activation. The concept diagram substitutes fictional content; it is not a production screenshot. Surrounding navigation islands reflect the user's supplied direction and are context rather than an approved final implementation.

All options preserve collection playback, focus navigation, keyboard access, complete-table expansion, context menus, and Reduce Motion behavior as implementation requirements. Real artwork decoding, lazy mounting, activation animation, and performance require subsequent native implementation and verification. The H4 information relocation is deliberately marked as a larger change. Compact variants illustrate layout allocation at reduced height; they are not actual window-size simulation or animation.

The page stores hero selections separately and exports the supplied audit choices plus `heroCardDesign`. Dark and compact previews are static SVGs. Regenerate SVGs with `node docs/hero-card-options/render.cjs`; the HTML embeds the catalog and received choices. No production SwiftUI code is modified in this proposal phase.
