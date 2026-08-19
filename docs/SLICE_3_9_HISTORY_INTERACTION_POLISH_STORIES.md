# Slice 3.9 — History interaction polish

## Contract

Manual date-rail motion is visual-only until native scrolling and inertia are
idle. At settlement, History selects once the valid buffered chip nearest the
rail's visual centre, in both layout directions, and aligns the lower timeline
once. Initial layout, programmatic alignment, lower-carousel coupling,
interruption and rebasing never settle the rail.

Completed days and elapsed Today instants may open the existing confirmation
before Food or Drink. Future dates and the remaining portion of Today are read
only; picker bounds end at `clock.now`. D-013 remains unchanged.

History browsing ends at Today + 1 local-calendar day. Future treatment uses
subtle semantic colour plus visible and accessible read-only language. Timeline
rules occur every two local-calendar hours, with labels only at 00:00, 06:00,
12:00 and 18:00. Calendar and TimeZone arithmetic are used throughout.
