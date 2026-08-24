# Repository document index

This is the repository's concise navigation point for current product and
engineering contracts. The classifications below are repository-level labels;
the original documents and their substantive status history remain unchanged.
Only the current-authority table governs current behavior and delivery
decisions.

## Status vocabulary

| Classification | Meaning |
| --- | --- |
| Current | The document is a current authority or current engineering entry point. |
| Active | Work or planning is still explicitly in view; only MNT-101 is the active implementation sprint. |
| Completed | The described delivery or review work is complete and retained as evidence. |
| Superseded | A newer document replaces this document for the named purpose. |
| Historical | Retained context, discovery, review, release or story evidence; not active instructions. |

## Current authority map

| Subject | Current authority | Historical/supporting treatment |
| --- | --- | --- |
| Product promise and principles | [PRODUCT.md](../PRODUCT.md) | Product packs are historical input. |
| Post-MVP roadmap | [docs/ROADMAP.md](ROADMAP.md) | Root roadmap references use `docs/ROADMAP.md`. |
| Original delivery ledger/current candidate links | [BACKLOG.md](../BACKLOG.md) | Completed slices remain ledger history. |
| Delivered 1.0 scope | [docs/MVP_SCOPE.md](MVP_SCOPE.md) | Explicitly historical release boundary. |
| Domain behavior | [DOMAIN_RULES.md](../DOMAIN_RULES.md) | Supersession notes remain authoritative history. |
| Accepted decisions | [DECISIONS.md](../DECISIONS.md) | No story document overrides an accepted decision. |
| Current architecture | [docs/ARCHITECTURE.md](ARCHITECTURE.md) | Review documents are evidence, not architecture authority. |
| Persistence migration guidance | [docs/PERSISTENCE_MIGRATIONS.md](PERSISTENCE_MIGRATIONS.md) | Completed migration stories are historical evidence. |
| Local engineering/release gates | [AGENTS.md](../AGENTS.md) and [docs/LOCAL_RELEASE_GATES.md](LOCAL_RELEASE_GATES.md) | App Store sprint records are historical evidence. |
| Active implementation-ready maintenance work | [MNT-101 follow-up sprint](POST_MVP_MAINTAINABILITY_FOLLOW_UP_SPRINT.md) | MNT-101 remains active until integrated acceptance; MNT-013B is sequenced after MNT-013A and is not started by this story. |

## Current supporting documents

These current public/support/design documents remain subordinate to the settled
authority map above and do not create a competing product or engineering
authority.

| Classification | Document | Treatment |
| --- | --- | --- |
| Current | [PRIVACY.md](../PRIVACY.md) | Current public privacy policy. |
| Current | [SUPPORT.md](../SUPPORT.md) | Current public support and local-data guidance. |
| Current | [UX_STYLE_GUIDE.md](../UX_STYLE_GUIDE.md) | Current visual guidance subordinate to product and domain authority. |
| Current | [Localization policy](LOCALIZATION_POLICY.md) | Current localization boundary subordinate to accepted decisions. |
| Current | [Tracked binary and generated-evidence policy](TRACKED_BINARY_POLICY.md) | Current MNT-013B retention and checker contract subordinate to local release gates. |
| Current | [Automatic Live Activity privacy policy](PRIVACY_AUTOMATIC_LIVE_ACTIVITIES.md) | Current optional-surface privacy policy. |
| Current | [Automatic Live Activity support](SUPPORT_AUTOMATIC_LIVE_ACTIVITIES.md) | Current optional-surface support guidance. |

## Active planning and work

| Classification | Document | Treatment |
| --- | --- | --- |
| Active | [MNT-101 follow-up sprint](POST_MVP_MAINTAINABILITY_FOLLOW_UP_SPRINT.md) | Current implementation entry point; MNT-013A is the assigned story. |
| Active | [MNT-014 root-tab accessibility story](MNT-014_ROOT_TAB_ACCESSIBILITY_STORY.md) | Draft future planning; not part of MNT-101 implementation. |
| Active | [Widget system-surface review stories](WIDGET_SYSTEM_SURFACE_REVIEW_STORIES.md) | Ready backlog planning; not the current implementation sprint. |
| Active | [Live Activity update recovery story](LIVE_ACTIVITY_UPDATE_RECOVERY_STORY.md) | Ready backlog planning; use accepted decisions as authority. |
| Active | [History streaming continuity story](HISTORY_STREAMING_CONTINUITY_STORY.md) | Ready backlog planning; not a current authority. |
| Active | [BF-101 fast-start boundary story](BF-101_FAST_START_36_HOUR_BOUNDARY_STORY.md) | Ready backlog planning; not a current authority. |
| Active | [BF-102 History midnight seam story](BF-102_HISTORY_MIDNIGHT_SEAM_RENDERING_STORY.md) | Ready backlog planning; not a current authority. |
| Active | [OW-410 inferred-fast story](OW-410_INFERRED_FAST_DETECTION_STORY.md) | Ready story retained for candidate delivery. |
| Active | [OW-411 caloric-boundary story](OW-411_CALORIC_EVENT_FAST_BOUNDARY_STORY.md) | Ready story retained for candidate delivery. |
| Active | [Favourite drink story](FAVOURITE_DRINK_MANAGEMENT_STORY.md) | Ready backlog planning; not a current authority. |
| Active | [Persistence-integrity review sprint](CODE_REVIEW_PERSISTENCE_INTEGRITY_SPRINT.md) | Ready backlog planning; not the current implementation sprint. |
| Active | [Release-integrity review story](CODE_REVIEW_RELEASE_INTEGRITY_STORY.md) | Ready backlog planning; not the current implementation sprint. |
| Active | [App Store packaging review story](CODE_REVIEW_APP_STORE_PACKAGING_STORY.md) | Ready backlog planning; not the current implementation sprint. |
| Active | [History timeline UX improvement sprint](HISTORY_TIMELINE_UX_IMPROVEMENT_SPRINT.md) | Ready backlog planning; not the current implementation sprint. |
| Active | [Live Activity progress freshness story](LIVE_ACTIVITY_PROGRESS_FRESHNESS_STORY.md) | Ready backlog planning; not the current implementation sprint. |

## Completed delivery records

| Classification | Document | Treatment |
| --- | --- | --- |
| Completed | [MNT-100 predecessor sprint](POST_MVP_MAINTAINABILITY_SPRINT.md) | MNT-002 through MNT-008 predecessor evidence; no longer an active command source. |
| Completed | [Maintainability hardening stories](MAINTAINABILITY_HARDENING_STORIES.md) | Final sprint gate passed; retained for implementation evidence. |
| Completed | [MNT-005 boundary query measurements](MNT-005_BOUNDARY_QUERY_MEASUREMENTS.md) | Completed structural evidence retained for the delivered work. |
| Completed | [Slice 1.5 stories](SLICE_1_5_UX_STORIES.md) | Delivered story and visual-contract record. |
| Completed | [Slice 2 Today stories](SLICE_2_TODAY_STORIES.md) | Delivered story and behavior-contract record. |
| Completed | [Slice 3 catch-up stories](SLICE_3_CATCH_UP_STORIES.md) | Delivered historical-entry and provenance record. |
| Completed | [Slice 3.5 History UX stories](SLICE_3_5_HISTORY_UX_STORIES.md) | Delivered visual-integration record. |
| Completed | [Slice 3.6 History interaction stories](SLICE_3_6_HISTORY_INTERACTION_STORIES.md) | Delivered interaction record. |
| Completed | [Slice 3.7 analog History stories](SLICE_3_7_ANALOG_HISTORY_SCROLL_STORIES.md) | Delivered carousel record. |
| Completed | [Slice 3.8 coupled History stories](SLICE_3_8_COUPLED_HISTORY_SCROLL_STORIES.md) | Delivered date-rail record. |
| Completed | [Slice 3.9 History interaction polish stories](SLICE_3_9_HISTORY_INTERACTION_POLISH_STORIES.md) | Completed record retained per the delivery ledger. |
| Completed | [Slice 3.10 automatic-fast History stories](SLICE_3_10_AUTOMATIC_FAST_HISTORY_STORIES.md) | Delivered replacement record. |
| Completed | [Slice 3.11 History grouping stories](SLICE_3_11_HISTORY_EVENT_GROUPING_STORIES.md) | Story-level completion is retained; its old sprint header is not an active command. |
| Completed | [Lock Screen stories](OW_LOCK_SCREEN_STORIES.md) | Delivered source and decision evidence; open release evidence remains historical. |
| Completed | [Automatic Live Activity stories](OW_LIVE_ACTIVITY_AUTOMATION_STORIES.md) | Delivered source and decision evidence; open release evidence remains historical. |
| Completed | [OW-L101 Lock Screen contract](OW-L101_LOCK_SCREEN_CONTRACT.md) | Accepted contract and prototype evidence; production capability followed in OW-L102. |

## Superseded records

| Classification | Document | Superseded by |
| --- | --- | --- |
| Superseded | [App Store readiness sprint](APP_STORE_RELEASE_READINESS_SPRINT.md) | The later release-plan records and current local release gates. |
| Superseded | [App Store readiness sprint v2](APP_STORE_RELEASE_READINESS_SPRINT_V2.md) | The later release-plan records and current local release gates. |
| Superseded | [App Store readiness sprint v3](APP_STORE_RELEASE_READINESS_SPRINT_V3.md) | The later release-plan records and current local release gates. |
| Superseded | [App Store submission execution plan](APP_STORE_SUBMISSION_EXECUTION_PLAN.md) | [Build 10 handoff](APP_STORE_CONNECT_BUILD_10.md) for its active-submission state. |

## Historical and review evidence

These documents remain useful records but do not override the current authority
map or make a completed story active. Their internal `Ready`, `Done`, review or
release wording is preserved as written.

| Classification | Document |
| --- | --- |
| Historical | [MNT-101 source code review](POST_MVP_MAINTAINABILITY_CODE_REVIEW.md) |
| Historical | [Ready story catalog](READY_STORIES.md) |
| Historical | [MNT-008 identity/schema feasibility (BLOCKED artifact)](MNT-008_IDENTITY_SCHEMA_IMPLEMENTATION_STORY.md) |
| Historical | [OW-L105 Luna prompt](OW_L105_LUNA_PROMPT.md) |
| Historical | [OW-L109 App Review notes](OW_L109_APP_REVIEW_NOTES.md) |
| Historical | [Automatic Live Activity Luna prompt](OW_LIVE_ACTIVITY_AUTOMATION_LUNA_PROMPT.md) |
| Historical | [Parallel UI test handoff](PARALLEL_UI_TESTS_CODEX_HANDOFF.md) |
| Historical | [Post-MVP maintainability Luna prompt](POST_MVP_MAINTAINABILITY_LUNA_PROMPT.md) |
| Historical | [Sol/Luna sprint workflow](codex-sprint-workflow.md) |
| Historical | [Story follow-up note](story-not-to-forget.md) |
| Historical | [Release notes](../RELEASE_NOTES.md) |
| Historical | [MVP App Store release plan](MVP_APP_STORE_RELEASE_PLAN.md) |
| Historical | [App Store build 9 record](APP_STORE_CONNECT_BUILD_9.md) |
| Historical | [App Store build 10 handoff](APP_STORE_CONNECT_BUILD_10.md) |
| Historical | [Product brief](Personal_Health_Companion_Product_Brief.md) |
| Historical | [Agentic configuration review](AGENTIC_CONFIG_REVIEW_AND_RECOMMENDATIONS.md) |
| Historical | [Story template](STORY_TEMPLATE.md) |

The [README](../README.md) links here as its first documentation navigation
point. Future generated binary evidence is governed separately by MNT-013B;
this index does not move or delete existing evidence.
