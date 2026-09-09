extends Node
## Existing home/village consumers wait on this shared readiness contract.
var world_initialized: bool:
	get: return get_parent().world_initialized
