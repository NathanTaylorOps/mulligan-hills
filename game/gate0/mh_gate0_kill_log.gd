class_name MHGate0KillLog
extends RefCounted
## Pure logic for the kill-during-save test (Gate 0 item 10). The save loop appends one line per event to a
## text log in user://, and after every relaunch "Load and verify" judges the loaded save against that log.
##
## Line formats (space separated, last field is a millisecond tick):
##   B <gen> <ms>          save of generation <gen> is about to start
##   D <gen> <ms>          save of generation <gen> finished (rename done)
##   V <outcome> <gen> <ms> a verify ran: outcome OK, FALLBACK, CORRUPT or NONE, generation found (-1 if none)
## A kill can tear the final line; malformed lines are ignored.

const GEN_MOD: int = 30000
const OUTCOMES: PackedStringArray = ["OK", "FALLBACK", "CORRUPT", "NONE"]


static func begin_line(gen: int, ms: int) -> String:
	return "B %d %d" % [gen, ms]


static func done_line(gen: int, ms: int) -> String:
	return "D %d %d" % [gen, ms]


static func verify_line(outcome: String, gen: int, ms: int) -> String:
	return "V %s %d %d" % [outcome, gen, ms]


## Result keys: last_begun, last_done (both -1 if none), begun, done, tally (Dictionary outcome -> count), verifies, torn_lines.
static func parse(text: String) -> Dictionary:
	var out: Dictionary = {"last_begun": -1, "last_done": -1, "begun": 0, "done": 0,
		"tally": {"OK": 0, "FALLBACK": 0, "CORRUPT": 0, "NONE": 0}, "verifies": 0, "torn_lines": 0}
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line == "":
			continue
		var f: PackedStringArray = line.split(" ")
		if f[0] == "B" and f.size() == 3 and f[1].is_valid_int() and f[2].is_valid_int():
			out["last_begun"] = f[1].to_int()
			out["begun"] = int(out["begun"]) + 1
		elif f[0] == "D" and f.size() == 3 and f[1].is_valid_int() and f[2].is_valid_int():
			out["last_done"] = f[1].to_int()
			out["done"] = int(out["done"]) + 1
		elif f[0] == "V" and f.size() == 4 and OUTCOMES.has(f[1]) and f[2].is_valid_int() and f[3].is_valid_int():
			var tally: Dictionary = out["tally"]
			tally[f[1]] = int(tally[f[1]]) + 1
			out["verifies"] = int(out["verifies"]) + 1
		else:
			out["torn_lines"] = int(out["torn_lines"]) + 1
	return out


## True when `loaded_gen` is a generation the log allows for `outcome`.
## OK: the primary file must be the last finished save or the one that was in flight when the process died.
## FALLBACK: the primary was unusable; the backup must hold one of those two or the generation before them.
## NONE: allowed only if no save ever began. CORRUPT: never allowed.
static func judge(outcome: String, loaded_gen: int, parsed: Dictionary) -> bool:
	var last_done: int = int(parsed["last_done"])
	var last_begun: int = int(parsed["last_begun"])
	if outcome == "NONE":
		return last_begun < 0
	if outcome == "CORRUPT":
		return false
	if last_begun < 0:
		return false
	var g: int = loaded_gen % GEN_MOD
	var allowed: Array[int] = [last_done % GEN_MOD, last_begun % GEN_MOD]
	if outcome == "FALLBACK":
		allowed.append(maxi(last_done - 1, 0) % GEN_MOD)
	if last_done < 0 and outcome == "OK":
		allowed = [last_begun % GEN_MOD]
	return allowed.has(g)


static func tally_text(parsed: Dictionary) -> String:
	var t: Dictionary = parsed["tally"]
	return "verifies %d: OK %d, FALLBACK %d, CORRUPT %d, NONE %d   (saves begun %d, finished %d, in flight at last kill: %s)" % [
		int(parsed["verifies"]), int(t["OK"]), int(t["FALLBACK"]), int(t["CORRUPT"]), int(t["NONE"]),
		int(parsed["begun"]), int(parsed["done"]), "yes" if int(parsed["last_begun"]) != int(parsed["last_done"]) else "no"]
