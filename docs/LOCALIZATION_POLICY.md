# Localization policy

uFast keeps English as its development and shipped language while its
localization boundary is established. User-facing copy on migrated surfaces is
owned by `uFast/App/AppText.swift` and `uFast/Resources/Localizable.xcstrings`.

- Keys use a stable, lower-case, dot-separated surface and purpose, such as
  `food.confirmation.active.message` or `drink.validation.volume`.
- Catalog comments describe the UI context, VoiceOver use, and any semantic
  distinction that translators must preserve. User-entered food, drink and
  favourite names are data, not catalog content.
- Interpolations stay typed at the `LocalizedStringResource` boundary. Counts
  use catalog plural variations, dates and times use the caller's
  `FormatStyle`, and formatted values are never assembled in domain or
  persistence types. Test-only pseudolocalization protects representative
  interpolated values at the `AppTextResolver` boundary before expanding
  surrounding copy.
- Accessibility labels, values and hints use the same `AppText` API as visible
  copy. Stable accessibility identifiers are separate from localized labels.
- Domain and persistence errors remain semantic. Localized prose is mapped only
  at presentation or system-surface boundaries.
- Test-only pseudolocalization is enabled only by `--ui-testing` plus
  `--ui-testing-pseudolocalization`; it is not a locale, a catalog localization,
  an `Info.plist` localization entry, or a release setting.
- Focused UI coverage reaches migrated confirmation and accessibility copy at
  `UICTContentSizeCategoryAccessibilityXXXL` through the typed UI-test launch
  configuration. This is simulator evidence, not a device claim.

New user-facing literals on a migrated surface must be added to both
`AppText` and the catalog. `scripts/check_localized_literals.py` is the local
source guard; a narrow `// localization-exception:` comment is required for an
intentional non-copy literal in a guarded presentation expression.

The same guard token-scans every `resource` first argument in `AppText`,
including each branch of a conditional key expression. The resulting key set
must exactly equal the catalog key set. There are currently no metadata-only
catalog entries; any future exception must be a documented, narrowly named
allowlist entry in the guard. Every catalog entry with plural variations must
provide both `one` and `other` English forms.
