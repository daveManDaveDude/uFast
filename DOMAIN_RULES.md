# Domain rules

## Terms

- **Fast:** a user-recorded or user-confirmed interval, not proof of a biological state.
- **Caloric event:** an event that counts as a fasting boundary. Food events
  always qualify; hydration follows the user's explicit classification.
- **Recorded fast:** explicitly started or entered by the user.
- **Reconstructed fast:** proposed from confirmed boundaries and saved after user confirmation.
- **Unknown period:** time without enough trusted information to assert a fast.

## Rules

- BR-01: Goal cannot be below 8 hours.
- BR-02: Goal changes do not alter completed history.
- BR-03: Only one active fast can exist.
- BR-04: End must be after start; both can be backdated.
- BR-05: Completed fasts retain the goal applicable when active.
- BR-06: Hydration does not break a fast unless marked caloric.
- BR-07: Food events are always caloric. Hydration classification remains
  explicit and correctable.
- BR-08: A caloric event inside an active fast prompts; it never silently changes the fast.
- BR-09: Reconstruction uses confirmed caloric boundaries and requires confirmation before save.
- BR-10: Insufficient or conflicting evidence remains unknown.
- BR-11: Changing a boundary invalidates affected reconstructed history for review.
- BR-12: Time-zone and daylight-saving changes preserve absolute instants.
- BR-13: Apple Health weight and steps are read-only in MVP.
- BR-14: Health permission denial never blocks manual features.
- BR-15: Copy describes records and patterns, not diagnosis or guaranteed physiology.
- BR-16: Correcting an active fast's start is limited to the preceding 24
  absolute hours; creating a new manually backdated fast may use an older start.
- BR-17: Saved fast intervals must not overlap, whether recorded or reconstructed.
  Treat completed intervals as half-open `[start, end)` ranges and an active fast
  as open-ended from its start for conflict checks, so touching boundaries are
  allowed. Existing conflicting records remain visible and are never silently
  rewritten.
- BR-18: Guided reconstruction considers consecutive user-saved caloric events
  and proposes only absolute intervals of at least eight hours. Both boundary
  events must exist; a range edge alone never becomes a boundary.
- BR-19: Every reconstruction candidate must be reviewed as accepted, adjusted
  or unknown before one explicit final save. An adjustment must remain within
  its supporting boundary instants, have positive duration and satisfy BR-17.
- BR-20: A confirmed reconstructed fast retains visible reconstructed
  provenance and does not claim a historical fasting goal. An unknown period is
  stored only after explicit review or when a bounded candidate is blocked by
  insufficient or conflicting evidence.
- BR-21: Adding a caloric event inside a reconstructed interval, or editing,
  deleting or reclassifying one of its supporting boundary events, marks the
  affected reconstructed fast for review in the same persistent transaction.
  The app never silently rewrites or deletes the saved fast.
