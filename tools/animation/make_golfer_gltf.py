#!/usr/bin/env python3
"""Generate a low-poly stylised golfer as glTF 2.0 (.gltf + .bin), pure Python stdlib.

Mulligan Hills, workstream G (animation).

What it writes
  - One skinned mesh (about 800 to 1500 triangles) with flat toon vertex colours (COLOR_0).
  - A humanoid skeleton using Godot SkeletonProfileHumanoid bone names, in a T-pose rest pose
    (all rest rotations are identity, so a bone's local rotation equals its pose delta).
  - Variants (skin, hair style and colour, headwear, shirt, sleeves, shorts or trousers,
    shoes, glove, build) chosen by --seed.

Coordinate system: glTF, right handed, +Y up, character faces +Z, character's LEFT is +X.
Units: metres. Height about 1.85 m with a big head (stylised, chunky).

Usage
  python3 make_golfer_gltf.py                       # writes game/characters/golfer_placeholder.gltf/.bin
  python3 make_golfer_gltf.py --seed 7 --name golfer_seed7 --out-dir /tmp/x
  python3 make_golfer_gltf.py --validate path/to/file.gltf
  python3 make_golfer_gltf.py --obj                 # also writes a T-pose .obj (for Mixamo upload)

Status: run and structurally validated with Python here. NOT imported into Godot (NOT YET RUN in engine).
"""
from __future__ import annotations

import argparse
import json
import math
import os
import random
import struct
import sys

# ----------------------------------------------------------------------------
# Skeleton
# ----------------------------------------------------------------------------

# (name, parent, world rest position for the LEFT/centre version). Right side mirrors x.
CENTRE_BONES = [
    ("Root", None, (0.0, 0.0, 0.0)),
    ("Hips", "Root", (0.0, 0.92, 0.0)),
    ("Spine", "Hips", (0.0, 1.04, 0.0)),
    ("Chest", "Spine", (0.0, 1.20, 0.0)),
    ("UpperChest", "Chest", (0.0, 1.34, 0.0)),
    ("Neck", "UpperChest", (0.0, 1.52, 0.0)),
    ("Head", "Neck", (0.0, 1.60, 0.0)),
]
SIDE_BONES = [  # (suffix, parent suffix or centre parent, left world position)
    ("Shoulder", "UpperChest", (0.07, 1.44, 0.0)),
    ("UpperArm", "Shoulder", (0.20, 1.44, 0.0)),
    ("LowerArm", "UpperArm", (0.46, 1.44, 0.0)),
    ("Hand", "LowerArm", (0.70, 1.44, 0.0)),
    ("UpperLeg", "Hips", (0.10, 0.90, 0.0)),
    ("LowerLeg", "UpperLeg", (0.10, 0.48, 0.0)),
    ("Foot", "LowerLeg", (0.10, 0.09, -0.02)),
    ("Toes", "Foot", (0.10, 0.03, 0.11)),
]

REQUIRED_GODOT_BONES = [
    "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
] + [s + n for s in ("Left", "Right") for n in
     ("Shoulder", "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot", "Toes")]


def build_skeleton(height_scale: float):
    """Return (names, parents(index), world positions) with Root first."""
    names, parent_names, pos = [], [], []
    for n, p, w in CENTRE_BONES:
        names.append(n)
        parent_names.append(p)
        pos.append(tuple(c * height_scale for c in w))
    for side, sign in (("Left", 1.0), ("Right", -1.0)):
        for n, p, w in SIDE_BONES:
            names.append(side + n)
            parent_names.append(p if p in ("UpperChest", "Hips") else side + p)
            pos.append((w[0] * sign * height_scale, w[1] * height_scale, w[2] * height_scale))
    parents = [(-1 if p is None else names.index(p)) for p in parent_names]
    return names, parents, pos


# ----------------------------------------------------------------------------
# Small vector helpers
# ----------------------------------------------------------------------------

def vsub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def vadd(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def vmul(a, s): return (a[0] * s, a[1] * s, a[2] * s)
def vdot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def vcross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def vlen(a): return math.sqrt(vdot(a, a))
def vnorm(a):
    l = vlen(a)
    return (0.0, 0.0, 0.0) if l == 0 else (a[0] / l, a[1] / l, a[2] / l)


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h: str):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1.0)


# ----------------------------------------------------------------------------
# Mesh builder
# ----------------------------------------------------------------------------

class Mesh:
    def __init__(self):
        self.pos = []      # (x,y,z)
        self.col = []      # (r,g,b,a) linear
        self.joints = []   # 4 ints
        self.weights = []  # 4 floats
        self.tris = []     # (i,j,k)

    def add_vertex(self, p, c, w):
        """w: dict bone_index -> weight. Keeps 4 largest, normalises to sum 1."""
        items = sorted(((b, x) for b, x in w.items() if x > 0), key=lambda t: -t[1])[:4]
        s = sum(x for _, x in items)
        items = [(b, x / s) for b, x in items]
        while len(items) < 4:
            items.append((0, 0.0))
        self.pos.append(p)
        self.col.append(c)
        self.joints.append([b for b, _ in items])
        self.weights.append([x for _, x in items])
        return len(self.pos) - 1


def _basis_for_axis(d):
    """u, v with u x v = d. For d=+Y: u=-X, v=+Z. For d=+Z: u=+X, v=+Y. For d=+-X: v=+Y."""
    h = (0.0, 0.0, 1.0) if abs(d[1]) > 0.9 else (0.0, 1.0, 0.0)
    u = vnorm(vcross(h, d))
    v = vcross(d, u)
    return u, v


def _lerp(a, b, t): return a + (b - a) * t


def _lerp_w(wa, wb, t):
    out = {}
    for k in set(wa) | set(wb):
        out[k] = _lerp(wa.get(k, 0.0), wb.get(k, 0.0), t)
    return out


def add_tube(mesh: Mesh, a, b, rings, zones, sides=8, cap_start=True, cap_end=True):
    """Add a tapered elliptical tube from point a to point b.

    rings: list of (t, r_u, r_v, weights_dict) with t ascending in [0,1].
    zones: list of (t_upper, colour); the colour of a ring is the zone containing the surface
           just below it. A hard colour edge inserts a duplicated ring (so colours stay flat).
    Winding: counter-clockwise seen from outside (glTF front faces).
    """
    a = tuple(a); b = tuple(b)
    d = vnorm(vsub(b, a))
    u, v = _basis_for_axis(d)

    def ring_params(t):
        # linear interpolation in the base ring list
        for i in range(len(rings) - 1):
            t0, t1 = rings[i][0], rings[i + 1][0]
            if t0 <= t <= t1:
                f = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
                return (_lerp(rings[i][1], rings[i + 1][1], f), _lerp(rings[i][2], rings[i + 1][2], f),
                        _lerp_w(rings[i][3], rings[i + 1][3], f))
        r = rings[0] if t < rings[0][0] else rings[-1]
        return r[1], r[2], r[3]

    # Expand into concrete rings: (t, ru, rv, weights, colour). Split at zone edges.
    conc = []
    zone_start = 0.0
    for zi, (zt, zc) in enumerate(zones):
        ts = {zone_start, zt}
        for rt, *_ in rings:
            if zone_start < rt < zt:
                ts.add(rt)
        for t in sorted(ts):
            ru, rv, w = ring_params(t)
            conc.append((t, ru, rv, w, zc))
        zone_start = zt
    # conc has duplicate t at zone edges: (t, colour of lower zone) then (t, colour of upper zone)

    ring_idx = []
    for (t, ru, rv, w, c) in conc:
        c0 = vadd(a, vmul(vsub(b, a), t))
        idx = []
        for k in range(sides):
            th = 2.0 * math.pi * k / sides
            p = vadd(c0, vadd(vmul(u, ru * math.cos(th)), vmul(v, rv * math.sin(th))))
            idx.append(mesh.add_vertex(p, c, w))
        ring_idx.append((t, idx))

    for i in range(len(ring_idx) - 1):
        (t0, r0), (t1, r1) = ring_idx[i], ring_idx[i + 1]
        if t1 == t0:
            continue  # colour seam, no geometry
        for k in range(sides):
            k2 = (k + 1) % sides
            mesh.tris.append((r0[k], r0[k2], r1[k2]))
            mesh.tris.append((r0[k], r1[k2], r1[k]))

    def cap(ring_i, top):
        t, idx = ring_idx[ring_i]
        _, ru, rv, w, c = conc[ring_i]
        cen = mesh.add_vertex(vadd(a, vmul(vsub(b, a), t)), c, w)
        for k in range(sides):
            k2 = (k + 1) % sides
            if top:
                mesh.tris.append((cen, idx[k], idx[k2]))
            else:
                mesh.tris.append((cen, idx[k2], idx[k]))
    if cap_end:
        cap(len(ring_idx) - 1, True)
    if cap_start:
        cap(0, False)


# ----------------------------------------------------------------------------
# Palette and variants
# ----------------------------------------------------------------------------

SKIN = ["#f2c9a5", "#e0a97e", "#c68863", "#a5694a", "#7d4a33", "#f6d6bd"]
HAIR = ["#2b1d14", "#5a3a22", "#a8703a", "#d9b25f", "#8c8c8c", "#b5462c", "#1c1c1f"]
SHIRT = ["#f4f1ea", "#d9483b", "#2f8f83", "#f0c23b", "#2c4a8a", "#e58aa5", "#5aa552", "#e8792b"]
PANTS = ["#3b4252", "#c9b48a", "#f4f1ea", "#5a6b4a", "#2c4a8a", "#8a8f99"]
SHOES = ["#f4f1ea", "#2b2b30", "#8a5a3a", "#c9b48a"]
SOCK = "#f4f1ea"
GLOVE = "#f4f1ea"

HAIR_STYLES = ["short", "ponytail", "bun", "bald", "short"]
HEADWEAR = ["none", "cap", "visor", "none", "cap", "bucket"]


def pick_variant(seed: int) -> dict:
    r = random.Random(seed)
    v = {
        "seed": seed,
        "skin": r.choice(SKIN),
        "hair": r.choice(HAIR),
        "hair_style": r.choice(HAIR_STYLES),
        "headwear": r.choice(HEADWEAR),
        "headwear_col": r.choice(SHIRT),
        "shirt": r.choice(SHIRT),
        "sleeves": r.choice(["short", "short", "long"]),
        "bottoms": r.choice(["trousers", "shorts", "shorts"]),
        "pants": r.choice(PANTS),
        "shoes": r.choice(SHOES),
        "glove": r.choice([True, True, False]),
        "height_scale": round(r.uniform(0.95, 1.05), 3),
        "girth": round(r.uniform(0.9, 1.15), 3),
    }
    return v


# ----------------------------------------------------------------------------
# Body construction
# ----------------------------------------------------------------------------

def build_character(variant: dict):
    hs = variant["height_scale"]
    g = variant["girth"]
    names, parents, jpos = build_skeleton(hs)
    bi = {n: i for i, n in enumerate(names)}
    P = {n: jpos[i] for n, i in bi.items()}
    skin = hexcol(variant["skin"])
    shirt = hexcol(variant["shirt"])
    pants = hexcol(variant["pants"])
    shoe = hexcol(variant["shoes"])
    sock = hexcol(SOCK)
    glove = hexcol(GLOVE)
    hair = hexcol(variant["hair"])
    hw = hexcol(variant["headwear_col"])
    m = Mesh()

    def S(p):  # scale a rest-space point (authored at height scale 1) to this build
        return (p[0] * hs, p[1] * hs, p[2] * hs)

    def w1(*pairs):
        return {bi[n]: x for n, x in pairs}

    def R(x):  # radius scale
        return x * g * hs

    # ---- torso ----
    add_tube(m, S((0, 0.86, 0)), S((0, 1.06, 0)),
             [(0.0, R(.150), R(.110), w1(("Hips", 1.0))),
              (1.0, R(.150), R(.110), w1(("Hips", .5), ("Spine", .5)))],
             [(1.0, pants)])
    add_tube(m, S((0, 1.06, 0)), S((0, 1.26, 0)),
             [(0.0, R(.150), R(.110), w1(("Hips", .5), ("Spine", .5))),
              (0.5, R(.145), R(.105), w1(("Spine", 1.0))),
              (1.0, R(.152), R(.112), w1(("Spine", .5), ("Chest", .5)))],
             [(1.0, shirt)], cap_start=False)
    add_tube(m, S((0, 1.26, 0)), S((0, 1.50, 0)),
             [(0.0, R(.152), R(.112), w1(("Spine", .5), ("Chest", .5))),
              (0.30, R(.165), R(.118), w1(("Chest", 1.0))),
              (0.65, R(.185), R(.120), w1(("UpperChest", 1.0))),
              (0.88, R(.160), R(.105), w1(("UpperChest", .7), ("Neck", .3))),
              (1.0, R(.075), R(.070), w1(("Neck", 1.0)))],
             [(0.97, shirt), (1.0, skin)], cap_start=False)
    # neck
    add_tube(m, S((0, 1.48, 0)), S((0, 1.64, 0)),
             [(0.0, R(.062), R(.062), w1(("Neck", 1.0))),
              (1.0, R(.060), R(.060), w1(("Neck", .5), ("Head", .5)))],
             [(1.0, skin)], cap_start=False, cap_end=False)

    # ---- head (sphere-ish profile) ----
    head_a, head_b = 1.60, 1.86
    prof = [(0.0, .030), (0.10, .092), (0.28, .132), (0.50, .146), (0.72, .136), (0.90, .098), (1.0, .020)]
    hw_head = w1(("Head", 1.0))

    def head_r(y):  # head radius at absolute y (build scale 1 space)
        t = (y - head_a) / (head_b - head_a)
        t = min(1.0, max(0.0, t))
        for i in range(len(prof) - 1):
            if prof[i][0] <= t <= prof[i + 1][0]:
                f = (t - prof[i][0]) / (prof[i + 1][0] - prof[i][0])
                return _lerp(prof[i][1], prof[i + 1][1], f)
        return prof[-1][1]

    add_tube(m, S((0, head_a, 0)), S((0, head_b, 0)),
             [(t, R(r), R(r * 0.98), w1(("Head", 1.0))) for t, r in prof],
             [(1.0, skin)], sides=10)

    def hair_shell(y0, y1, colour, grow=1.10, back_only=False):
        ring = []
        n = 4
        for i in range(n + 1):
            y = _lerp(y0, y1, i / n)
            r = head_r(y) * grow + 0.004
            ring.append((i / n, R(r), R(r), hw_head))
        add_tube(m, S((0, y0, 0)), S((0, y1, 0)), ring, [(1.0, colour)], sides=10, cap_start=False)

    style = variant["hair_style"]
    wear = variant["headwear"]
    if wear in ("cap", "bucket"):
        hair_shell(1.755, 1.875, hw, 1.12)
    elif wear == "visor":
        pass
    if style in ("short", "ponytail", "bun") and wear not in ("cap", "bucket"):
        hair_shell(1.745, 1.875, hair, 1.10)
    if wear == "visor":
        # headband ring
        hair_shell(1.775, 1.815, hw, 1.13)
        hair_shell(1.815, 1.875, hair, 1.10) if style != "bald" else None
    if style == "ponytail":
        add_tube(m, S((0, 1.78, -0.13)), S((0, 1.52, -0.20)),
                 [(0.0, R(.045), R(.045), hw_head), (0.3, R(.055), R(.055), hw_head),
                  (1.0, R(.028), R(.028), hw_head)],
                 [(1.0, hair)], sides=6)
    elif style == "bun" and wear not in ("cap", "bucket"):
        add_tube(m, S((0, 1.86, -0.05)), S((0, 1.97, -0.05)),
                 [(0.0, R(.05), R(.05), hw_head), (0.5, R(.07), R(.07), hw_head), (1.0, R(.02), R(.02), hw_head)],
                 [(1.0, hair)], sides=8)
    if wear in ("cap", "visor"):
        add_tube(m, S((0, 1.80, 0.10)), S((0, 1.80, 0.29)),
                 [(0.0, R(.115), R(.010), hw_head), (1.0, R(.085), R(.008), hw_head)],
                 [(1.0, hw)], sides=8)
    if wear == "bucket":
        add_tube(m, S((0, 1.765, 0)), S((0, 1.775, 0)),
                 [(0.0, R(.215), R(.215), hw_head), (1.0, R(.215), R(.215), hw_head)],
                 [(1.0, hw)], sides=10)

    # ---- arms, legs ----
    long_sleeves = variant["sleeves"] == "long"
    shorts = variant["bottoms"] == "shorts"
    for side, sgn in (("Left", 1.0), ("Right", -1.0)):
        sh, ua, la, ha = P[side + "Shoulder"], P[side + "UpperArm"], P[side + "LowerArm"], P[side + "Hand"]
        # upper arm
        add_tube(m, ua, la,
                 [(0.0, R(.072), R(.072), w1((side + "Shoulder", .5), (side + "UpperArm", .5))),
                  (0.25, R(.068), R(.068), w1((side + "UpperArm", 1.0))),
                  (0.75, R(.058), R(.058), w1((side + "UpperArm", 1.0))),
                  (1.0, R(.055), R(.055), w1((side + "UpperArm", .5), (side + "LowerArm", .5)))],
                 [(0.60, shirt), (1.0, shirt if long_sleeves else skin)], cap_start=False)
        # lower arm
        add_tube(m, la, ha,
                 [(0.0, R(.052), R(.052), w1((side + "UpperArm", .5), (side + "LowerArm", .5))),
                  (0.3, R(.050), R(.050), w1((side + "LowerArm", 1.0))),
                  (1.0, R(.038), R(.038), w1((side + "LowerArm", .6), (side + "Hand", .4)))],
                 [(1.0, shirt if long_sleeves else skin)], cap_start=False)
        # hand (glove on the left hand for a right-handed golfer)
        hc = glove if (variant["glove"] and side == "Left") else skin
        tip = (ha[0] + sgn * 0.11 * hs, ha[1] - 0.01 * hs, ha[2] + 0.0)
        add_tube(m, ha, tip,
                 [(0.0, R(.040), R(.030), w1((side + "Hand", 1.0))),
                  (0.5, R(.046), R(.032), w1((side + "Hand", 1.0))),
                  (1.0, R(.030), R(.022), w1((side + "Hand", 1.0)))],
                 [(1.0, hc)], cap_start=False)
        # legs
        ul, ll, ft, ts = P[side + "UpperLeg"], P[side + "LowerLeg"], P[side + "Foot"], P[side + "Toes"]
        upper_zones = [(0.62, pants), (1.0, skin)] if shorts else [(1.0, pants)]
        add_tube(m, ul, ll,
                 [(0.0, R(.092), R(.092), w1(("Hips", .5), (side + "UpperLeg", .5))),
                  (0.30, R(.088), R(.088), w1((side + "UpperLeg", 1.0))),
                  (0.75, R(.070), R(.070), w1((side + "UpperLeg", 1.0))),
                  (1.0, R(.064), R(.064), w1((side + "UpperLeg", .5), (side + "LowerLeg", .5)))],
                 upper_zones, cap_start=False)
        lower_end = (ll[0], 0.10 * hs, ll[2])
        lower_zones = [(0.55, skin), (1.0, sock)] if shorts else [(1.0, pants)]
        add_tube(m, ll, lower_end,
                 [(0.0, R(.062), R(.062), w1((side + "UpperLeg", .5), (side + "LowerLeg", .5))),
                  (0.30, R(.060), R(.060), w1((side + "LowerLeg", 1.0))),
                  (1.0, R(.046), R(.046), w1((side + "LowerLeg", .7), (side + "Foot", .3)))],
                 lower_zones, cap_start=False)
        # foot: tube along +Z
        fy = 0.050 * hs
        add_tube(m, (ft[0], fy, ft[2] - 0.06 * hs), (ft[0], fy, ft[2] + 0.24 * hs),
                 [(0.0, R(.048), R(.046), w1((side + "Foot", 1.0))),
                  (0.45, R(.055), R(.048), w1((side + "Foot", 1.0))),
                  (0.75, R(.056), R(.040), w1((side + "Foot", .5), (side + "Toes", .5))),
                  (1.0, R(.046), R(.028), w1((side + "Toes", 1.0)))],
                 [(1.0, shoe)], sides=8)

    return m, names, parents, jpos


# ----------------------------------------------------------------------------
# glTF writer
# ----------------------------------------------------------------------------

def compute_normals(mesh: Mesh):
    n = [[0.0, 0.0, 0.0] for _ in mesh.pos]
    for (i, j, k) in mesh.tris:
        e1 = vsub(mesh.pos[j], mesh.pos[i])
        e2 = vsub(mesh.pos[k], mesh.pos[i])
        fn = vcross(e1, e2)  # area weighted
        for idx in (i, j, k):
            n[idx][0] += fn[0]; n[idx][1] += fn[1]; n[idx][2] += fn[2]
    out = []
    for v in n:
        l = vnorm(tuple(v))
        out.append(l if vlen(l) > 0 else (0.0, 1.0, 0.0))
    return out


def pad4(b: bytearray):
    while len(b) % 4:
        b.append(0)


def write_gltf(out_dir: str, name: str, variant: dict):
    mesh, names, parents, jpos = build_character(variant)
    normals = compute_normals(mesh)
    nv = len(mesh.pos)

    buf = bytearray()
    views, accessors = [], []

    def add_view(data: bytes, target=None):
        pad4(buf)
        off = len(buf)
        buf.extend(data)
        vw = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            vw["target"] = target
        views.append(vw)
        return len(views) - 1

    def add_acc(view, ctype, count, atype, mn=None, mx=None):
        a = {"bufferView": view, "componentType": ctype, "count": count, "type": atype}
        if mn is not None:
            a["min"], a["max"] = mn, mx
        accessors.append(a)
        return len(accessors) - 1

    pos_b = b"".join(struct.pack("<3f", *p) for p in mesh.pos)
    a_pos = add_acc(add_view(pos_b, 34962), 5126, nv, "VEC3",
                    [min(p[i] for p in mesh.pos) for i in range(3)],
                    [max(p[i] for p in mesh.pos) for i in range(3)])
    a_nrm = add_acc(add_view(b"".join(struct.pack("<3f", *n) for n in normals), 34962), 5126, nv, "VEC3")
    a_col = add_acc(add_view(b"".join(struct.pack("<4f", *c) for c in mesh.col), 34962), 5126, nv, "VEC4")
    a_jnt = add_acc(add_view(b"".join(struct.pack("<4B", *j) for j in mesh.joints), 34962), 5121, nv, "VEC4")
    a_wgt = add_acc(add_view(b"".join(struct.pack("<4f", *w) for w in mesh.weights), 34962), 5126, nv, "VEC4")
    flat = [i for t in mesh.tris for i in t]
    assert max(flat) < 65535
    a_idx = add_acc(add_view(struct.pack("<%dH" % len(flat), *flat), 34963), 5123, len(flat), "SCALAR")
    # inverse bind matrices: rest pose has identity rotation, so IBM = translate(-world position). Column major.
    ibm = bytearray()
    for p in jpos:
        ibm += struct.pack("<16f", 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -p[0], -p[1], -p[2], 1)
    a_ibm = add_acc(add_view(bytes(ibm)), 5126, len(names), "MAT4")
    pad4(buf)

    nodes = []
    for i, n in enumerate(names):
        loc = jpos[i] if parents[i] < 0 else vsub(jpos[i], jpos[parents[i]])
        nd = {"name": n, "translation": [round(c, 6) for c in loc]}
        kids = [j for j, p in enumerate(parents) if p == i]
        if kids:
            nd["children"] = kids
        nodes.append(nd)
    mesh_node = len(nodes)
    nodes.append({"name": "GolferMesh", "mesh": 0, "skin": 0})

    tri_count = len(mesh.tris)
    gltf = {
        "asset": {"version": "2.0", "generator": "mulligan-hills make_golfer_gltf.py",
                  "extras": {"variant": variant, "triangles": tri_count, "vertices": nv}},
        "scene": 0,
        "scenes": [{"name": "Golfer", "nodes": [0, mesh_node]}],
        "nodes": nodes,
        "skins": [{"name": "GolferSkin", "inverseBindMatrices": a_ibm, "skeleton": 0,
                   "joints": list(range(len(names)))}],
        "meshes": [{"name": "GolferMesh", "primitives": [{
            "attributes": {"POSITION": a_pos, "NORMAL": a_nrm, "COLOR_0": a_col,
                           "JOINTS_0": a_jnt, "WEIGHTS_0": a_wgt},
            "indices": a_idx, "material": 0, "mode": 4}]}],
        "materials": [{"name": "ToonVertexColour",
                       "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0,
                                                "roughnessFactor": 1.0},
                       "doubleSided": False}],
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"uri": name + ".bin", "byteLength": len(buf)}],
    }
    os.makedirs(out_dir, exist_ok=True)
    gpath = os.path.join(out_dir, name + ".gltf")
    with open(os.path.join(out_dir, name + ".bin"), "wb") as f:
        f.write(bytes(buf))
    with open(gpath, "w") as f:
        json.dump(gltf, f, indent=1)
    return gpath, mesh, names, jpos


def write_obj(path: str, mesh: Mesh):
    """Static T-pose OBJ (positions and normals only) for uploading to Mixamo's auto-rigger."""
    normals = compute_normals(mesh)
    with open(path, "w") as f:
        f.write("# Mulligan Hills placeholder golfer, T-pose, metres, +Y up, faces +Z\n")
        f.write("o golfer\n")
        for p in mesh.pos:
            f.write("v %.5f %.5f %.5f\n" % p)
        for n in normals:
            f.write("vn %.4f %.4f %.4f\n" % n)
        for (i, j, k) in mesh.tris:
            f.write("f %d//%d %d//%d %d//%d\n" % (i + 1, i + 1, j + 1, j + 1, k + 1, k + 1))


# ----------------------------------------------------------------------------
# Structural validation (reads the written files back; independent of the builder)
# ----------------------------------------------------------------------------

COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
TYPES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}


def validate(gltf_path: str, tri_range=(800, 1500)) -> list:
    """Return list of error strings (empty = pass). Prints nothing."""
    errs = []
    try:
        with open(gltf_path) as f:
            g = json.load(f)
    except Exception as e:  # noqa
        return ["cannot read json: %s" % e]
    base = os.path.dirname(gltf_path)
    if g.get("asset", {}).get("version") != "2.0":
        errs.append("asset.version != 2.0")
    for key in ("buffers", "bufferViews", "accessors", "nodes", "meshes", "skins", "scenes"):
        if key not in g:
            errs.append("missing " + key)
    if errs:
        return errs
    binb = open(os.path.join(base, g["buffers"][0]["uri"]), "rb").read()
    if len(binb) != g["buffers"][0]["byteLength"]:
        errs.append("bin size %d != buffer.byteLength %d" % (len(binb), g["buffers"][0]["byteLength"]))
    for i, v in enumerate(g["bufferViews"]):
        if v["byteOffset"] + v["byteLength"] > len(binb):
            errs.append("bufferView %d out of range" % i)
        if v["byteOffset"] % 4:
            errs.append("bufferView %d misaligned" % i)

    def read(ai):
        a = g["accessors"][ai]
        fmt, size = COMP[a["componentType"]]
        n = TYPES[a["type"]]
        v = g["bufferViews"][a["bufferView"]]
        need = a["count"] * n * size
        if a.get("byteOffset", 0) + need > v["byteLength"]:
            errs.append("accessor %d exceeds its bufferView" % ai)
            return []
        off = v["byteOffset"] + a.get("byteOffset", 0)
        if off + need > len(binb):
            errs.append("accessor %d reads past end of .bin" % ai)
            return []
        flat = struct.unpack_from("<%d%s" % (a["count"] * n, fmt), binb, off)
        return [flat[i * n:(i + 1) * n] for i in range(a["count"])]

    prim = g["meshes"][0]["primitives"][0]
    at = prim["attributes"]
    P = read(at["POSITION"]); N = read(at["NORMAL"]); C = read(at["COLOR_0"])
    J = read(at["JOINTS_0"]); W = read(at["WEIGHTS_0"]); I = read(prim["indices"])
    if errs:
        return errs
    nv = len(P)
    for nm, arr in (("NORMAL", N), ("COLOR_0", C), ("JOINTS_0", J), ("WEIGHTS_0", W)):
        if len(arr) != nv:
            errs.append("%s count %d != POSITION count %d" % (nm, len(arr), nv))
    a = g["accessors"][at["POSITION"]]
    for ax in range(3):
        lo = min(p[ax] for p in P); hi = max(p[ax] for p in P)
        if abs(lo - a["min"][ax]) > 1e-5 or abs(hi - a["max"][ax]) > 1e-5:
            errs.append("POSITION min/max mismatch on axis %d" % ax)
    if any(math.isnan(c) or math.isinf(c) for p in P for c in p):
        errs.append("NaN/inf in positions")
    flat = [i[0] for i in I]
    if len(flat) % 3:
        errs.append("index count not multiple of 3")
    if flat and max(flat) >= nv:
        errs.append("index out of range")
    tris = [tuple(flat[i:i + 3]) for i in range(0, len(flat), 3)]
    if not (tri_range[0] <= len(tris) <= tri_range[1]):
        errs.append("triangle count %d outside %s" % (len(tris), tri_range))
    degenerate = 0
    volume = 0.0
    for (i, j, k) in tris:
        cr = vcross(vsub(P[j], P[i]), vsub(P[k], P[i]))
        if vlen(cr) < 1e-12:
            degenerate += 1
        volume += vdot(P[i], vcross(P[j], P[k])) / 6.0
    if degenerate:
        errs.append("%d degenerate triangles" % degenerate)
    if volume <= 0:
        errs.append("signed volume %.5f <= 0 (winding looks inverted)" % volume)
    # skin
    skin = g["skins"][0]
    nj = len(skin["joints"])
    for vi in range(nv):
        s = sum(W[vi])
        if abs(s - 1.0) > 1e-4:
            errs.append("vertex %d weights sum %.6f" % (vi, s)); break
        if any(w < 0 for w in W[vi]):
            errs.append("negative weight at vertex %d" % vi); break
        for jj, w in zip(J[vi], W[vi]):
            if w > 0 and jj >= nj:
                errs.append("joint index out of range at vertex %d" % vi); break
    if any(abs(vlen(n) - 1.0) > 1e-3 for n in N):
        errs.append("non-unit normals")
    if any(not (0.0 <= c <= 1.0) for col in C for c in col):
        errs.append("vertex colour out of [0,1]")
    # node graph
    nodes = g["nodes"]
    parent = {}
    for i, nd in enumerate(nodes):
        for c in nd.get("children", []):
            if c in parent:
                errs.append("node %d has two parents" % c)
            parent[c] = i
    for i in range(len(nodes)):
        seen, cur = set(), i
        while cur in parent:
            if cur in seen:
                errs.append("cycle in node graph"); break
            seen.add(cur); cur = parent[cur]
    jn = [nodes[j]["name"] for j in skin["joints"]]
    if len(set(jn)) != len(jn):
        errs.append("duplicate joint names")
    missing = [b for b in REQUIRED_GODOT_BONES if b not in jn]
    if missing:
        errs.append("missing Godot humanoid bones: %s" % missing)
    # IBM check
    ibm = read(skin["inverseBindMatrices"])
    if len(ibm) != nj:
        errs.append("IBM count %d != joints %d" % (len(ibm), nj))
    else:
        def world(i):
            t = list(nodes[i]["translation"])
            while i in parent:
                i = parent[i]
                pt = nodes[i]["translation"]
                t = [t[k] + pt[k] for k in range(3)]
            return t
        for k, j in enumerate(skin["joints"]):
            wpos = world(j)
            m = ibm[k]
            if any(abs(m[12 + a2] + wpos[a2]) > 1e-4 for a2 in range(3)):
                errs.append("IBM mismatch for joint %s" % nodes[j]["name"]); break
    # every skinned-to bone actually exists / left-right symmetry of mesh extents
    used = set(jj for vi in range(nv) for jj, w in zip(J[vi], W[vi]) if w > 0)
    unused = [jn[k] for k in range(nj) if k not in used]
    if unused and set(unused) != {"Root"}:
        errs.append("bones with no skin influence (other than Root): %s" % unused)
    return errs


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--name", default="golfer_placeholder")
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--out-dir", default=os.path.normpath(os.path.join(here, "..", "..", "game", "characters")))
    ap.add_argument("--validate", metavar="GLTF", help="only validate an existing file")
    ap.add_argument("--obj", action="store_true", help="also write <name>_tpose.obj into <out-dir>/mixamo_test/upload/")
    args = ap.parse_args(argv)
    if args.validate:
        errs = validate(args.validate)
        print("OK" if not errs else "\n".join(errs))
        return 1 if errs else 0
    variant = pick_variant(args.seed)
    gpath, mesh, names, jpos = write_gltf(args.out_dir, args.name, variant)
    print("wrote", gpath, "triangles=%d vertices=%d bones=%d" % (len(mesh.tris), len(mesh.pos), len(names)))
    print("variant", json.dumps(variant))
    if args.obj:
        d = os.path.join(args.out_dir, "mixamo_test", "upload")
        os.makedirs(d, exist_ok=True)
        write_obj(os.path.join(d, args.name + "_tpose.obj"), mesh)
        print("wrote obj in", d)
    errs = validate(gpath)
    if errs:
        print("VALIDATION FAILED:\n" + "\n".join(errs))
        return 1
    print("validation: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
