class_name MHAdvisor
extends RefCounted
## Pure helpers for the hole rating advisor. The rating engine (docs/spec/rating/rating-engine.md
## section 15) emits reason codes RCnnn with a severity; the advisor shows at most 3 per hole,
## highest severity first, then lowest code number. The UI maps a code to the string key
## "advisor.RCnnn". A reason row is a Dictionary {code:int, severity:int, a:int, b:int}.
##
## Severity ints here follow the spec order (smaller is worse). NOTE: docs/spec/interfaces/rating_engine.md
## says severity 0..2; the rating spec has five levels. The UI uses these five until the interface is reconciled.

const SEV_BLOCK: int = 0
const SEV_SEVERE: int = 1
const SEV_WARN: int = 2
const SEV_INFO: int = 3
const SEV_PRAISE: int = 4

const MAX_SHOWN: int = 3


static func code_label(code: int) -> String:
	return "RC%03d" % code


static func string_key(code: int) -> String:
	return "advisor." + code_label(code)


static func severity_key(severity: int) -> String:
	match severity:
		SEV_BLOCK:
			return "advisor.sev.block"
		SEV_SEVERE:
			return "advisor.sev.severe"
		SEV_WARN:
			return "advisor.sev.warn"
		SEV_PRAISE:
			return "advisor.sev.praise"
	return "advisor.sev.info"


static func is_praise(severity: int) -> bool:
	return severity == SEV_PRAISE


## Copy of `reasons` ordered by severity then code number. Rows without a code are dropped.
static func sorted_reasons(reasons: Array) -> Array:
	var out: Array = []
	for r: Variant in reasons:
		if typeof(r) == TYPE_DICTIONARY and (r as Dictionary).has("code"):
			out.append(r)
	out.sort_custom(_less)
	return out


static func top_reasons(reasons: Array, max_n: int = MAX_SHOWN) -> Array:
	var s: Array = sorted_reasons(reasons)
	if s.size() > max_n:
		return s.slice(0, maxi(0, max_n))
	return s


static func _less(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = int(a.get("severity", SEV_INFO))
	var sb: int = int(b.get("severity", SEV_INFO))
	if sa != sb:
		return sa < sb
	return int(a.get("code", 0)) < int(b.get("code", 0))
