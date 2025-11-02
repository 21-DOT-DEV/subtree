# Data Model: CLI Bootstrap & Test Foundation

**Feature**: 001-cli-bootstrap  
**Date**: 2025-10-26

## Status: Not Applicable

This bootstrap spec establishes CLI infrastructure only. No domain entities or persistent data models are defined in this phase.

## Future Considerations

Subsequent specs will define:
- **Subtree Configuration**: Structure of subtree.yaml
- **Repository State**: Git repository metadata
- **Command Arguments**: Typed argument structures

The bootstrap provides the foundation for these future models through:
- YAML parsing capability (Yams dependency)
- File system operations (swift-system dependency)
- Process execution (swift-subprocess dependency)

## Test Entities (Transient Only)

The integration test harness creates temporary test entities:

### GitRepositoryFixture

**Purpose**: Temporary git repository for integration testing

**Attributes**:
- `tempPath: FilePath` - Temporary directory path
- `isInitialized: Bool` - Whether git init has been called

**Lifecycle**: Created at test start, destroyed at test cleanup

**Not Persisted**: Exists only in memory during test execution

---

No persistent data model required for this bootstrap spec.
