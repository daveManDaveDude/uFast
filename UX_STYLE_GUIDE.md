# uFast UX style guide

**Status:** Current after Slice 3.7
**Last reviewed:** 23 July 2026
**Source of truth:** `uFast/Features/Foundation/UFastDesignSystem.swift`

This is the quick reference for extending uFast without rediscovering the visual
decisions made during OW-150 through OW-155. It translates the Slice 1.5 visual
contract into reusable implementation guidance. It does not expand product
scope or override the behavioural rules in `DOMAIN_RULES.md`.

## The uFast feel

uFast should feel calm, natural, private and direct:

- warm ivory canvas, deep evergreen hierarchy and restrained natural accents;
- generous space, softly rounded surfaces and fine visible boundaries;
- one obvious primary action per screen;
- concise, neutral language that records behaviour without coaching or health
  claims;
- nature and open-window imagery used as atmosphere, never as the only source
  of meaning;
- native iOS behaviour wherever it improves accessibility, locale handling or
  familiarity.

When a screen feels busy, remove competition before adding decoration.

## Slice 1.5 delivery record

| Story | Delivered outcome |
| --- | --- |
| OW-150 | Semantic colours, typography, spacing, radii, cards, button styles, brand treatment, screen shell and representative previews. |
| OW-151 | Branded first-use introduction, neutral 8–24 hour goal choice, persistent selection and retry state. |
| OW-152 | Calm inactive Today state with one dominant start action, past-start access, target preview, validation and error states. |
| OW-153 | Glanceable active-fast hero, second-precision elapsed timer, thick progress treatment, reached-goal state, facts card and prominent start correction. |
| OW-154 | Consistent start/end editors, past-end flow, completion feedback, completed-fast correction and safe confirmation behaviour. |
| OW-155 | Coherent History and Settings, illustrated empty state, completed-fast edit/delete, goal changes, full appearance/accessibility review and journey verification. |

The final visual refinement also established purpose-made botanical artwork,
light and dark thumbnail variants, matching light and dark app icons, a precise
progress-fill shape, and calmer light-mode form surfaces.

## Foundation tokens

Use the named roles in `UFastTheme`; do not introduce screen-local literal
colours, spacing or corner radii when an existing role expresses the intent.

### Colour roles

| Token | Use |
| --- | --- |
| `canvas` | Full-screen background. Warm ivory in light mode; deep green-black in dark mode. |
| `primary` | Main text, headings and high-value information. |
| `action` / `onAction` | Primary interactive fill and its foreground content. |
| `surface` | Ordinary grouped card surface. |
| `raisedSurface` | Controls or content that must separate more clearly from the canvas. |
| `formSurface` | Form rows and editor groups; deliberately softer than pure white in light mode. |
| `sage` | Calm positive or natural supporting accent. Not a success claim. |
| `sky` | Illustrated hero and information-card atmosphere. |
| `apricot` | Restrained warm accent, principally the sun motif. |
| `border` | Semantic surface separation, including increased-contrast treatment. |
| `secondaryText` | Supporting labels and explanations. |
| `error` | Validation, destructive actions and failures only. |

Check both appearances whenever a token is added or changed. Increased contrast
must strengthen meaningful boundaries without relying on shadows.

### Spacing and shape

| Role | Value | Typical use |
| --- | ---: | --- |
| `compact` | 8 pt | Closely related label/icon or text pairs. |
| `standard` | 16 pt | Default internal padding and control groups. |
| `generous` | 24 pt | Cards and major sibling groups. |
| `section` | 32 pt | Distinct sections and hero breathing room. |
| `control` radius | 14 pt | Buttons, action rows and compact artwork. |
| `card` radius | 22 pt | Ordinary information and facts cards. |
| `hero` radius | 32 pt | Large illustrated or focal surfaces. |

These values are semantic defaults, not permission to force fixed layouts.
Allow content to grow for Dynamic Type.

### Typography

- Use `Font.uFastDisplay` for screen titles, major card headings and the brand.
- Use the system sans-serif family throughout. Weight and Dynamic Type style
  create hierarchy; uFast does not depend on a third-party font.
- Use native body, headline, subheadline and caption styles for supporting text.
- Use monospaced digits only where changing character widths would make a live
  value jump, such as the elapsed timer.
- If a focal value needs a custom point size, scale it with `@ScaledMetric`,
  provide a deliberate minimum scale factor and verify accessibility sizes.
- Never communicate selection, status or hierarchy by font treatment alone.

## Reusable patterns

### Screen composition

Use `ScreenLayout` and the shared brand/header treatment. Start with this order:

1. destination title and compact uFast mark;
2. the current state or most important value;
3. supporting facts or explanation;
4. one dominant action;
5. subordinate correction, maintenance or destructive actions.

Keep the principal action visible and unambiguous. Do not make several filled
buttons compete.

### Buttons and actionable rows

- `UFastPrimaryButtonStyle`: the one dominant action.
- `UFastSecondaryButtonStyle`: a valid alternative with lower emphasis.
- `UFastActionRowButtonStyle`: a discoverable correction or navigation action
  inside a card, with a label, useful symbol and chevron where appropriate.
- `UFastDestructiveButtonStyle`: destructive action with semantic red text and
  border; keep it visually separate from the main flow and confirm before
  changing data.

Controls must retain at least a 44-by-44-point interaction target. Disabled
state must remain readable but clearly unavailable.

### Cards and forms

Use `.uFastCard()` for related read-only facts or compact content. Use
`formSurface` for date/time rows and editor groups so light-mode sheets do not
become a stack of harsh white panels on ivory.

Use native `DatePicker`, navigation, confirmation dialog and alert behaviour.
Use `border` for dividers. A destructive form action should look intentionally
actionable, not like a large blank white card with red text floating inside it.

### Illustrated information card

`UFastIllustratedInformationCard` is the standard pattern for a calm,
non-interactive empty or explanatory state:

- one rounded tonal surface;
- restrained botanical artwork;
- one concise heading and one short supporting message;
- text positioned in a deliberately quiet area of the image;
- complete meaning when the decorative image is hidden.

Use it for empty or informational states, such as empty History. Do not use it
for actions, warnings, forms, confirmations or dense data.

### Botanical artwork and icon

`FastingBotanical` is the full-width atmospheric artwork used by the active-fast
hero and illustrated information cards. `FastingBotanicalThumbnail` is the
purpose-made compact landscape used where the same composition must read at a
small size.

Preserve these composition rules:

- the branch enters from the left at its original angle and does not overlap
  primary text;
- the full sun remains visible with generous sky around it;
- layered hills remain anchored to the lower right and fade into the surface;
- artwork remains decorative and is hidden from accessibility;
- use the asset catalogue's light/dark variants instead of applying a generic
  filter to simulate dark artwork.

The app icon uses native light and dark luminosity variants. Home Screen icon
appearance remains an iOS/user preference and is separate from the app's own
colour scheme.

### Active-fast progress

The elapsed timer represents the full recorded duration and continues after the
goal is reached. The progress bar represents progress toward the goal and
therefore clamps at 100%.

`UFastThickProgressStyle` has deliberate edge rules:

- zero progress shows no fill;
- the first visible fill is a tiny curved sliver; it must not exaggerate a few
  seconds into a large cap;
- every partial fill has a vertical trailing edge, including very short fasts;
- only a fully completed bar is rounded at both ends;
- there is no separate progress dot.

Do not reproduce this geometry in a feature screen; reuse the shared style.

## History evidence states

History must name provenance in text, not colour alone. Use **Recorded by you**
for directly recorded fasts, **Reconstructed · Confirmed by you** for reviewed
reconstruction, **Adjusted by you** when its interval was changed, **Needs
review** when supporting evidence changes, and **Unknown period** when no fast
was saved. Reconstructed and converted records without a captured goal omit the
historical-goal row. Changed-history review presents **Currently saved** before
**Updated evidence** and keeps conversion and removal subordinate to **Update
and reconfirm**.

## Temporal history language

History and Catch up use a shared, evening-to-evening temporal ribbon. This is
a viewport over existing absolute records, never a stored day model.

- History has one transient selected local date shared by the month heading,
  native date picker, stable date rail, centered temporal page and structured
  detail. Fractional scroll position is never a selected date, and automatic
  alignment must not feed a second selection change back into that state.
- History temporal detail is a native-inertial, day-aligned carousel. Content
  tracks the finger continuously; a fast release may cross several adjacent
  local-calendar dates before settling. It does not restore within-day
  horizontal panning.
- While either horizontal surface is being manipulated or the carousel is
  decelerating, automatic rail and page alignment pauses. The settled centered
  page becomes the selected day exactly once. Deliberate buttons, chips, picker
  and accessibility actions align immediately to avoid competing travel
  animations.
- The locale-derived date rail keeps stable day identity across week, month and
  year boundaries. Its selected date uses text, fill, a visible border and the
  word **Selected**; blank dates are neutral. Manual rail scrolling does not
  select a date.
- The default ribbon begins at 18:00 on the preceding local date and ends at
  18:00 on the following local date. Geometry uses the actual elapsed interval,
  so London clock changes naturally produce 47- or 49-hour two-date windows.
- Fasts use capsule intervals. A clipped interval shows doubled chevrons when
  space permits; a very short segment uses its status symbol alone instead of
  clipping text. Both keep one record identity and one detail destination.
- Recorded intervals use sage; reconstructed intervals use sky; Needs review
  uses restrained apricot plus its warning symbol and text; unknown periods use
  a dashed outline, question-mark symbol and explicit copy.
- Food and caloric drinks use warm filled marks with distinct system symbols.
  Non-caloric drinks use an outlined circular drop mark and never appear as a
  fasting boundary.
- Dense visual marks use deterministic lanes. Lane position is presentation
  only and is never persisted.
- On completed days, an empty ribbon point maps through the actual absolute
  window to an in-memory instant. Existing marks take precedence. The selected
  date and time are shown with native controls before **Food**, **Drink** or
  **Cancel**, and nothing is recorded until the reused full editor saves.
- Every ribbon has a structured chronological alternative for VoiceOver.
  History exposes actionable semantic rows; Catch up follows its summary with
  the existing editable event list.
- The selected-day heading supports adjustable Previous/Next day actions.
  Named buttons, the native picker and date chips remain complete alternatives
  to drag precision, and no accessibility announcement represents a fractional
  page offset.
- At accessibility sizes, replace the non-semantic visual axis with a calm
  **Timeline details are listed below** card, make the structured list the
  primary precision-independent representation, and expose a vertically
  expanding **Add at selected time** control as the explicit alternative to
  canvas tapping.
- Eligible eight-hour-or-longer caloric gaps are labelled **Suggested fast ·
  Needs review** until Accept, Adjust or Leave unknown review and the final
  atomic save. They must not resemble confirmed reconstructed fasts before that
  save.
- A native graphical date picker is the subordinate month jump. Do not add a
  competing month dashboard or seven-column time canvas.

Axis labels must be formatted through the injected Calendar, Locale and
TimeZone. Do not divide geometry by 24 hours, hardcode weekday order or use an
ambiguous numeric date. Repeated autumn times include GMT/BST context when
needed; geometry must not invent a missing spring time.

## Accessibility and adaptation

Every new or changed screen must be checked for:

- light and dark appearance;
- increased contrast;
- a narrow iPhone width and a wider Pro Max width;
- at least one accessibility Dynamic Type size;
- logical VoiceOver reading order, labels, values and retained test identifiers;
- decorative artwork excluded from the accessibility tree;
- Reduce Motion, with no essential meaning dependent on bespoke animation;
- locale-sensitive dates and times through native formatters and controls;
- usable empty, validation, persistence-error and offline states.

Prefer flexible frames and content-driven height. Avoid device-specific offsets,
especially for artwork or bottom controls.

## Content rules

- Always call the product **uFast**.
- Prefer **fast**, **fasting goal**, **started**, **target** and **recorded
  fast**.
- Describe what was recorded; do not assert a biological state or health result.
- Avoid praise, guilt, urgency, streak pressure, coaching and body-shaming.
- Keep explanations short enough to preserve the visual hierarchy.

## Extending the system

Before adding styling to a new feature:

1. Check this guide and `UFastDesignSystem.swift` for an existing semantic role
   or component.
2. If the need repeats or expresses a product-wide meaning, add one shared
   semantic role and document its intended use here.
3. If the need is genuinely feature-specific, keep it local but build it from
   semantic tokens.
4. Add or update a representative preview.
5. Verify the accessibility and appearance matrix above.

Do not ship pieces cropped from composite reference mockups. Prefer native
symbols, code-native decoration or a purpose-made asset with correct catalogue
variants.

## Definition-of-Done checklist

- The screen has one obvious primary action.
- Literal colours, duplicated button styles and arbitrary spacing are absent.
- Light, dark and increased-contrast hierarchy are equivalent.
- Dynamic Type, VoiceOver and narrow/wide widths remain usable.
- Empty, error, validation and offline states remain calm and operable.
- Existing accessibility identifiers and domain behaviour are preserved.
- Relevant previews and tests are updated.
- `make format`, `make build`, `make test-unit`, `make test-ui`, `make lint` and
  `git diff --check` pass in proportion to the change.
- The complete diff contains no unintended persistence change or Slice 2 scope.

## Related documents

- `SLICE_1_5_UX_STORIES.md` — accepted visual contract and story criteria.
- `SLICE_3_5_HISTORY_UX_STORIES.md` — temporal History/Catch-up research,
  accepted direction and delivery criteria.
- `SLICE_3_7_ANALOG_HISTORY_SCROLL_STORIES.md` — analog carousel, stable date
  rail and movement-state verification.
- `DECISIONS.md` — D-012 and other accepted product decisions.
- `DOMAIN_RULES.md` — authoritative fasting and persistence behaviour.
- `PRODUCT.md` and `MVP_SCOPE.md` — product principles and scope boundary.
