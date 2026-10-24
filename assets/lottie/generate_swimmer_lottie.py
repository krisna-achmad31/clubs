"""Generator animasi Lottie karakter perenang Klubby (5 tahap evolusi streak).

Jalankan:  python generate_swimmer_lottie.py
Output   :  swimmer_day1_pemula.json ... swimmer_day30_legend.json
            swimmer_streak_evolution.json (gabungan, dengan marker per tahap)
"""
import json
import math
import os

FR = 60
LOOP = 120  # 2 detik per loop, semua periode animasi harus membagi angka ini
W, H = 500, 400
# Gaya Duolingo: tanpa outline gelap, warna flat cerah, shading pakai warna senada yang lebih gelap
OUTLINE = "#2D2A4A"   # hanya dipakai sebagai penanda; stroke outline pada shape berisi fill dibuang di grp()
INK = "#4B4B4B"       # garis wajah (mulut/mata)
SKIN = "#FFC8A2"
SKIN_DARK = "#F0A57E"
HAIR = "#FFC800"
HAIR_DARK = "#E5A800"
WATER = "#49C0F8"
WATER_FRONT = "#A5E4FF"

# ---------------------------------------------------------------- helpers


def rgba(hexstr, a=1.0):
    h = hexstr.lstrip("#")
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)] + [a]


def st(v):
    return {"a": 0, "k": v}


def _dims(v):
    if isinstance(v, (int, float)):
        return 1
    if isinstance(v, dict):
        return 1
    return len(v)


def _wrap(v):
    return v if isinstance(v, list) else [v]


def kf(t, v, ease="io", hold=False):
    d = {"t": t, "s": _wrap(v)}
    n = _dims(v)
    if hold:
        d["h"] = 1
    elif ease == "lin":
        d["o"] = {"x": [0.0] * n, "y": [0.0] * n}
        d["i"] = {"x": [1.0] * n, "y": [1.0] * n}
    elif ease == "out":
        d["o"] = {"x": [0.2] * n, "y": [0.8] * n}
        d["i"] = {"x": [0.4] * n, "y": [1.0] * n}
    elif ease == "in":   # makin cepat ke ujung (jatuh)
        d["o"] = {"x": [0.5] * n, "y": [0.0] * n}
        d["i"] = {"x": [0.9] * n, "y": [0.6] * n}
    else:
        d["o"] = {"x": [0.42] * n, "y": [0.0] * n}
        d["i"] = {"x": [0.58] * n, "y": [1.0] * n}
    return d


def anim(frames):
    """frames: list of (t, value[, ease]) ; last keyframe gets no easing."""
    ks = []
    for i, f in enumerate(frames):
        t, v = f[0], f[1]
        ease = f[2] if len(f) > 2 else "io"
        if i == len(frames) - 1:
            ks.append({"t": t, "s": _wrap(v)})
        else:
            ks.append(kf(t, v, ease=ease, hold=(ease == "hold")))
    return {"a": 1, "k": ks}


def osc(a, b, period, phase=0.0):
    """Ease in-out oscillation a<->b looping seamlessly over LOOP."""
    half = period / 2
    start = -phase * period
    frames = []
    t = start
    cur_a = True
    while t <= LOOP + period:
        frames.append((round(t, 3), a if cur_a else b, "io"))
        cur_a = not cur_a
        t += half
    return anim(frames)


def spin(r0, turns, direction=1):
    return anim([(0, r0, "lin"), (LOOP, r0 + 360 * turns * direction)])


def cyc(points, period, phase=0.0):
    """Sawtooth cycle. points: [(u, value), ...] with u in [0,1]; value at u=1
    is held one frame then jumps back to the u=0 value."""
    frames = []
    start = -phase * period - period
    k = 0
    while start + k * period <= LOOP + period:
        s = start + k * period
        for u, v in points[:-1]:
            frames.append((round(s + u * period, 3), v, "lin"))
        frames.append((round(s + period - 0.5, 3), points[-1][1], "hold"))
        k += 1
    return anim(frames)


def tr(p=(0, 0), a=(0, 0), s=(100, 100), r=0, o=100):
    def v(x):
        return x if isinstance(x, dict) else st(list(x) if isinstance(x, tuple) else x)
    return {"ty": "tr", "p": v(p), "a": v(a), "s": v(s), "r": v(r), "o": v(o),
            "sk": st(0), "sa": st(0), "nm": "Transform"}


def fill(c, o=100):
    return {"ty": "fl", "c": st(rgba(c)), "o": st(o) if not isinstance(o, dict) else o, "r": 1, "nm": "Fill"}


def stroke(c, w=3.5, o=100):
    return {"ty": "st", "c": st(rgba(c)), "o": st(o) if not isinstance(o, dict) else o,
            "w": st(w), "lc": 2, "lj": 2, "ml": 4, "nm": "Stroke"}


def ell(p, s):
    return {"ty": "el", "p": st(list(p)), "s": st(list(s)) if not isinstance(s, dict) else s, "d": 1, "nm": "Ellipse"}


def rect(p, s, r):
    return {"ty": "rc", "p": st(list(p)), "s": st(list(s)), "r": st(r), "d": 1, "nm": "Rect"}


def shape_data(pts, closed=True, smooth=0.0):
    """pts list of (x,y). smooth>0 makes catmull-rom style tangents."""
    n = len(pts)
    ins, outs = [], []
    for i in range(n):
        if smooth and (closed or 0 < i < n - 1):
            p0 = pts[(i - 1) % n]
            p2 = pts[(i + 1) % n]
            dx, dy = (p2[0] - p0[0]) * smooth, (p2[1] - p0[1]) * smooth
            ins.append([-dx, -dy])
            outs.append([dx, dy])
        else:
            ins.append([0, 0])
            outs.append([0, 0])
    return {"i": ins, "o": outs, "v": [list(p) for p in pts], "c": closed}


def path(pts, closed=True, smooth=0.0):
    return {"ty": "sh", "ks": st(shape_data(pts, closed, smooth)), "nm": "Path"}


def path_anim(frames_pts, closed=True, smooth=0.0):
    """frames_pts: list of (t, pts, ease)."""
    ks = []
    for i, (t, pts, ease) in enumerate(frames_pts):
        d = {"t": t, "s": [shape_data(pts, closed, smooth)]}
        if i < len(frames_pts) - 1:
            d["o"] = {"x": 0.42, "y": 0} if ease == "io" else {"x": 0, "y": 0}
            d["i"] = {"x": 0.58, "y": 1} if ease == "io" else {"x": 1, "y": 1}
        ks.append(d)
    return {"ty": "sh", "ks": {"a": 1, "k": ks}, "nm": "Path"}


def grp(name, items, **trkw):
    has_fill = any(i.get("ty") == "fl" for i in items)
    items = [i for i in items if not (has_fill and i.get("ty") == "st" and i["c"]["k"] == rgba(OUTLINE))]
    for i in items:
        if i.get("ty") == "st" and i["c"]["k"] == rgba(OUTLINE):
            i["c"] = st(rgba(INK))
    return {"ty": "gr", "nm": name, "it": items + [tr(**trkw)]}


def star4(cx, cy, r):
    k = r * 0.28
    return path([(cx, cy - r), (cx + k, cy - k), (cx + r, cy), (cx + k, cy + k),
                 (cx, cy + r), (cx - k, cy + k), (cx - r, cy), (cx - k, cy - k)])


class Comp:
    def __init__(self):
        self.layers = []  # rendered top-first; we append bottom-first then reverse
        self.ind = 0

    def layer(self, name, shapes, p=(0, 0), a=(0, 0), r=0, s=(100, 100), o=100, parent=None):
        self.ind += 1

        def v(x, d3=True):
            if isinstance(x, dict):
                return x
            if isinstance(x, tuple):
                return st(list(x) + ([0] if d3 else []))
            return st(x)
        L = {"ddd": 0, "ind": self.ind, "ty": 4, "nm": name, "sr": 1,
             "ks": {"o": v(o, False), "r": v(r, False), "p": v(p), "a": v(a), "s": v(s if isinstance(s, dict) else (s[0], s[1], 100) if isinstance(s, tuple) else s, False)},
             "ao": 0, "shapes": shapes, "ip": 0, "op": LOOP, "st": 0, "bm": 0}
        if parent:
            L["parent"] = parent
        self.layers.append(L)
        return self.ind


def p3(frames):
    """position animation helper from list of (t,(x,y),ease)."""
    return anim([(t, [x, y, 0], e) for t, (x, y), e in frames])


# ---------------------------------------------------------------- stages

STAGES = [
    dict(key="day1_pemula", title="Hari 1 · Pemula", arm="paddle", arm_period=60, leg_period=60,
         bob=(6, 60), wave_cycles=1, front_cycles=1, speed_lines=0, bubbles=(3, 120),
         outfit="hoodie", ring=True, eyes="happy", goggles="forehead", mouth="smile", sweat=True),
    dict(key="day3_gesit", title="Hari 3 · Gesit", arm="crawl", turns=3, leg_period=20,
         bob=(4, 40), wave_cycles=3, front_cycles=4, speed_lines=3, line_period=40, bubbles=(4, 60),
         outfit="rash_blue", eyes="goggles", mouth="grin", splash=True),
    dict(key="day7_turbo", title="Streak 7 · Turbo Kincir", arm="windmill", turns=10, ghosts=True, leg_period=8,
         bob=(3, 12), shake=True, wave_cycles=6, front_cycles=8, speed_lines=6, line_period=20, bubbles=(6, 30),
         outfit="rash_turbo", eyes="goggles", mouth="laugh", headband=True, splash=True, wake=True),
    dict(key="day14_champion", title="Streak 14 · Juara", arm="windmill", turns=8, ghosts=True, leg_period=10,
         bob=(3, 15), wave_cycles=5, front_cycles=6, speed_lines=5, line_period=24, bubbles=(5, 40),
         outfit="rash_purple", eyes="shades", mouth="grin", cape=True, medal=True, splash=True, wake=True),
    dict(key="day30_legend", title="Streak 30 · Golden Legend", arm="windmill", turns=10, ghosts=True, leg_period=8,
         bob=(4, 20), wave_cycles=6, front_cycles=8, speed_lines=6, line_period=20, bubbles=(6, 30),
         outfit="gold", eyes="shades", mouth="laugh", crown=True, wings=True, aura=True, sparkles=True,
         splash=True, wake=True),
]

OUTFITS = {
    "hoodie": dict(main="#FF4B4B", dark="#EA2B2B", trim="#FFFFFF"),
    "rash_blue": dict(main="#1CB0F6", dark="#1899D6", trim="#FFFFFF"),
    "rash_turbo": dict(main="#FF9600", dark="#E58600", trim="#FFE14D"),
    "rash_purple": dict(main="#CE82FF", dark="#A568CC", trim="#FFC800"),
    "gold": dict(main="#FFC800", dark="#E5A800", trim="#FFF4C2"),
}


def wave_shape(amp, period=100, x0=-400, x1=1000, depth=260):
    pts = []
    x = x0
    up = True
    while x <= x1:
        pts.append((x, -amp if up else amp))
        up = not up
        x += period / 2
    n = len(pts)
    h = period / 2 * 0.38
    ins = [[-h, 0]] * n + [[0, 0], [0, 0]]
    outs = [[h, 0]] * n + [[0, 0], [0, 0]]
    v = [list(p) for p in pts] + [[x1, depth], [x0, depth]]
    return {"ty": "sh", "ks": st({"i": ins, "o": outs, "v": v, "c": True}), "nm": "Wave"}


def build_stage(cfg):
    c = Comp()
    out = OUTFITS[cfg["outfit"]]
    body_base = (236, 214)

    # ---- background
    c.layer("BG", [grp("sky", [rect((250, 200), (W, H), 0), fill("#FFFFFF")]),
                   grp("blob", [ell((120, 90), (180, 180)), fill("#F1FAFF")]),
                   grp("blob2", [ell((430, 70), (120, 120)), fill("#F1FAFF")])])
    if cfg.get("aura"):
        c.layer("Golden Aura", [grp("aura", [ell((0, 0), (300, 300)), fill("#FFE27A", 45)]),
                                grp("aura2", [ell((0, 0), (200, 200)), fill("#FFD23F", 45)])],
                p=(270, 200), s=osc([92, 92, 100], [108, 108, 100], 40), o=osc(70, 100, 40))

    # ---- back water
    c.layer("Water Back", [grp("w", [wave_shape(6), fill(WATER)])],
            p=anim([(0, [0, 228, 0], "lin"), (LOOP, [-100 * cfg["wave_cycles"], 228, 0])]))

    # ---- body (parent for all character parts)
    bob_amp, bob_p = cfg["bob"]
    bx, by = body_base
    body_pos = osc([bx, by - bob_amp, 0], [bx, by + bob_amp, 0], bob_p)
    body_rot = osc(-3, 3, 12) if cfg.get("shake") else osc(-2, 2, bob_p * 2 if bob_p * 2 <= LOOP else bob_p)

    if cfg.get("wings"):
        pass  # wings created after body (needs parent id) – see below

    # placeholders to keep layer order (bottom first)
    order = []

    # wings (behind body)
    body_ind_holder = {}

    def body_child(name, shapes, **kw):
        order.append((name, shapes, kw))

    # torso shapes
    torso = [grp("shade", [rect((0, 15), (112, 26), 13), fill(out["dark"])]),
             grp("torso", [rect((0, 0), (122, 58), 29), fill(out["main"])])]
    if cfg["outfit"] == "hoodie":
        torso.insert(0, grp("pocket", [path([(-20, 10), (20, 10)], closed=False), stroke(out["dark"], 3)]))
        torso.insert(0, grp("strings", [path([(44, -6), (40, 14)], closed=False), path([(52, -6), (50, 12)], closed=False),
                                        stroke(out["trim"], 3)]))
    else:
        torso.insert(0, grp("stripe", [rect((-6, 2), (96, 9), 4.5), fill(out["trim"])]))
    if cfg["outfit"] == "rash_turbo":
        torso.insert(0, grp("bolt", [path([(-4, -18), (-14, 2), (-4, 2), (-10, 18), (8, -4), (-2, -4), (4, -18)]),
                                     fill("#FFE14D"), stroke(OUTLINE, 2.5)]))
    if cfg["outfit"] == "gold":
        torso.insert(0, grp("star", [star4(-8, -2, 14), fill("#FFFFFF"), stroke(OUTLINE, 2)]))

    # ---- legs (behind body)
    legs_shapes = []
    for i, (dy, ph) in enumerate([(-8, 0.0), (8, 0.5)]):
        legs_shapes.append(grp(f"leg{i}", [
            grp("short", [rect((-8, 0), (26, 24), 10), fill(out["dark"]), stroke(OUTLINE, 3)]),
            grp("foot", [ell((-56, 0), (18, 22)), fill(SKIN), stroke(OUTLINE, 3)]),
            grp("shin", [rect((-30, 0), (50, 17), 8.5), fill(SKIN), stroke(OUTLINE, 3)]),
        ], p=(0, dy), r=osc(-18, 18, cfg["leg_period"], ph)))

    # ---- arms
    def arm_shapes(color_main, ghost=False):
        o = 100
        items = [grp("hand", [ell((64, 0), (26, 26)), fill(SKIN)]),
                 grp("cuff", [rect((50, 0), (10, 22), 5), fill(OUTFITS[cfg["outfit"]]["dark"])]),
                 grp("sleeve", [rect((26, 0), (58, 24), 12), fill(color_main)])]
        if ghost:
            items = [grp("ghost", [rect((34, 0), (78, 22), 11), fill("#FFFFFF")])]
        return items

    def arm_rot(phase_deg, ghost_lag=0):
        if cfg["arm"] == "paddle":
            return osc(25 + phase_deg * 0, 115, cfg["arm_period"], 0.5 if phase_deg else 0.0)
        r0 = 180 + phase_deg - ghost_lag
        return spin(r0, cfg["turns"])

    # ---- head
    head = []
    eyes = cfg["eyes"]
    if cfg.get("crown"):
        head.append(grp("crown", [
            grp("gems", [ell((-4, -46), (6, 6)), ell((10, -48), (6, 6)), ell((24, -46), (6, 6)), fill("#FF4D8D")]),
            grp("crownbody", [path([(-14, -36), (-16, -58), (-4, -46), (10, -62), (22, -46), (34, -58), (32, -36)]),
                              fill("#FFD23F"), stroke(OUTLINE, 3)])], r=-6))
    if cfg.get("headband"):
        head.append(grp("headband", [rect((0, -18), (68, 11), 5.5), fill("#E8282B"), stroke(OUTLINE, 2.5)]))
    if eyes == "goggles":
        head.append(grp("goggles", [
            grp("shine", [ell((4, -9), (5, 5)), ell((20, -9), (5, 5)), fill("#FFFFFF")]),
            grp("lens", [ell((6, -6), (15, 14)), ell((22, -6), (15, 14)), fill("#3EC5FF"), stroke(OUTLINE, 3)]),
            grp("strap", [path([(-32, -10), (-2, -6)], closed=False), stroke("#FF7A1A", 4)])]))
    elif eyes == "shades":
        head.append(grp("shades", [
            grp("shine", [path([(0, -10), (6, -10)], closed=False), path([(17, -10), (23, -10)], closed=False), stroke("#FFFFFF", 2)]),
            grp("lens", [rect((6, -6), (16, 12), 5), rect((23, -6), (16, 12), 5), fill("#1D1B33")]),
            grp("bridge", [path([(-30, -8), (32, -8)], closed=False), stroke("#1D1B33", 3)])]))
    else:  # happy closed eyes
        head.append(grp("eyes", [
            grp("hl", [ell((8, -9), (4, 4)), ell((24, -9), (4, 4)), fill("#FFFFFF")]),
            grp("pupil", [ell((9, -6), (9, 11)), ell((25, -6), (9, 11)), fill(INK)], s=cyc([(0, [100, 100]), (0.92, [100, 100]), (0.96, [100, 10]), (1, [100, 100])], 120), a=(17, -6), p=(17, -6)),
            grp("white", [ell((7, -6), (15, 18)), ell((23, -6), (15, 18)), fill("#FFFFFF")]),
            grp("brows", [path([(1, -19), (10, -21)], closed=False), path([(19, -21), (28, -19)], closed=False), stroke(HAIR_DARK, 3)])]))
    if cfg.get("goggles") == "forehead":
        head.append(grp("goggles_up", [
            grp("lens", [ell((2, -24), (14, 12)), ell((17, -26), (14, 12)), fill("#3EC5FF"), stroke(OUTLINE, 2.5)]),
            grp("strap", [path([(-30, -18), (-6, -23)], closed=False), stroke("#FF7A1A", 4)])], r=10, p=(0, 0)))
    mouth = cfg["mouth"]
    if mouth == "smile":
        head.append(grp("mouth", [path([(8, 8), (16, 14), (24, 8)], closed=False, smooth=0.3), stroke(OUTLINE, 3)]))
    elif mouth == "grin":
        head.append(grp("mouth", [
            grp("teeth", [rect((16, 7), (16, 4), 2), fill("#FFFFFF")]),
            grp("m", [path([(6, 5), (26, 5), (16, 18)], smooth=0.0), fill("#7A1F2B"), stroke(OUTLINE, 2.5)])]))
    else:  # laugh – mouth opens/closes "ha-ha-ha"
        head.append(grp("mouth", [
            grp("tongue", [ell((16, 16), (12, 7)), fill("#FF6B81")]),
            grp("m", [path([(4, 4), (28, 4), (24, 16), (16, 21), (8, 16)], smooth=0.12), fill("#7A1F2B"), stroke(OUTLINE, 2.5)])],
            a=(16, 4), p=(16, 4), s=osc([100, 70], [105, 115], 10)))
    head += [
        grp("nose", [ell((18, 4), (9, 7)), fill(SKIN_DARK)]),
        grp("cheeks", [ell((0, 8), (11, 7)), ell((30, 8), (8, 7)), fill("#FF9AA2", 80)]),
        grp("hairshade", [path([(-30, 8), (-37, -12), (-34, -30), (-24, -40), (-20, -30), (-24, -14), (-20, 6)], smooth=0.16), fill(HAIR_DARK)]),
        grp("hair_", [path([(-30, 8), (-37, -12), (-34, -30), (-24, -40), (-10, -44), (4, -42), (18, -38), (30, -30),
                           (34, -20), (22, -24), (16, -16), (8, -24), (-4, -20), (-16, -12), (-20, 6)], smooth=0.16),
                     fill(HAIR), stroke(OUTLINE, 3)]),
        grp("ear", [ell((-14, 4), (13, 16)), fill(SKIN_DARK)]),
        grp("chin", [ell((0, 30), (40, 16)), fill(SKIN_DARK)]),
        grp("face", [ell((2, 0), (70, 66)), fill(SKIN)]),
    ]

    # ===== add layers bottom → top
    body_ind_ref = {}

    # we need body ind for parenting: create body layer first in a temporary list and fix order later
    # Simplest: create body now, then children (parent indices only need to exist, not be in order)
    body_ind = c.layer("Body", torso, p=body_pos, r=body_rot, s=(138, 138))
    body_layer = c.layers.pop()  # re-insert later at correct z

    if cfg.get("wings"):
        wing_pts = [(0, 0), (-30, -40), (-70, -62), (-58, -36), (-84, -40), (-64, -16), (-82, -12), (-40, 6)]
        c.layer("Wings", [
            grp("wingB", [path(wing_pts, smooth=0.1), fill("#FFE27A"), stroke(OUTLINE, 3)], p=(10, -20), r=osc(-25, 15, 20, 0.15)),
            grp("wingF", [path(wing_pts, smooth=0.1), fill("#FFD23F"), stroke(OUTLINE, 3)], p=(0, -22), r=osc(-15, 25, 20)),
        ], parent=body_ind)
    if cfg.get("ring"):
        c.layer("Ring Back", [grp("ringback", [path([(-70, 14), (0, -8), (70, 14)], closed=False, smooth=0.35),
                                               stroke("#FFD23F", 16)])], parent=body_ind)
    c.layer("Legs", legs_shapes, p=(-56, 4), parent=body_ind)
    c.layer("Arm Back", arm_shapes(out["dark"]), p=(30, -12), r=arm_rot(180), parent=body_ind)
    c.layers.append(body_layer)
    if cfg.get("cape"):
        def cape(t_off):
            w = math.sin(t_off) * 8
            return [(36, -24), (-10, -40 + w * 0.3), (-60, -34 + w), (-96, -26 - w), (-88, -8 + w * 0.6),
                    (-50, -16 - w * 0.4), (-6, -18), (30, -14)]
        frames = [(t, cape(t / 30 * 2 * math.pi), "lin") for t in range(0, LOOP + 1, 10)]
        c.layer("Cape", [grp("cape", [path_anim(frames, smooth=0.15), fill("#E8282B"), stroke(OUTLINE, 3)])],
                parent=body_ind)
    if cfg.get("medal"):
        c.layer("Medal", [grp("medal", [
            grp("glint", [star4(36, 28, 5), fill("#FFFFFF")], s=osc([30, 30], [120, 120], 30)),
            grp("coin", [ell((36, 28), (18, 18)), fill("#FFD23F"), stroke(OUTLINE, 2.5)]),
            grp("ribbon", [path([(28, 2), (36, 22), (44, 2)], closed=False), stroke("#2F7BEA", 5)])])], parent=body_ind)
    if cfg.get("ring"):
        c.layer("Ring Front", [
            grp("duck", [
                grp("beak", [path([(32, 30), (44, 34), (32, 38)], smooth=0.2), fill("#FF8A1F"), stroke(OUTLINE, 2.5)]),
                grp("eye", [ell((26, 28), (5, 6)), fill(OUTLINE)]),
                grp("duckhead", [ell((22, 32), (26, 24)), fill("#FFD23F"), stroke(OUTLINE, 3)])]),
            grp("ringfront", [path([(-72, 12), (0, 40), (72, 12)], closed=False, smooth=0.35), stroke("#FFD23F", 18)]),
            grp("ringoutline", [path([(-72, 12), (0, 40), (72, 12)], closed=False, smooth=0.35), stroke(HAIR_DARK, 22)]),
        ], parent=body_ind)
    head_ind = c.layer("Head", head, p=(66, -24), s=(114, 114), r=osc(-4, 4, max(cfg["bob"][1], 20)), parent=body_ind)
    if cfg.get("headband"):
        c.layer("Headband Tails", [
            grp("tail1", [path([(0, 0), (-26, -6), (-30, 4)], closed=True, smooth=0.1), fill("#E8282B"), stroke(OUTLINE, 2.5)],
                r=osc(-20, 15, 8)),
            grp("tail2", [path([(0, 2), (-30, 6), (-28, 16)], closed=True, smooth=0.1), fill("#E8282B"), stroke(OUTLINE, 2.5)],
                r=osc(15, -15, 8, 0.3)),
        ], p=(-32, -18), parent=head_ind)
    if cfg.get("sweat"):
        c.layer("Sweat", [grp("drop", [path([(0, -8), (5, 2), (0, 6), (-5, 2)], smooth=0.25), fill("#9BE3FF"), stroke(OUTLINE, 2)])],
                p=cyc([(0, [36, -30, 0]), (1, [42, -6, 0])], 60), o=cyc([(0, 100), (0.7, 100), (1, 0)], 60), parent=head_ind)

    if cfg.get("ghosts"):
        for i, lag in enumerate([24, 48]):
            c.layer(f"Arm Blur {i}", arm_shapes(out["main"], ghost=True), p=(36, -8), r=arm_rot(0, lag), o=35 - i * 15, parent=body_ind)
    c.layer("Arm Front", arm_shapes(out["main"]), p=(36, -8), r=arm_rot(0), parent=body_ind)

    # ---- front water overlay (tints everything under the surface)
    c.layer("Water Front", [grp("w", [wave_shape(5, period=80), fill(WATER_FRONT)])],
            p=anim([(0, [-40, 238, 0], "lin"), (LOOP, [-40 - 80 * cfg["front_cycles"], 238, 0])]), o=62)
    c.layer("Water Shine", [grp("lines", [path([(60, 300), (110, 300)], closed=False), path([(330, 330), (400, 330)], closed=False),
                                          path([(180, 360), (220, 360)], closed=False), stroke("#FFFFFF", 4, 70)])],
            p=anim([(0, [0, 0, 0], "lin"), (LOOP, [-500, 0, 0])]) if False else st([0, 0, 0]))

    # ---- fx
    n_b, b_period = cfg["bubbles"]
    for i in range(n_b):
        y0 = 290 + (i * 23) % 70
        x0 = 380 - (i * 61) % 260
        c.layer(f"Bubble {i}", [grp("b", [ell((0, 0), (10 + i % 3 * 4, 10 + i % 3 * 4)), stroke("#FFFFFF", 2.5)])],
                p=cyc([(0, [x0, y0, 0]), (1, [x0 - 120, y0 - 50, 0])], b_period, i / n_b),
                o=cyc([(0, 0), (0.15, 90), (0.8, 90), (1, 0)], b_period, i / n_b))
    for i in range(cfg.get("speed_lines", 0)):
        y = 150 + i * 22
        ln = 40 + (i % 3) * 18
        c.layer(f"Speed Line {i}", [grp("l", [path([(0, 0), (ln, 0)], closed=False), stroke("#FFFFFF", 5)])],
                p=cyc([(0, [200, y, 0]), (1, [-40, y, 0])], cfg["line_period"], i / max(1, cfg["speed_lines"])),
                o=cyc([(0, 0), (0.2, 100), (0.8, 100), (1, 0)], cfg["line_period"], i / max(1, cfg["speed_lines"])))
        if i == 0:
            pass
    if cfg.get("splash"):
        per = LOOP / cfg["turns"]
        for i, (dx, dy) in enumerate([(-14, -30), (4, -40), (20, -26), (30, -12)]):
            c.layer(f"Splash {i}", [grp("d", [ell((0, 0), (10, 13)), fill("#FFFFFF"), stroke(WATER, 2)])],
                    p=cyc([(0, [372, 226, 0]), (1, [372 + dx, 226 + dy, 0])], per, 0.0),
                    s=cyc([(0, [40, 40]), (0.4, [110, 110]), (1, [20, 20])], per, 0.0),
                    o=cyc([(0, 100), (0.6, 100), (1, 0)], per, 0.0))
    if cfg.get("wake"):
        for i in range(7):
            ph = i / 7
            c.layer(f"Wake {i}", [grp("d", [ell((0, 0), (14 - i % 3 * 3, 14 - i % 3 * 3)), fill("#FFFFFF"), stroke(WATER, 2)])],
                    p=cyc([(0, [96, 228, 0]), (0.5, [62 - i * 6, 192 - (i % 3) * 12, 0]), (1, [26 - i * 8, 232, 0])], 18, ph),
                    o=cyc([(0, 100), (0.8, 100), (1, 0)], 18, ph))
        c.layer("Foam", [grp("f", [ell((0, 0), (90, 18)), fill("#FFFFFF", 85)]), grp("f2", [ell((-50, 4), (60, 12)), fill("#FFFFFF", 70)])],
                p=(80, 230), s=osc([90, 90], [115, 110], 12))
    if cfg.get("sparkles"):
        for i, (x, y) in enumerate([(120, 110), (380, 120), (420, 210), (90, 190), (300, 90)]):
            c.layer(f"Sparkle {i}", [grp("s", [star4(0, 0, 12), fill("#FFFFFF"), stroke("#FFC21A", 2.5)])],
                    p=(x, y), s=osc([0, 0], [110, 110], 30, i / 5), r=spin(0, 1))

    c.layers.reverse()  # Lottie renders first layer on top
    return c.layers


def comp(name, layers, op=LOOP, markers=None):
    return {"v": "5.7.4", "fr": FR, "ip": 0, "op": op, "w": W, "h": H, "nm": name, "ddd": 0,
            "assets": [], "layers": layers, "markers": markers or []}


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    combined, markers = [], []
    for si, cfg in enumerate(STAGES):
        layers = build_stage(cfg)
        name = f"swimmer_{cfg['key']}"
        with open(os.path.join(here, name + ".json"), "w", encoding="utf-8") as f:
            json.dump(comp(f"Klubby Swimmer – {cfg['title']}", layers), f, separators=(",", ":"))
        # combined: shift each stage in time with layer start offset
        off = si * LOOP
        base = si * 1000
        for L in json.loads(json.dumps(layers)):
            L["ind"] += base
            if "parent" in L:
                L["parent"] += base
            L["st"] = off
            L["ip"] = off
            L["op"] = off + LOOP
            combined.append(L)
        markers.append({"tm": off, "cm": cfg["key"], "dr": LOOP})
    with open(os.path.join(here, "swimmer_streak_evolution.json"), "w", encoding="utf-8") as f:
        json.dump(comp("Klubby Swimmer – Streak Evolution (all stages)", combined, op=LOOP * len(STAGES), markers=markers),
                  f, separators=(",", ":"))
    print("ok", [s["key"] for s in STAGES])


if __name__ == "__main__":
    main()
