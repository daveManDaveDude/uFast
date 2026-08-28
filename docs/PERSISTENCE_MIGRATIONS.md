# SwiftData schema migrations

uFast opens every production, preview, test and custom-URL store through
`PersistenceContainer`, the current `VersionedSchema`, and `UFastMigrationPlan`.
CloudKit remains explicitly disabled in every configuration.

To evolve the stored schema:

1. Leave the existing versioned schema and its model declarations unchanged.
2. Add a new `VersionedSchema` containing the new model definitions and a higher
   `Schema.Version`.
3. Append the schema to `UFastMigrationPlan.schemas` and add the smallest suitable
   lightweight or custom `MigrationStage` from the preceding version.
4. Add an on-disk test that creates the preceding-version store, opens it through
   `PersistenceContainer`, and verifies every identifier, timestamp, provenance,
   goal, preference and domain value that must survive.
5. Test a migration failure and confirm the original store is neither deleted,
   reset nor replaced. Production recovery must remain the calm unavailable state;
   test reset and seeding arguments are never a migration strategy.

Never edit a released schema in place, point production at a fresh replacement
store, or enable CloudKit as part of a migration.

## Version 7: inferred-fast suppression

OW-412 adds `InferredFastSuppressionRecord` in an additive lightweight V6 to V7
migration. The entity is keyed by a source `CaloricBoundaryReference` and
stores derived projection metadata for local visibility recovery; it is not a
`FastRecord` and does not fabricate inferred history during migration. Existing
settings, events, fasts and legacy rows remain unchanged. Store-open
reconciliation removes stale suppression rows and refreshes qualifying rows
before History consumes them. Delete All Data includes this entity, and a
failed save restores the suppression snapshot through the same local rollback
boundary as the related mutation.
