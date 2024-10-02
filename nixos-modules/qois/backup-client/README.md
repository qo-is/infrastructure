# Backup Module

This module creates a host-based backup job `system-${target-hostname}` (currently with borg).
The module has sensible defaults for a whole system, note however that individual services/paths must be included or excluded added manually.

Target hosts should use the [Backup Server Module](../backup-server).
