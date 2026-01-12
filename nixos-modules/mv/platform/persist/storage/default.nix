# Configuration of storage im classes, and mapping to device paths.
# Storage classes are devided in:
# - hot (ssd, raid1), use cases: database, binaries, cache etc.
# - cool (hdd, raid1, possibly cached), usecases: data at rest e.g. cloud files
# - cold (hdd, raid1/5) levels