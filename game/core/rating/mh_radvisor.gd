class_name MHRAdvisor
extends RefCounted
## Advisor reason codes (docs/spec/rating/rating-engine.md section 15): 66 codes, severity, and the
## triggers that can be evaluated from a rated hole or a rated course. Text generation lives elsewhere.
## Mirror of hole_codes / course_codes / top_codes in tools/reference/rating/rating_eng.py.
@warning_ignore_start("integer_division")

const SEV_INFO: int = 0
const SEV_WARN: int = 1
const SEV_SEVERE: int = 2
const SEV_BLOCK: int = 3

## code -> severity (3 BLOCK, 2 SEVERE, 1 WARN, 0 INFO). Lookup only, never iterated for results.
const SEVERITY: Dictionary = {
	"RC001": 3, "RC002": 3, "RC003": 3, "RC004": 3, "RC005": 3, "RC006": 3,
	"RC007": 3, "RC008": 3, "RC009": 1, "RC010": 0, "RC011": 1, "RC012": 0,
	"RC013": 1, "RC014": 2, "RC015": 2, "RC016": 0, "RC017": 0, "RC021": 2,
	"RC022": 1, "RC023": 2, "RC024": 1, "RC025": 1, "RC026": 1, "RC027": 2,
	"RC028": 2, "RC029": 0, "RC031": 2, "RC032": 1, "RC033": 0, "RC034": 1,
	"RC035": 2, "RC036": 1, "RC037": 1, "RC038": 0, "RC039": 0, "RC040": 1,
	"RC041": 1, "RC042": 0, "RC043": 0, "RC044": 0, "RC045": 1, "RC046": 2,
	"RC047": 0, "RC048": 0, "RC051": 1, "RC052": 0, "RC053": 0, "RC054": 1,
	"RC055": 0, "RC056": 0, "RC057": 0, "RC061": 1, "RC062": 0, "RC063": 1,
	"RC064": 1, "RC065": 2, "RC066": 0, "RC067": 0, "RC068": 1, "RC071": 0,
	"RC072": 0, "RC073": 3, "RC074": 0, "RC075": 1, "RC076": 1, "RC081": 0,
}


static func severity(code: String) -> int:
	return int(SEVERITY.get(code, 0))


static func _code_less(a: String, b: String) -> bool:
	var sa: int = severity(a)
	var sb: int = severity(b)
	if sa != sb:
		return sa > sb
	return a < b


## Highest severity first, then lowest code number; duplicates removed; at most `limit`.
static func top_codes(codes: Array, limit: int = 3) -> Array:
	var seen: Dictionary = {}
	var uniq: Array = []
	for c in codes:
		var cs: String = String(c)
		if not seen.has(cs):
			seen[cs] = true
			uniq.append(cs)
	uniq.sort_custom(func(a: String, b: String) -> bool: return MHRAdvisor._code_less(a, b))
	var out: Array = []
	for i in range(mini(limit, uniq.size())):
		out.append(uniq[i])
	return out


## Codes that fire for a rated, valid hole result (keys as produced by MHRatingEngine.rate_hole).
static func hole_codes(r: Dictionary) -> Array:
	var c: Array = []
	var L: int = int(r["L"])
	var par: int = int(r["par"])
	var means: Array = r["means"]
	var bm2: int = int(means[2])
	if L < 120:
		c.append("RC011")
	if L >= 120 and L < 150:
		c.append("RC012")
	if L >= 650 and L <= 700:
		c.append("RC013")
	if L > 700 and L < 850:
		c.append("RC014")
	if L >= 850:
		c.append("RC015")
	if absi(L - 260) <= 8 or absi(L - 470) <= 8:
		c.append("RC016")
	if int(r["Len"]) >= 950:
		c.append("RC017")
	var f: int = int(r["forced_pm"])
	var p: int = int(r["pickup_pm"])
	if f >= 300:
		c.append("RC021")
	elif f >= 100:
		c.append("RC022")
	if p >= 100:
		c.append("RC023")
	elif p >= 30:
		c.append("RC024")
	if int(r["tree_pm"]) >= 100:
		c.append("RC025")
	if int(r["over"]) > 0:
		c.append("RC026")
	if bm2 > par * 100 + 250:
		c.append("RC027")
	if int(r["raw_corr"]) == 0:
		c.append("RC028")
	if int(r["F"]) >= 950 and int(r["I"]) >= 400:
		c.append("RC029")
	var s: int = int(r["score_pm"])
	if s < 250:
		c.append("RC031")
	elif s < 400:
		c.append("RC032")
	if s >= 650:
		c.append("RC033")
	var pc: int = int(r["pace_pm"])
	if pc > 1150:
		c.append("RC034")
	if pc >= 1400:
		c.append("RC035")
	if int(r["spread"]) * 100 < 40 * int(r["T_par"]):
		c.append("RC036")
	if int(r["spread"]) > 2 * int(r["T_par"]):
		c.append("RC037")
	if int(r["inversions"]) >= 1:
		c.append("RC038")
	if int(r["A"]) >= 800:
		c.append("RC039")
	if int(r["A"]) < 300:
		c.append("RC040")
	var cm: int = int(r["comps"])
	var risk: int = int(r["risk_pm"])
	if int(r["I"]) < 100 and cm == 1:
		c.append("RC041")
	if cm == 2:
		c.append("RC042")
	if cm >= 3:
		c.append("RC043")
	if cm >= 2 and risk < 150:
		c.append("RC044")
	if risk > 500:
		c.append("RC045")
	if risk > 750:
		c.append("RC046")
	if par >= 4 and int(r["bend_s"]) == 0:
		c.append("RC047")
	if int(r["elev"]) == 0:
		c.append("RC048")
	if int(r["B"]) < 200:
		c.append("RC051")
	var nt: int = int(r["n_tree"])
	var raw_t: int = int(r["raw_trees"])
	if nt >= 60:
		c.append("RC052")
	if raw_t > 0 and raw_t * 2 >= nt * 3:
		c.append("RC053")
	if int(r["B_raw"]) > int(r["PQ"]) + 300:
		c.append("RC054")
	if int(r["cats"]) < 2:
		c.append("RC055")
	if int(r["wat"]) >= 60 and int(r["raw_corr"]) >= 1:
		c.append("RC056")
	if bool(r["stacked"]):
		c.append("RC057")
	return c


## Course level codes. ro needs: mean, low_third, invalid, tier, valid_non_dead, course_x10, similar_s (per hole
## best similarity), n. results are the per hole result dictionaries. Returns {per_hole: [[code, i]], course: [code]}.
static func course_codes(ro: Dictionary, results: Array, few_pars: bool) -> Dictionary:
	var per_hole: Array = []
	var sims: Array = ro["similar_s"]
	for i in range(int(ro["n"])):
		var sv: int = int(sims[i])
		if sv >= 850:
			per_hole.append(["RC061", i])
		elif sv > 700:
			per_hole.append(["RC062", i])
	var glob: Array = []
	if few_pars:
		glob.append("RC063")
	if int(ro["mean"]) - int(ro["low_third"]) >= 150:
		glob.append("RC064")
	if int(ro["invalid"]) > 0:
		glob.append("RC065")
	var nxt: int = int(ro["tier"]) + 1
	if nxt <= 5:
		if int(ro["valid_non_dead"]) < MHRParams.hole_gates[nxt - 2]:
			glob.append("RC066")
		if int(ro["course_x10"]) < MHRParams.score_gates[nxt - 2]:
			glob.append("RC067")
	var n_valid: int = 0
	var pace_sum: int = 0
	for r in results:
		if bool((r as Dictionary)["valid"]):
			n_valid += 1
			pace_sum += int((r as Dictionary)["pace_pm"])
	if n_valid > 0 and pace_sum / n_valid > 1150:
		glob.append("RC068")
	return {"per_hole": per_hole, "course": glob}
