"""Relief (elevation) fixtures shared by gen_golden.py and checks."""
import copy


def grid(x0, y0, step, cols, rows, fn):
    return dict(x0=x0, y0=y0, step=step, cols=cols, rows=rows,
                z=[int(fn(x0 + i * step, y0 + j * step)) for j in range(rows) for i in range(cols)])


BASE = {"slot_id": 51, "tee": [0, 0], "green": [0, 340, 14], "features": [
    {"t": "fairway", "rect": [-22, 0, 22, 330]}, {"t": "bunker", "circle": [-17, 325, 6]},
    {"t": "tree", "at": [[-35, 100], [35, 180], [-38, 260]]}, {"t": "flower", "count": 4}]}


def with_relief(name, fn, step=8):
    h = copy.deepcopy(BASE)
    h["relief"] = grid(-48, -16, step, 13 if step == 8 else 25, 46 if step == 8 else 90, fn)
    return h


def uphill(x, y):      # steady 6 m climb tee to green
    return y * 6000 // 340


def downhill(x, y):
    return 6000 - y * 6000 // 340


def hump(x, y):        # a 5 m hill in the middle, tee and green level
    d = abs(y - 170)
    return max(0, 5000 - d * 5000 // 90)


def sidehill(x, y):    # cross slope 8% plus gentle rise
    return x * 75 + y * 4


def green_tilt(x, y):  # flat fairway, green tilted 6%
    return max(0, y - 320) * 55 + (x * 55 if y > 320 else 0) + 1000


HOLES = {"uphill": uphill, "downhill": downhill, "hump": hump, "sidehill": sidehill, "green_tilt": green_tilt}


def fixtures():
    out = {}
    for k, f in HOLES.items():
        out[k] = with_relief(k, f)
    out["uphill_step2"] = with_relief("u2", uphill, step=2) if False else out["uphill"]
    flat = copy.deepcopy(BASE)
    out["flat"] = flat
    return out
