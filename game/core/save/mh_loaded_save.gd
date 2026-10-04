class_name MHLoadedSave
extends RefCounted
## What MHSaveStore.load_slot returns in MHSaveResult.value.

## The validated, migrated, sealed save document (ints only).
var data: Dictionary = {}
## Terrain blob bytes (MHTerrainSave format), verified to pair with data.course.terrain.content_hash. Empty when the
## save has no terrain reference.
var blob: PackedByteArray = PackedByteArray()
var json_source: String = "main"
var blob_source: String = ""
## True when anything other than the main files was used (tmp or bak for the JSON or the blob).
var recovered: bool = false
var migrated: bool = false
var from_version: int = 0
var warnings: Array = []
