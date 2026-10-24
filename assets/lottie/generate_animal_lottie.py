"""Generator animasi Lottie karakter hewan Klubby (versi sebadan): 18 hewan (1 per keluarga olahraga) x 5 tahap streak.

Jalankan:  python generate_animal_lottie.py
Output   :  animals/<hewan>_<tahap>.json      (90 file, loop 2 detik)
            animals/<hewan>_evolution.json     (gabungan 5 tahap, marker per tahap)

Bentuk badan mengikuti "Board · Maskot Sebadan (Geng Gemoy)" di klubby_app.pen.
Sistem pembeda tahap (sama dengan board):
  latar warna, ukuran badan, aksesori bertambah (kaos & sepatu -> ikat kepala -> kacamata, jubah & medali
  -> mahkota & aura), kecepatan gerak naik, dan tiap olahraga punya jurus tambahan di tahap tinggi.
"""
import json
import math
import os

from generate_swimmer_lottie import (
    FR, LOOP, WATER, WATER_FRONT, Comp, anim, cyc, ell, fill, grp, osc, rect, path, path_anim, spin, star4, stroke, tr,
)

W = H = 400
INK = "#3C3C3C"
MOUTH = "#C2333A"
CHEEK = "#FF9E9E"

STAGES = [
    # key, label, tint, shirt, scale, speed period (frames per gerakan, harus membagi 120 kira-kira)
    dict(key="day1_pemula", label="Hari 1 · Pemula", tint="#FFF4D6", shirt=None, sc=82, P=60, SP=120),
    dict(key="day3_gesit", label="Hari 3 · Gesit", tint="#DDF4FF", shirt="#1CB0F6", sc=88, P=40, SP=60),
    dict(key="day7_turbo", label="Streak 7 · Turbo", tint="#FFE8CC", shirt="#FF9600", sc=94, P=24, SP=40),
    dict(key="day14_juara", label="Streak 14 · Juara", tint="#F3E2FF", shirt="#CE82FF", sc=100, P=15, SP=30),
    dict(key="day30_legend", label="Streak 30 · Legend", tint="#D7FFB8", shirt="#FFC800", sc=104, P=12, SP=24),
]
SWIM_TURNS = [0, 2, 2, 3, 4]   # tahap 1 masih kayuh anjing, sisanya gaya kupu-kupu
WHEEL_TURNS = [1, 2, 3, 4, 4]  # pedal & roda berputar 1:1 supaya kaki dan ban selalu sinkron
DANCE_BEAT = [60, 60, 30, 30, 20]  # frame per ketukan, 2 ketukan harus membagi LOOP
BADMINTON_JUMP = [0, 0, 0, 50, 30]   # tinggi lompatan smash (Juara+)
MARTIAL_P = [120, 120, 120, 60, 60]  # frame per jurus silat (Pemula/Gesit pukulan saja, Turbo+ pukulan + tendangan)

# pose silat: kuda-kuda lebar, tangan depan siaga di depan dada, tangan belakang di pinggang
SILAT_POSE = {
    "guard": dict(bp=[0, -36, 0], br=0, af=-145, ab=24, lf=-30, lb=30),
    "punch": dict(bp=[12, -36, 0], br=10, af=-88, ab=24, lf=-30, lb=30),
    "kick": dict(bp=[-6, -46, 0], br=-10, af=-115, ab=120, lf=-98, lb=8),
    "jump": dict(bp=[-6, -78, 0], br=-10, af=-115, ab=120, lf=-98, lb=-30),
}

# Urutan & warna sama dengan board sebadan. bird=True -> badan bulat + kaki burung.
ANIMALS = [
    dict(key="otto_berang", name="Otto", animal="Berang-berang", sport="swim", ears="round", tail="otter",
         fur="#A86D38", dark="#7A4A22", inner="#F2D2A9", muzzle="#F2D2A9", nose="#4B2C14"),
    dict(key="pingo_pinguin", name="Pingo", animal="Pinguin", sport="surf", ears="none", bird=True,
         face="penguin", beak="penguin", fur="#3C4A5C", dark="#2B3645", belly="#FFFFFF", muzzle=None, nose=INK),
    dict(key="kiki_kelinci", name="Kiki", animal="Kelinci", sport="run", ears="long", tail="puff", tailC="#FFFFFF",
         fur="#F4F1EC", dark="#DCD4C8", inner="#FFB3C1", muzzle="#FFFFFF", nose="#FF8FA3"),
    dict(key="gugun_kambing", name="Gugun", animal="Kambing Gunung", sport="hike", ears="side", tail="puff",
         horn="goat", hornC="#B9A88C", beard="#E2D8C6",
         fur="#F2EDE4", dark="#D6CCBC", muzzle="#E6DCCB", nose="#8A7A66"),
    dict(key="rubi_rubah", name="Rubi", animal="Rubah", sport="bike", ears="pointy", tail="fox",
         fur="#FF8A3D", dark="#E0662A", inner="#FFE0C2", muzzle="#FFF3E6", nose=INK),
    dict(key="doni_corgi", name="Doni", animal="Anjing Corgi", sport="frisbee", ears="corgi", tail="puff",
         blaze="#FFFFFF", fur="#F4A340", dark="#E08A1E", inner="#FFD7B0", muzzle="#FFFFFF", nose=INK),
    dict(key="ciko_ayam", name="Ciko", animal="Anak Ayam", sport="badminton", ears="tuft",
         fur="#FFD43B", dark="#F5B700", inner="#FFD43B", muzzle=None, nose="#FF9600"),
    dict(key="pandu_panda", name="Pandu", animal="Panda", sport="padel", ears="panda", tail="puffdark", limbs=INK,
         fur="#FFFFFF", dark=INK, inner=INK, muzzle=None, nose=INK),
    dict(key="cimot_kucing", name="Cimot", animal="Kucing", sport="pingpong", ears="cat", tail="cat", whiskers=True,
         stripes="#C97F4E", fur="#F2B27E", dark="#C97F4E", inner="#FFB3C1", muzzle="#FFF1E4", nose="#FF8FA3"),
    dict(key="koko_koala", name="Koko", animal="Koala", sport="soccer", ears="big",
         fur="#9AA5B1", dark="#7D8896", inner="#F3D9E0", muzzle="#C9D1D9", nose="#4B4B4B"),
    dict(key="jeri_jerapah", name="Jeri", animal="Jerapah", sport="basket", ears="side", tail="thin", horn="giraffe",
         neck=True, spots="#D08A3A", fur="#F7C55A", dark="#D08A3A", muzzle="#FBE3B0", nose="#8A5A2B"),
    dict(key="bento_banteng", name="Bento", animal="Banteng", sport="rugby", ears="side", tail="thin", horn="bull",
         hornC="#F4E9D8", nostrils=True, bigMuzzle=True, fur="#7A4A2E", dark="#5A321D", muzzle="#D9A08C", nose="#5A321D"),
    dict(key="tara_harimau", name="Tara", animal="Harimau", sport="martial", ears="round", tail="tiger",
         stripes=INK, fur="#FF9F1C", dark="#E07B00", inner="#FFE0C2", muzzle="#FFFFFF", nose=INK),
    dict(key="gembul_gajah", name="Gembul", animal="Gajah", sport="lift", ears="big", tail="thin", trunk=True,
         fur="#A7B4D6", dark="#8F9CC2", inner="#F3C6D3", muzzle=None, nose="#8F9CC2"),
    dict(key="kura_kurakura", name="Kura", animal="Kura-kura", sport="yoga", ears="none", tail="stub", shell="#3F7E25",
         fur="#8ED16B", dark="#58A700", muzzle="#C8EDB0", nose="#3F7E25"),
    dict(key="flami_flamingo", name="Flami", animal="Flamingo", sport="dance", ears="tuft", bird=True,
         feet="flamingo", beak="flamingo", fur="#FF9EC4", dark="#F06AA0", muzzle=None, nose=INK),
    dict(key="momo_monyet", name="Momo", animal="Monyet", sport="climb", ears="monkey", tail="monkey", face="monkey",
         fur="#8B5A3C", dark="#6E4329", inner="#F2CFA5", muzzle=None, nose="#5A3622"),
    dict(key="eko_elang", name="Eko", animal="Elang Jawa", sport="archery", ears="tuft", bird=True, tail="feather",
         beak="eagle", fur="#A8693A", dark="#6B3F1D", muzzle="#F2D9B8", nose=INK),
]

K = 1.25          # skala offset wajah dari desain pen (kepala 96x86 -> 120x108)
HC = (0, -55)     # pusat kepala relatif ke leher


def PR(v):
    """rotasi desain pen (negatif = searah jarum jam) -> rotasi Lottie (positif = searah jarum jam)."""
    return -v


def E(name, cx, cy, w, h, c, **kw):
    return grp(name, [ell((cx, cy), (w, h)), fill(c)], **kw)


def R(name, cx, cy, w, h, r, c, **kw):
    return grp(name, [rect((cx, cy), (w, h), r), fill(c)], **kw)


def ER(name, cx, cy, w, h, c, rot):
    """ellips yang diputar di pusatnya sendiri."""
    return E(name, cx, cy, w, h, c, p=(cx, cy), a=(cx, cy), r=rot)


def RR(name, cx, cy, w, h, r, c, rot):
    return grp(name, [rect((cx, cy), (w, h), r), fill(c)], p=(cx, cy), a=(cx, cy), r=rot)


def hp(dx, dy):
    """offset desain pen -> koordinat lokal kepala."""
    return HC[0] + dx * K, HC[1] + dy * K


def HE(name, dx, dy, w, h, c, rot=0):
    x, y = hp(dx, dy)
    return E(name, x, y, w * K, h * K, c, p=(x, y), a=(x, y), r=rot) if rot else E(name, x, y, w * K, h * K, c)


def HR(name, dx, dy, w, h, r, c):
    x, y = hp(dx, dy)
    return R(name, x, y, w * K, h * K, r * K, c)


def is_bird(a):
    return a.get("bird") or a["ears"] == "tuft"


def head_shapes(a, si, cfg):
    """Daftar group kepala, urutan bawah -> atas (dibalik saat dipakai)."""
    g = []
    e = a["ears"]
    horn = a.get("horn")
    if horn == "goat":
        for d in (-1, 1):
            g.append(HE("Horn", 22 * d, -44, 14, 36, a["hornC"], rot=PR(-24 * d)))
    if horn == "bull":
        for d in (-1, 1):
            g.append(HE("Horn", 46 * d, -34, 16, 40, a["hornC"], rot=PR(-40 * d)))
    if horn == "giraffe":
        for d in (-1, 1):
            g.append(HR("Ossicone", 16 * d, -50, 9, 26, 4, a["dark"]))
            g.append(HE("Knob", 16 * d, -63, 15, 15, a["nose"]))
    if e in ("round", "panda"):
        for d in (-1, 1):
            g.append(HE("Ear", 34 * d, -34, 30, 30, a["dark"]))
            if e == "round":
                g.append(HE("Ear in", 34 * d, -34, 15, 15, a["inner"]))
    if e == "long":
        for d in (-1, 1):
            x, y = hp(20 * d, -30)
            ear = [ell((20 * d * K, -55 - 52 * K), (24 * K, 56 * K)), fill(a["fur"])]
            inner = [ell((20 * d * K, -55 - 50 * K), (11 * K, 38 * K)), fill(a["inner"])]
            g.append(grp("Ear", [grp("in", inner), grp("out", ear)], p=(x, y), a=(x, y),
                         r=osc(-6 * d, 8 * d, cfg["P"] * 2, 0.25 * d)))
    if e == "pointy":
        for d in (-1, 1):
            g.append(HE("Ear", 30 * d, -36, 30, 48, a["dark"], rot=PR(-25 * d)))
            g.append(HE("Ear in", 30 * d, -33, 14, 26, a["inner"], rot=PR(-25 * d)))
    if e == "cat":
        for d in (-1, 1):
            g.append(HE("Ear", 30 * d, -34, 28, 38, a["fur"], rot=PR(-22 * d)))
            g.append(HE("Ear in", 30 * d, -31, 13, 22, a["inner"], rot=PR(-22 * d)))
    if e == "corgi":
        for d in (-1, 1):
            g.append(HE("Ear", 32 * d, -42, 36, 58, a["fur"], rot=PR(-22 * d)))
            g.append(HE("Ear in", 32 * d, -39, 18, 36, a["inner"], rot=PR(-22 * d)))
    if e == "big":
        for d in (-1, 1):
            g.append(HE("Ear", 44 * d, -22, 46, 46, a["dark"]))
            g.append(HE("Ear in", 44 * d, -20, 26, 26, a["inner"]))
    if e == "monkey":
        for d in (-1, 1):
            g.append(HE("Ear", 48 * d, 2, 30, 30, a["fur"]))
            g.append(HE("Ear in", 48 * d, 2, 16, 16, a["inner"]))
    if e == "side":
        for d in (-1, 1):
            g.append(HE("Ear", 50 * d, -10, 32, 16, a["dark"], rot=PR(-20 * d)))
    if e == "tuft":
        g.append(HE("Tuft", -6, -44, 12, 22, a["dark"]))
        g.append(HE("Tuft", 5, -46, 10, 24, a["dark"]))
    g.append(HE("Head", 0, 0, 96, 86, a["fur"]))
    if e == "panda":
        for d in (-1, 1):
            g.append(HE("Patch", 19 * d, 4, 30, 34, INK))
    sp = a.get("stripes")
    if sp and e != "cat":
        g += [HR("Stripe", 0, -36, 8, 16, 4, sp), HR("Stripe", -15, -32, 6, 12, 3, sp), HR("Stripe", 15, -32, 6, 12, 3, sp)]
        for d in (-1, 1):
            g += [HR("Stripe", 43 * d, 2, 12, 5, 2, sp), HR("Stripe", 43 * d, 11, 9, 5, 2, sp)]
    if sp and e == "cat":
        g += [HR("Stripe", 0, -34, 7, 14, 3, sp), HR("Stripe", -12, -31, 6, 10, 3, sp), HR("Stripe", 12, -31, 6, 10, 3, sp)]
    if a.get("spots"):
        g += [HE("Spot", -28, -20, 16, 12, a["spots"]), HE("Spot", 30, -14, 12, 10, a["spots"]),
              HE("Spot", 6, -32, 14, 9, a["spots"])]
    if a.get("blaze"):
        g.append(HR("Blaze", 0, -22, 14, 30, 7, a["blaze"]))
    face = a.get("face")
    if face == "monkey":
        g += [HE("Face", -14, 2, 38, 40, a["inner"]), HE("Face", 14, 2, 38, 40, a["inner"]),
              HE("Face", 0, 22, 56, 32, a["inner"])]
    if face == "penguin":
        g += [HE("Face", -17, 4, 36, 46, "#FFFFFF"), HE("Face", 17, 4, 36, 46, "#FFFFFF"),
              HE("Face", 0, 20, 54, 32, "#FFFFFF")]
    if a["muzzle"] and e != "long" and not face:
        g.append(HE("Muzzle", 0, 24, 60, 34, a["muzzle"]) if a.get("bigMuzzle") else HE("Muzzle", 0, 22, 46, 30, a["muzzle"]))
    if si == 3:
        for d in (-1, 1):
            g.append(HR("Shade", 18 * d, 2, 32, 22, 9, INK))
        g.append(HR("Bridge", 0, 0, 10, 5, 2, INK))
        g.append(HR("Glint", -24, -3, 10, 4, 2, "#FFFFFF"))
        g.append(HR("Glint", 12, -3, 10, 4, 2, "#FFFFFF"))
    else:
        blink = cyc([(0, [100, 100]), (0.9, [100, 100]), (0.94, [100, 8]), (1, [100, 100])], LOOP)
        for d in (-1, 1):
            ex, ey = hp(18 * d, 2)
            px, py = hp(18 * d + 2, 5)
            hx, hy = hp(18 * d + 4, 1)
            g.append(grp("Eye", [
                grp("hl", [ell((hx, hy), (4 * K, 5 * K)), fill("#FFFFFF")]),
                grp("pupil", [ell((px, py), (12 * K, 15 * K)), fill(INK)]),
                grp("white", [ell((ex, ey), (22 * K, 26 * K)), fill("#FFFFFF")]),
            ], p=(ex, ey), a=(ex, ey), s=blink))
    beak = a.get("beak") or ("chick" if e == "tuft" else None)
    if beak == "chick":
        g.append(HE("Beak", 0, 17, 24, 15, "#FF9600"))
        g.append(HE("Beak low", 0, 22, 16, 8, "#E58600"))
    elif beak == "flamingo":
        g.append(HE("Beak", 0, 17, 28, 16, "#FFFFFF"))
        g.append(HE("Beak tip", 2, 27, 17, 12, INK))
    elif beak == "penguin":
        g.append(HE("Beak", 0, 17, 22, 13, "#FF9600"))
        g.append(HE("Beak low", 0, 22, 14, 6, "#E58600"))
    elif beak == "eagle":
        g.append(HE("Beak", 0, 17, 28, 17, "#FFC800"))
        g.append(HE("Beak hook", 3, 26, 12, 10, "#E5A800"))
    elif a.get("trunk"):
        tx, ty = hp(0, 12)
        g.append(grp("Trunk", [
            grp("tip", [ell((0, 38 * K), (24 * K, 11 * K)), fill(a["dark"])]),
            grp("trunk", [rect((0, 18 * K), (18 * K, 40 * K), 9 * K), fill(a["dark"])]),
        ], p=(tx, ty), a=(0, 0), r=osc(-10, 10, cfg["SP"])))
        g.append(HE("Mouth", 20, 30, 10, 6, MOUTH))
    elif e == "big":
        g.append(HE("Nose", 0, 15, 22, 26, a["nose"]))
        g.append(HE("Mouth", 0, 33, 14, 8, MOUTH))
    elif a.get("nostrils"):
        g.append(HE("Nostril", -9, 20, 8, 7, a["nose"]))
        g.append(HE("Nostril", 9, 20, 8, 7, a["nose"]))
        g.append(HE("Mouth", 0, 32, 12 if si == 0 else 18, 8 if si == 0 else 10, MOUTH))
    else:
        g.append(HE("Nose", 0, 14, 15, 10, a["nose"]))
        g.append(HE("Mouth", 0, 27, 12 if si == 0 else 18, 10 if si == 0 else 11, MOUTH))
    for d in (-1, 1):
        g.append(HE("Cheek", 36 * d, 18, 14, 8, CHEEK))
    if a.get("whiskers"):
        for d in (-1, 1):
            for dy in (14, 22):
                g.append(HR("Whisker", 42 * d, dy, 22, 3, 1.5, INK))
    if a.get("beard"):
        g.append(HE("Beard", 0, 46, 14, 18, a["beard"]))
    if si in (2, 3):
        g.append(HR("Headband", 0, -24, 82, 12, 6, "#FF4B4B"))
        tx, ty = hp(44, -22)
        g.append(grp("Tails", [
            grp("t2", [rect((tx + 14, ty + 12), (24, 10), 5), fill("#EA2B2B")]),
            grp("t1", [rect((tx + 14, ty), (26, 11), 5), fill("#FF4B4B")]),
        ], p=(tx, ty), a=(tx, ty), r=osc(-12, 18, cfg["P"])))
    if si == 4:
        cx, cy = hp(0, -46)
        g.append(grp("Crown", [
            grp("gem", [ell((cx, cy), (9 * K, 9 * K)), fill("#FF4B4B")]),
            grp("band", [rect((cx, cy), (46 * K, 16 * K), 4), fill("#FFC800")]),
            grp("pts", [ell((cx - 18 * K, cy - 11 * K), (12 * K, 12 * K)), ell((cx, cy - 13 * K), (12 * K, 12 * K)),
                        ell((cx + 18 * K, cy - 11 * K), (12 * K, 12 * K)), fill("#FFC800")]),
        ], p=(cx, cy), a=(cx, cy), r=osc(-5, 5, 60)))
    return g


def arm_shapes(a, shirt):
    """urutan atas -> bawah (format shapes Lottie)."""
    g = [E("Paw", 0, 48, 24, 22, a.get("limbs") or a["fur"])]
    if shirt:
        g.append(R("Sleeve", 0, 10, 28, 26, 10, shirt))
    arm_c = a.get("limbs") or (a["dark"] if is_bird(a) else a["fur"])
    g.append(R("Arm", 0, 24, 22, 50, 11, arm_c))
    return g


def leg_shapes(a, shirt):
    if a.get("feet") == "flamingo":
        return [E("Foot", 6, 44, 24, 10, a["dark"]), R("Leg", 0, 22, 7, 44, 3, a["dark"])]
    if is_bird(a):
        return [E("Foot", 6, 44, 30, 12, "#FF9600"), R("Leg", 0, 22, 8, 40, 4, "#FF9600")]
    leg_c = a.get("limbs") or a["fur"]
    if shirt:   # sepatu mulai tahap Gesit, garisnya ikut warna kaos
        return [R("Shoe stripe", 6, 50, 34, 6, 3, shirt), E("Shoe", 6, 44, 40, 20, "#FFFFFF"), R("Leg", 0, 20, 26, 44, 12, leg_c)]
    return [E("Foot", 6, 44, 36, 18, a["dark"]), R("Leg", 0, 20, 26, 44, 12, leg_c)]


def tail_shapes(a):
    """ekor dalam koordinat pangkal ekor (sisi kanan-belakang badan). Urutan atas -> bawah."""
    t, fur, dk = a.get("tail"), a["fur"], a["dark"]
    if t == "otter":
        return [ER("tail", 20, 26, 24, 62, dk, -55)]
    if t == "puff":
        return [E("tail", 10, 8, 28, 28, a.get("tailC") or fur)]
    if t == "puffdark":
        return [E("tail", 8, 12, 22, 22, dk)]
    if t == "fox":
        return [ER("tip", 39, -36, 20, 26, "#FFFFFF", 30), ER("tail", 24, -10, 38, 74, fur, 30)]
    if t == "cat":
        return [E("tip", 23, -64, 16, 16, dk), RR("tail", 12, -32, 11, 68, 6, dk, 20)]
    if t == "thin":
        return [E("tuft", 18, -38, 12, 16, dk), RR("tail", 9, -19, 6, 42, 3, dk, 25)]
    if t == "tiger":
        return [E("tip", 24, -59, 16, 16, INK), RR("band", 18, -44, 15, 5, 2, INK, 22),
                RR("tail", 12, -30, 14, 64, 7, fur, 22)]
    if t == "monkey":
        return [grp("curl", [ell((20, -75), (30, 30)), stroke(dk, 9)]), RR("tail", 7, -28, 10, 58, 5, dk, 15)]
    if t == "stub":
        return [E("tail", 6, 16, 15, 11, fur)]
    if t == "feather":
        return [E("f", 0, 12, 24, 42, dk), ER("f", -16, 8, 22, 38, dk, 30), ER("f", 16, 8, 22, 38, dk, -30)]
    return None


def racket(c_frame="#FF4B4B"):
    return [
        grp("strings", [ell((0, 104), (36, 46)), fill("#FFFFFF", 70)]),
        grp("rim", [ell((0, 104), (44, 54)), stroke(c_frame, 6)]),
        grp("handle", [rect((0, 70), (8, 34), 4), fill(INK)]),
    ]


def paddle():
    return [E("face", 0, 88, 40, 44, "#FF4B4B"), R("handle", 0, 62, 10, 26, 4, "#8B5A2B")]


def dumbbell():
    return [R("plate", -26, 54, 12, 30, 4, INK), R("plate", 26, 54, 12, 30, 4, INK), R("bar", 0, 54, 64, 8, 4, "#AFAFAF")]


def note(c):
    return [R("stem", 6, -14, 4, 26, 2, c), E("head", 0, 0, 16, 12, c)]


def path_cyc(keys, period, closed=False, smooth=0.0):
    """animasi path berulang. keys: [(u, pts)] dengan u di [0,1); siklus menyambung ke u=0 lagi."""
    frames = []
    s = -period
    while s <= LOOP + period:
        for u, pts in keys:
            frames.append((round(s + u * period, 3), pts, "io"))
        s += period
    return path_anim(frames, closed=closed, smooth=smooth)


def loop_io(points, period, phase=0.0):
    """siklus mulus berulang (ease in-out), menyambung balik ke points[0]. points: [(u, value)] dengan u di [0,1)."""
    frames = []
    s = -phase * period - period
    while s <= LOOP + period:
        for u, v in points:
            frames.append((round(s + u * period, 3), v, "io"))
        s += period
    return anim(frames)


def track(points, period, phase=0.0):
    """siklus berulang dengan easing per titik. points: [(u, value, ease)], ease 'lin'/'io'/'in'/'out'/'hold'."""
    frames = []
    s = -phase * period - period
    while s <= LOOP + period:
        for u, v, e in points:
            frames.append((round(s + u * period, 3), v, e))
        s += period
    return anim(frames)


def silat_timeline(si):
    """[(u, pose)] satu jurus. Pose ditahan sebentar supaya gerakan terbaca jelas, bukan gemetar."""
    if si < 2:
        return [(0, "guard"), (0.3, "guard"), (0.4, "punch"), (0.55, "punch"), (0.7, "guard")]
    kick = "jump" if si == 4 else "kick"
    return [(0, "guard"), (0.12, "guard"), (0.2, "punch"), (0.32, "punch"), (0.44, "guard"),
            (0.56, "guard"), (0.66, kick), (0.8, kick), (0.92, "guard")]


def silat_track(si, key):
    return loop_io([(u, SILAT_POSE[p][key]) for u, p in silat_timeline(si)], MARTIAL_P[si])


def pop_at(u0, u1, period):
    """skala bintang 'pow' yang muncul sebentar di antara u0..u1."""
    return loop_io([(0, [0, 0]), (u0, [0, 0]), (u0 + 0.04, [120, 120]), (u1, [0, 0])], period)


def leg_ik(hip, foot, thigh, shin):
    """lutut untuk kaki dua ruas dari pinggul ke telapak; pilih lutut yang menekuk ke depan (kanan)."""
    dx, dy = foot[0] - hip[0], foot[1] - hip[1]
    d = min(max((dx * dx + dy * dy) ** 0.5, 1e-3), thigh + shin - 0.01)
    a = (thigh * thigh + d * d - shin * shin) / (2 * thigh * d)
    a = math.acos(max(-1.0, min(1.0, a)))
    base = math.atan2(dy, dx)
    knees = [(hip[0] + thigh * math.cos(base + s * a), hip[1] + thigh * math.sin(base + s * a)) for s in (-1, 1)]
    return max(knees, key=lambda k: k[0])


def bike_layers(c, a, si, shirt, sc, rig):
    """kaki dua ruas yang menapak pedal; pedal & roda memakai putaran yang sama."""
    turns = WHEEL_TURNS[si]
    bb, crank_r, hip = (-10, 34), 20, (-24, -24)
    leg_c = a.get("limbs") or a["fur"]
    foot_c = "#FFFFFF" if shirt else a["dark"]
    n = turns * 16
    layers = {}
    for side, ph in (("far", 180), ("near", 0)):
        pts, feet = [], []
        for k in range(n + 1):
            t = LOOP * k / n
            ang = math.radians(360 * turns * t / LOOP + ph)
            foot = (bb[0] + crank_r * math.sin(ang), bb[1] - crank_r * math.cos(ang))
            knee = leg_ik(hip, foot, 44, 44)
            pts.append((round(t, 3), [hip, knee, foot], "lin"))
            feet.append((round(t, 3), [foot[0] + 6, foot[1] - 4, 0], "lin"))
        crank = [grp("pedal", [rect((0, -crank_r), (18, 6), 3), fill(INK)]),
                 grp("arm", [rect((0, -crank_r / 2), (6, crank_r + 6), 3), fill("#AFAFAF")])]
        shoe = [E("shoe", 0, 0, 34, 16, foot_c)]
        if shirt:
            shoe.insert(0, R("stripe", 0, 5, 28, 5, 2, shirt))
        layers[side] = [
            ("Crank " + side, crank, dict(p=bb, r=anim([(0, ph, "lin"), (LOOP, ph + 360 * turns)]), parent=rig)),
            ("Leg " + side, [grp("leg", [path_anim(pts, closed=False), stroke(leg_c, 22)])], dict(parent=rig)),
            ("Shoe " + side, shoe, dict(p=anim(feet), parent=rig)),
        ]
    return layers


def build(a, si):
    cfg = STAGES[si]
    P, SP = cfg["P"], cfg["SP"]
    shirt = cfg["shirt"]
    sport = a["sport"]
    c = Comp()
    cx, cy = 200, 200

    # latar
    c.layer("BG", [E("tint", 0, 0, 380, 380, cfg["tint"])], p=(cx, cy))
    if si == 4:
        rays = [grp(f"ray{i}", [rect((0, -150), (26, 120), 13), fill("#FFE58F")], r=i * 30) for i in range(12)]
        c.layer("Aura rays", rays, p=(cx, cy), r=spin(0, 1 / 12))
        c.layer("Aura glow", [E("g", 0, 0, 230, 230, "#FFE58F")], p=(cx, cy), s=osc([92, 92], [104, 104], 60))

    rig_y = {"swim": 250, "bike": 262, "surf": 298, "climb": 296}.get(sport, 312) + (16 if a.get("neck") else 0)   # jerapah lebih tinggi, turunkan supaya mahkota tidak terpotong
    sc = cfg["sc"]
    yoga_p = 120 if si < 3 else 60   # yoga tetap pelan, Juara ke atas sedikit lebih cepat

    # garis kecepatan
    if si >= 2:
        for i, (y, w) in enumerate([(150, 50), (195, 70), (240, 40)]):
            c.layer(f"Speed {i}", [R("l", 0, 0, w, 9, 5, "#FFFFFF")],
                    p=cyc([(0, [120, y, 0]), (1, [40, y, 0])], P * 2, i / 3),
                    o=cyc([(0, 0), (0.2, 100), (0.8, 100), (1, 0)], P * 2, i / 3))

    # properti belakang
    if sport == "swim":
        c.layer("Water back", [R("w", 0, 0, 520, 200, 0, WATER)],
                p=osc([200, rig_y + 70, 0], [212, rig_y + 64, 0], 60))
    if sport == "surf":
        c.layer("Water back", [R("w", 0, 0, 520, 200, 0, WATER)],
                p=osc([200, rig_y + 100, 0], [212, rig_y + 92 - si * 3, 0], SP))
    if sport == "hike":
        c.layer("Mountains", [
            grp("snow", [path([(-60, -150), (-36, -112), (-84, -112)]), fill("#FFFFFF")]),
            grp("m1", [path([(-60, -150), (40, 20), (-160, 20)]), fill("#C9E7B5")]),
            grp("m2", [path([(80, -100), (170, 20), (-10, 20)]), fill("#A8DB8A")]),
        ], p=(200, rig_y - 10))
    if sport == "climb":
        # tebing di sisi kanan: tepi kiri bergerigi, tepi kanan mengikuti lingkaran latar
        edge = [(250, 17), (262, 60), (246, 105), (266, 150), (250, 200), (268, 248), (248, 295), (262, 340), (250, 383)]
        arc = [(200 + 190 * math.cos(math.radians(d)), 200 + 190 * math.sin(math.radians(d))) for d in range(74, -75, -8)]
        shade = [edge[0]] + [(x + 16, y) for x, y in edge[1:-1]] + [edge[-1]]
        c.layer("Cliff", [grp("shade", [path(shade + arc), fill("#B08458")]),
                          grp("rock", [path(edge + arc), fill("#C9A27A")])][::-1], p=(0, 0))
        # pegangan di permukaan tebing turun dari atas ke bawah (kesan memanjat), memudar di ujung
        colors = ["#FF4B4B", "#1CB0F6", "#FFC800", "#58CC02", "#CE82FF"]
        T = [120, 120, 60, 60, 40][si]
        lanes = (284, 318, 300)
        for i in range(9):
            x = lanes[i % 3] + (i * 7) % 10 - 5
            c.layer(f"Grip {i}", [ER("g", 0, 0, 26, 18, colors[i % 5], (i * 37) % 90 - 45)],
                    p=cyc([(0, [x, 50, 0]), (1, [x, 350, 0])], T, i / 9),
                    o=cyc([(0, 0), (0.15, 100), (0.85, 100), (1, 0)], T, i / 9))
    if sport in ("run", "soccer", "padel", "badminton", "hike", "frisbee", "pingpong", "basket", "rugby",
                 "martial", "lift", "yoga", "dance", "archery"):
        dashes = [R(f"d{i}", -240 + i * 80, 0, 44, 8, 4, "#FFFFFF") for i in range(8)]
        if sport in ("run", "soccer", "rugby"):
            gp = cyc([(0, [200, rig_y + 6, 0]), (1, [120, rig_y + 6, 0])], P * 2)
        elif sport == "hike":
            gp = cyc([(0, [200, rig_y + 6, 0]), (1, [120, rig_y + 6, 0])], SP)
        else:
            gp, dashes = (200, rig_y + 6), []
        c.layer("Ground", [R("g", 0, -4, 420, 10, 5, "#FFFFFF", o=60)] + dashes, p=gp)
    if sport == "yoga":
        c.layer("Mat", [R("mat", 0, 0, 220, 12, 6, "#CE82FF"), R("edge", 0, 5, 220, 4, 2, "#A568CC")], p=(200, rig_y + 4))
        if si >= 1:
            c.layer("Calm ring", [grp("ring", [ell((0, 0), (220, 220)), stroke("#FFFFFF", 6)])],
                    p=(200, rig_y - 120), s=osc([84, 84], [104, 104], yoga_p), o=osc(30, 80, yoga_p))
    if sport == "bike":
        for nm, wx in (("Wheel back", -78), ("Wheel front", 78)):
            spokes = [grp(f"s{i}", [rect((0, 0), (4, 64), 2), fill("#AFAFAF")], r=i * 45) for i in range(4)]
            c.layer(nm, [grp("tire", [ell((0, 0), (78, 78)), stroke(INK, 9)]),
                         grp("hub", [ell((0, 0), (14, 14)), fill(INK)])] + spokes,
                    p=(cx + wx * sc / 100, rig_y + 34 * sc / 100), s=(sc, sc), r=spin(0, WHEEL_TURNS[si]))
        bike = None
        c.layer("Rig ref", [], p=(cx, rig_y), s=(sc, sc))
        bike_rig = c.ind
        bike = bike_layers(c, a, si, shirt, sc, bike_rig)
        for name, shapes, kw in bike["far"]:
            c.layer(name, shapes, **kw)
        c.layer("Bike frame", [grp("saddle", [rect((-36, -20), (34, 10), 5), fill(INK)]),
                               grp("post", [path([(-34, -14), (-36, -20)], closed=False), stroke(INK, 6)]),
                               grp("frame", [path([(-78, 34), (-10, 34), (30, -14), (-34, -14), (-78, 34)], closed=False),
                                             path([(-10, 34), (-34, -14)], closed=False),
                                             path([(30, -14), (78, 34)], closed=False),
                                             stroke("#FF4B4B", 8)]),
                               grp("bar", [path([(30, -14), (40, -44), (58, -46)], closed=False), stroke(INK, 7)])],
                p=(cx, rig_y), s=(sc, sc))

    # rig: surf ikut goyang ombak, Pemula paling goyah
    rig_kw = {}
    if sport == "climb":   # geser ke kiri supaya tangan menempel di tebing kanan
        rig_kw["p"] = (184, rig_y)
    if sport == "surf":
        wob = [12, 7, 6, 5, 4][si]
        rig_kw = dict(r=osc(-wob, wob, SP), p=osc([cx, rig_y, 0], [cx, rig_y - 8, 0], SP / 2))
        if si == 4:   # Legend: lompat aerial di atas ombak
            rig_kw["p"] = cyc([(0, [cx, rig_y, 0]), (0.5, [cx, rig_y, 0]), (0.7, [cx, rig_y - 30, 0]),
                               (0.85, [cx, rig_y - 20, 0]), (1, [cx, rig_y, 0])], 60)
            rig_kw["r"] = cyc([(0, 0), (0.5, 0), (0.75, -20), (1, 0)], 60)
    if sport == "dance" and si >= 3:   # Juara+: sekali putar badan tiap loop
        rig_kw["s"] = loop_io([(0, [sc, sc]), (0.55, [sc, sc]), (0.58, [10, sc]), (0.5805, [-10, sc]), (0.61, [-sc, sc]),
                               (0.7, [-sc, sc]), (0.73, [-10, sc]), (0.7305, [10, sc]), (0.76, [sc, sc])], LOOP)   # lewati skala 0 supaya tidak hilang
    rig = c.layer("Rig", [], p=rig_kw.get("p", (cx, rig_y)), s=rig_kw.get("s", (sc, sc)), r=rig_kw.get("r", 0))
    if sport == "surf":
        c.layer("Board", [R("stripe", 0, 0, 190, 5, 2, "#FFFFFF"), E("board", 0, 0, 240, 26, "#FF4B4B"),
                          grp("fin", [path([(40, 10), (60, 10), (46, 30)]), fill("#E5A800")])],
                p=(0, 20), parent=rig)

    # gerak badan
    if sport == "swim":
        # badan rebah horizontal (kepala ke kanan), naik-turun seperti gelombang lumba-lumba
        body_p = osc([-40, -12, 0], [-40, -22, 0], P)
        body_r = osc(84, 96, P)
    elif sport in ("run", "rugby"):
        body_p = osc([0, -46, 0], [0, -46 - (8 + si * 3), 0], P / 2)
        body_r = 8 + si * 2
    elif sport == "hike":
        body_p = osc([0, -46, 0], [0, -50 - si, 0], SP / 2)
        body_r = 3 + si
    elif sport == "bike":   # duduk di sadel, badan diam supaya kaki tepat di pedal
        body_p = (-26, -20)
        body_r = 12
    elif sport == "badminton" and si >= 3:
        jump = BADMINTON_JUMP[si]   # Legend lebih rendah supaya mahkota tidak terpotong lingkaran
        body_p = cyc([(0, [0, -46, 0]), (0.45, [0, -46, 0]), (0.6, [0, -46 - jump, 0]), (0.75, [0, -40 - jump, 0]), (1, [0, -46, 0])], SP)
        body_r = osc(-3, 3, SP)
    elif sport == "basket" and si >= 3:   # Juara+: dribel lalu lompat
        body_p = cyc([(0, [0, -46, 0]), (0.5, [0, -46, 0]), (0.65, [0, -72, 0]), (0.8, [0, -68, 0]), (1, [0, -46, 0])], LOOP / 2)
        body_r = 0
    elif sport == "martial":
        body_p = silat_track(si, "bp")
        body_r = silat_track(si, "br")
    elif sport == "lift":
        body_p = osc([0, -46, 0], [0, -40 if si == 0 else -42, 0], SP)
        body_r = osc(-4, 4, SP / 2) if si == 0 else 0     # Pemula masih goyah
    elif sport == "yoga":
        lift = -46 - (16 if si == 4 else 0)                  # Legend melayang tenang
        body_p = osc([0, -46, 0], [0, lift - 4, 0], yoga_p)
        body_r = osc(-5, 5, yoga_p / 2) if si == 0 else 0  # Pemula masih goyah
    elif sport == "dance":
        # 2 ketukan: goyang ke kiri sambil mendak, naik, ke kanan sambil mendak, naik (mulus, bukan getar)
        sway, tilt, DB = 10 + si * 3, 7 + si, DANCE_BEAT[si] * 2
        body_p = loop_io([(0, [-sway, -42, 0]), (0.25, [0, -52, 0]), (0.5, [sway, -42, 0]), (0.75, [0, -52, 0])], DB)
        body_r = loop_io([(0, -tilt), (0.25, 0), (0.5, tilt), (0.75, 0)], DB)
    elif sport == "climb":
        body_p = osc([0, -46, 0], [0, -56, 0], SP / 2)
        body_r = osc(2, 9, SP)   # condong ke tebing
    elif sport == "surf":
        body_p = (0, -46)
        body_r = osc(-4, 4, SP / 2)
    else:
        body_p = osc([0, -46, 0], [0, -52, 0], SP / 2)
        body_r = osc(-3, 3, SP)

    bird = is_bird(a)
    torso = [R("Torso", 0, -40, 92, 92, 40, shirt or a["fur"])]
    if sport == "swim":   # badan lebih panjang supaya jelas rebah horizontal
        torso = [R("Torso", 0, -46, 86, 124, 40, shirt or a["fur"])]
    belly = a.get("belly") or a["muzzle"]
    if not shirt and belly and not a.get("bigMuzzle") and sport != "swim":
        torso.insert(0, E("Belly", 0, -32, 54, 50, belly))
    if shirt:
        torso.insert(0, R("Hem", 0, -6, 84, 14, 6, _darker(shirt)))
    if bird:   # kaos menutup seluruh badan bulat, sama seperti hewan lain
        torso = [E("Body", 0, -40, 100, 90, shirt or a["fur"])]
        if shirt:
            torso.append(R("Hem", 0, -4, 70, 12, 6, _darker(shirt)))
        elif belly:
            torso.append(E("Belly", 0, -32, 60, 56, belly))
        torso.reverse()
    if sport == "climb":
        torso.insert(0, R("Harness", 0, -18, 96, 12, 5, "#FF4B4B"))
    if sport == "martial":
        torso.insert(0, R("Belt", 0, -22, 94, 10, 4, INK))
        torso.insert(0, E("Knot", 14, -14, 12, 14, INK))
    if a.get("neck"):
        torso.insert(0, R("Neck", 0, -96, 34, 50, 14, a["fur"]))
        if a.get("spots"):
            torso.insert(0, E("Spot", 6, -100, 12, 9, a["spots"]))
            torso.insert(0, E("Spot", -7, -86, 10, 8, a["spots"]))

    body = c.layer("Body", torso, p=body_p, r=body_r, parent=rig)

    back = []
    if si >= 3 and sport != "swim":   # jubah menutupi perenang, cukup medali & mahkota
        cape_c = "#E5A800" if si == 4 else "#A568CC"
        back.append(("Cape", [grp("cape", [path([(-40, -80), (40, -80), (70, 10), (-70, 10)], smooth=0.12), fill(cape_c)])],
                     dict(p=(0, -80), a=(0, -80), s=osc([100, 100], [112, 96], P), r=osc(-6, 6, P * 2), parent=body)))
    if a.get("shell"):
        back.append(("Shell", [E("rim", 0, -40, 124, 112, a["shell"]), E("in", 0, -44, 96, 84, "#58A700")][::-1],
                     dict(parent=body)))
    tail = tail_shapes(a)
    if tail and sport != "swim":
        wag = 14 if a["tail"] in ("cat", "tiger", "monkey", "puff", "puffdark") else 8
        tail_p = (0, -2) if a["tail"] == "feather" else (34, -14)
        back.append(("Tail", tail, dict(p=tail_p, r=osc(-wag, wag, SP if sport != "yoga" else yoga_p), parent=body)))

    shoulder_y = -70
    # tangan & kaki per olahraga
    arm_back_r = arm_front_r = 0
    leg_back_r = leg_front_r = 0
    front_extra, back_extra = [], []
    if sport == "swim":
        # kedua bahu di sisi atas (punggung). 180 = lurus ke depan, 0 = lurus ke arah kaki
        if SWIM_TURNS[si] == 0:   # Pemula: kayuh anjing di depan muka
            arm_front_r = osc(140, 220, P)
            arm_back_r = osc(220, 140, P)
        else:   # gaya kupu-kupu: dua tangan berputar bersamaan searah jarum jam
            arm_front_r = spin(40, SWIM_TURNS[si])
            arm_back_r = spin(0, SWIM_TURNS[si])
    elif sport == "run":
        arm_front_r = osc(-45 - si * 6, 45 + si * 6, P)
        arm_back_r = osc(45 + si * 6, -45 - si * 6, P)
        leg_front_r = osc(35 + si * 4, -35 - si * 4, P)
        leg_back_r = osc(-35 - si * 4, 35 + si * 4, P)
    elif sport == "bike":   # tangan memegang setang
        arm_front_r = arm_back_r = -46
    elif sport == "badminton":
        arm_front_r = cyc([(0, 20), (0.45, 160), (0.6, 290), (0.8, 340), (1, 380)], SP)   # ancang-ancang ke belakang, smash lewat atas kepala
        arm_back_r = osc(-20, -40, SP)
        front_extra = racket("#1CB0F6")
    elif sport == "padel":
        arm_front_r = osc(-80, 60, SP)
        arm_back_r = osc(20, -10, SP)
        front_extra = racket("#58CC02")
    elif sport == "soccer":
        arm_front_r = osc(-30, 30, SP)
        arm_back_r = osc(30, -30, SP)
        leg_front_r = track([(0.05, 0, "io"), (0.4, 0, "io"), (0.55, -60, "io"), (0.7, -10, "io")], SP)   # angkat kaki menyambut bola
        leg_back_r = osc(-5, 5, SP)
    elif sport == "surf":
        arm_front_r = osc(-75, -105 - si * 4, SP / 2)
        arm_back_r = osc(75, 105 + si * 4, SP / 2, 0.5)
        leg_front_r, leg_back_r = -18, 18
    elif sport == "hike":
        amp = 22 + si * 4
        arm_front_r = osc(-amp, amp * 0.6, SP)
        arm_back_r = osc(amp, -amp, SP)
        leg_front_r = osc(amp, -amp, SP)
        leg_back_r = osc(-amp, amp, SP)
        # tongkat digenggam di ujung atas dan tetap hampir tegak menapak tanah (tidak ikut berayun)
        def stick(arm_a, arm_b):
            return [grp("stick", [rect((0, 86), (7, 86), 3), fill("#8B5A2B")], a=(0, 48), p=(0, 48),
                        r=osc(-arm_a * 0.8, -arm_b * 0.8, SP))]
        front_extra = stick(-amp, amp * 0.6)
        if si >= 2:   # Turbo+: tongkat kedua & ransel
            back_extra = stick(amp, -amp)
            back.append(("Backpack", [R("pack", 0, -46, 108, 84, 22, "#58CC02")], dict(parent=body)))
    elif sport == "frisbee":
        arm_front_r = cyc([(0, 0), (0.4, 45), (0.55, -110), (0.75, -90), (1, 0)], SP)
        arm_back_r = osc(10, -30, SP)
        leg_front_r = cyc([(0, 0), (0.4, 10), (0.55, -20), (1, 0)], SP)
        front_extra = [E("disc", 0, 54, 50, 14, "#FF4B4B", o=cyc([(0, 100), (0.55, 100), (0.56, 0), (1, 0)], SP))]
    elif sport == "pingpong":
        arm_front_r = cyc([(0, -80), (0.15, -50), (0.6, -30), (0.85, -85), (1, -80)], SP / (2 if si >= 2 else 1))
        arm_back_r = osc(20, 40, SP)
        leg_front_r, leg_back_r = -10, 10
        front_extra = paddle()
    elif sport == "basket":
        arm_front_r = osc(-30, -8, SP / 2)
        arm_back_r = osc(15, 30, SP)
        if si >= 3:
            arm_front_r = cyc([(0, -20), (0.5, -10), (0.65, -170), (0.8, -150), (1, -20)], LOOP / 2)
            arm_back_r = cyc([(0, 20), (0.5, 20), (0.65, 170), (0.8, 150), (1, 20)], LOOP / 2)
    elif sport == "rugby":
        arm_front_r = osc(-50, -25, P)
        arm_back_r = osc(45 + si * 6, -45 - si * 6, P)
        leg_front_r = osc(35 + si * 4, -35 - si * 4, P)
        leg_back_r = osc(-35 - si * 4, 35 + si * 4, P)
        front_extra = [R("lace", 0, 60, 4, 16, 2, "#FFFFFF"), E("ball", 0, 60, 46, 30, "#A0522D")]
    elif sport == "martial":
        arm_front_r, arm_back_r = silat_track(si, "af"), silat_track(si, "ab")
        leg_front_r, leg_back_r = silat_track(si, "lf"), silat_track(si, "lb")
    elif sport == "lift":
        top = -150 if si == 0 else -172
        arm_front_r = osc(-95, top, SP)
        arm_back_r = osc(95, -top, SP)
        leg_front_r, leg_back_r = -12, 12
        front_extra, back_extra = dumbbell(), dumbbell()
    elif sport == "yoga":
        arm_front_r = osc(-20, -172, yoga_p)
        arm_back_r = osc(20, 172, yoga_p)
    elif sport == "dance":
        # gaya disko: ketukan 1 tangan depan menunjuk ke atas, ketukan 2 gantian tangan belakang
        DB = DANCE_BEAT[si] * 2
        arm_front_r = loop_io([(0, -150), (0.2, -150), (0.5, -35), (0.7, -35)], DB)
        arm_back_r = loop_io([(0, 35), (0.2, 35), (0.5, 150), (0.7, 150)], DB)
        lift = -40 - si * 6
        leg_front_r = loop_io([(0, lift), (0.2, lift), (0.4, 0), (0.85, 0)], DB)   # angkat satu kaki ala flamingo
        leg_back_r = loop_io([(0, 0), (0.5, 0), (0.7, 10), (0.9, 0)], DB)
    elif sport == "climb":
        # tangan bergantian meraih tebing di kanan atas, kaki menjejak tebing
        arm_front_r = osc(-150, -122, SP)
        arm_back_r = osc(-172, -150, SP, 0.5)
        leg_front_r = osc(-40, -78, SP)
        leg_back_r = osc(-74, -36, SP)
        back.append(("Rope", [grp("rope", [path([(-30, -18), (-62, -150), (-80, -440)], closed=False, smooth=0.3),
                                           stroke("#FF9600", 6)])], dict(parent=body)))   # tali dari harness, lewat samping kepala
    elif sport == "archery":
        arm_front_r = -90
        arm_back_r = cyc([(0, -60), (0.5, -95), (0.6, -60), (1, -60)], SP)
        leg_front_r, leg_back_r = -12, 12
        nock = [(0, 40), (0.5, 10), (0.6, 40)]
        front_extra = [
            grp("string", [path_cyc([(u, [(-46, 40), (0, y), (46, 40)]) for u, y in nock], SP), stroke("#FFFFFF", 2.5)]),
            grp("bow", [path([(-46, 40), (0, 62), (46, 40)], closed=False, smooth=0.35), stroke("#8B5A2B", 7)]),
        ]

    back.append(("Arm back", back_extra + arm_shapes(a, shirt), dict(p=(-46, shoulder_y), r=arm_back_r, parent=body)))
    if sport == "swim":   # tendangan lumba-lumba: dua kaki rapat bergerak bersama
        back.append(("Leg back", leg_shapes(a, None), dict(p=(-12, -4), r=osc(-28, 22, P, 0.1), parent=body)))
        back.append(("Leg front", leg_shapes(a, None), dict(p=(10, -4), r=osc(-28, 22, P), parent=body)))
    if sport not in ("swim", "bike"):
        back.append(("Leg back", leg_shapes(a, shirt), dict(p=(-20, -4), r=leg_back_r, parent=body)))
        if sport == "yoga" and si >= 2:   # Turbo+: pose pohon, lutut menekuk keluar & telapak menempel di lutut kaki lain
            stand, tree = [(0, 0), (0, 16), (0, 30)], [(0, 0), (46, 8), (-2, 32)]
            shoe = [E("Foot", 0, 0, 36, 18, a["dark"])] if not shirt else [R("Shoe stripe", 0, 6, 30, 6, 3, shirt),
                                                                         E("Shoe", 0, 0, 40, 20, "#FFFFFF")]
            leg_c = a.get("limbs") or a["fur"]
            back.append(("Leg front", [
                grp("shoe", shoe, p=loop_io([(0, [6, 44]), (0.5, [-12, 34])], yoga_p), r=loop_io([(0, 0), (0.5, -80)], yoga_p)),
                grp("leg", [path_cyc([(0, stand), (0.5, tree)], yoga_p), stroke(leg_c, 26)]),
            ], dict(p=(20, -4), parent=body)))
        else:
            back.append(("Leg front", leg_shapes(a, shirt), dict(p=(20, -4), r=leg_front_r, parent=body)))
    # sisipkan layer belakang tepat sebelum Body
    body_pos = next(i for i, L in enumerate(c.layers) if L["ind"] == body)
    for name, shapes, kw in back:
        c.layer(name, shapes, **kw)
        L = c.layers.pop()
        c.layers.insert(body_pos, L)
        body_pos += 1

    if si >= 3:
        c.layer("Medal", [grp("medal", [grp("rim", [ell((0, 34), (24, 24)), stroke("#E5A800", 4)]),
                                        E("m", 0, 34, 24, 24, "#FFC800"),
                                        R("ribbon", 0, 12, 10, 26, 3, "#1CB0F6")])],
                p=(22, -76), r=osc(-12, 12, P), parent=body)

    if sport == "bike":   # kaki dekat di depan badan, tetap di belakang tangan
        for name, shapes, kw in bike["near"]:
            c.layer(name, shapes, **kw)

    head_y = -84 - (26 if a.get("neck") else 0)
    head_r = osc(-8, 8, P) if sport == "swim" else (osc(-2, 2, yoga_p) if sport == "yoga" else osc(-4, 4, P * 2))
    if sport == "dance":   # kepala angguk-angguk ikut ketukan, arah berlawanan dengan badan
        head_r = loop_io([(0, 8), (0.25, -4), (0.5, -8), (0.75, 4)], DANCE_BEAT[si] * 2)
    arm_front_p = (-30, shoulder_y) if sport == "swim" else (46, shoulder_y)
    arm_behind_head = sport in ("swim", "badminton")   # renang & smash: tangan/raket lewat di belakang kepala, muka tetap terlihat
    if arm_behind_head:
        c.layer("Arm front", arm_shapes(a, shirt) + front_extra, p=arm_front_p, r=arm_front_r, parent=body)
    head_p = (0, head_y)
    if sport == "swim":   # kepala tetap tegak di atas air walau badan rebah
        head_p, head_r = (-24, head_y - 18), osc(-85, -95, P)
    head = c.layer("Head", head_shapes(a, si, cfg)[::-1], p=head_p, r=head_r, parent=body)

    if not arm_behind_head:
        c.layer("Arm front", arm_shapes(a, shirt) + front_extra, p=arm_front_p, r=arm_front_r, parent=body)

    # properti depan
    if sport == "swim":
        waves = [E(f"crest{i}", -260 + i * 70, 0, 80, 34, WATER_FRONT) for i in range(9)]
        c.layer("Water front", [R("w", 0, 60, 560, 120, 0, WATER_FRONT)] + waves,
                p=osc([200, rig_y + 18, 0], [180, rig_y + 24, 0], P * 2))   # punggung & lengan tampak di atas air
        if si >= 1:
            for i in range(3 + si):
                c.layer(f"Splash {i}", [E("d", 0, 0, 14, 18, "#FFFFFF")],
                        p=cyc([(0, [200 + (i - 1.5) * 34, rig_y - 10, 0]), (0.5, [200 + (i - 1.5) * 50, rig_y - 60 - si * 8, 0]),
                               (1, [200 + (i - 1.5) * 64, rig_y + 10, 0])], P, i / (3 + si)),
                        o=cyc([(0, 0), (0.2, 100), (0.8, 100), (1, 0)], P, i / (3 + si)))
    if sport == "surf":
        waves = [E(f"crest{i}", -260 + i * 70, 0, 80, 30 + si * 4, WATER_FRONT) for i in range(9)]
        c.layer("Water front", [R("w", 0, 60, 560, 120, 0, WATER_FRONT)] + waves,
                p=cyc([(0, [200, rig_y + 40, 0]), (1, [130, rig_y + 40, 0])], SP))
        if si >= 1:
            for i in range(2 + si):
                c.layer(f"Spray {i}", [E("d", 0, 0, 12, 16, "#FFFFFF")],
                        p=cyc([(0, [90, rig_y + 20, 0]), (0.5, [60 - i * 10, rig_y - 20 - si * 10, 0]),
                               (1, [30 - i * 16, rig_y + 30, 0])], SP, i / (2 + si)),
                        o=cyc([(0, 0), (0.2, 100), (0.8, 100), (1, 0)], SP, i / (2 + si)))
    if sport == "badminton":
        shuttle = [grp("cork", [ell((0, 10), (16, 16)), fill("#FF4B4B")]),
                   grp("feather", [path([(-8, 6), (8, 6), (16, -22), (-16, -22)]), fill("#FFFFFF")]),
                   grp("ln", [path([(-16, -22), (16, -22)], closed=False), stroke("#AFAFAF", 2)])][::-1]
        # kok datang dari kanan atas, kena kepala raket saat smash, lalu melesat turun ke kanan
        u_hit = 0.45 + 0.15 * (215 - 160) / 130
        by = -46 - BADMINTON_JUMP[si] * (u_hit - 0.45) / 0.15
        th = math.radians(215)
        hit = [round(46 - 104 * math.sin(th)), round(-70 + 104 * math.cos(th) + by), 0]
        c.layer("Shuttle", shuttle,
                p=track([(0.08, [330, -330, 0], "lin"), (u_hit, hit, "lin"), (u_hit + 0.09, [380, -10, 0], "hold")], SP),
                r=track([(0.08, 60, "hold"), (u_hit, 60, "lin"), (u_hit + 0.02, -55, "hold")], SP), parent=rig)
    if sport == "padel":
        # bola kena raket di ujung ayunan depan, melambung keluar, lalu kembali memantul di lantai ke raket
        hit = [148, -98, 0]
        c.layer("Ball", [E("b", 0, 0, 24, 24, "#D7FF3A"), grp("seam", [ell((0, 0), (16, 24)), stroke("#FFFFFF", 2)])][::-1],
                p=track([(0, hit, "out"), (0.4, [340, -230, 0], "hold"), (0.5, [340, -110, 0], "in"),
                         (0.8, [150, -8, 0], "out")], SP), parent=rig)
    if sport == "soccer":
        ball = [E("b", 0, 0, 40, 40, "#FFFFFF"), E("p1", 0, 0, 14, 14, INK), E("p2", -13, -10, 9, 9, INK),
                E("p3", 13, -10, 9, 9, INK), E("p4", 0, 15, 9, 9, INK)][::-1]
        # juggling: bola jatuh ke punggung kaki yang terangkat lalu memantul lagi ke atas (tidak menembus kepala)
        top = -170 - si * 6
        c.layer("Ball", ball, p=track([(0.05, [104, top, 0], "in"), (0.55, [66, -58, 0], "out")], SP),
                r=spin(0, 2 + si), parent=rig)
    if sport == "frisbee":
        c.layer("Disc", [grp("ring", [ell((0, 0), (34, 8)), stroke("#FFFFFF", 2)]), E("disc", 0, 0, 50, 14, "#FF4B4B")],
                p=cyc([(0, [95, -132, 0]), (0.55, [95, -132, 0]), (1, [300, -210 - si * 10, 0])], SP),
                o=cyc([(0, 0), (0.55, 0), (0.56, 100), (1, 100)], SP), r=osc(-10, 10, SP / 2), parent=rig)
        if si >= 3:   # Juara+: jejak kilau di belakang piringan
            for i in range(3):
                c.layer(f"Trail {i}", [grp("s", [star4(0, 0, 8), fill("#FFFFFF")])],
                        p=cyc([(0, [95, -132, 0]), (0.55, [95, -132, 0]), (1, [300 - (i + 1) * 40, -210 + (i + 1) * 14, 0])], SP),
                        o=cyc([(0, 0), (0.6, 0), (0.62, 100), (1, 0)], SP), parent=rig)
    if sport == "pingpong":
        c.layer("Table", [R("line", 120, -14, 150, 2, 1, "#FFFFFF"), R("net", 120, -27, 4, 26, 2, "#FFFFFF"),
                          R("top", 120, -10, 150, 12, 4, "#1F6FD1"), R("leg", 70, 30, 8, 70, 3, INK),
                          R("leg", 170, 30, 8, 70, 3, INK)], parent=rig)
        bp = SP / (2 if si >= 2 else 1)
        c.layer("Ball", [E("b", 0, 0, 14, 14, "#FFFFFF"), grp("o", [ell((0, 0), (14, 14)), stroke("#FF9600", 2)])][::-1],
                p=cyc([(0, [116, -84, 0]), (0.3, [150, -118, 0]), (0.55, [170, -18, 0]), (0.8, [140, -70, 0]),
                       (1, [116, -84, 0])], bp), parent=rig)
    if sport == "basket":
        ball = [E("b", 0, 0, 40, 40, "#FF9600"), R("h", 0, 0, 40, 3, 1, INK), R("v", 0, 0, 3, 40, 1, INK)][::-1]
        if si >= 3:   # dribel lalu tembak ke atas
            c.layer("Ball", ball, p=cyc([(0, [62, -52, 0]), (0.25, [62, -14, 0]), (0.5, [62, -52, 0]), (0.65, [60, -210, 0]),
                                         (0.85, [160, -320, 0]), (1, [62, -52, 0])], LOOP / 2),
                    o=cyc([(0, 100), (0.84, 100), (0.86, 0), (0.98, 0), (1, 100)], LOOP / 2), parent=rig)
        else:
            # dribel: jatuh makin cepat ke lantai, memantul, melambat di telapak tangan
            c.layer("Ball", ball, p=track([(0, [62, -52, 0], "in"), (0.5, [62, -14, 0], "out")], SP / 2), parent=rig)
    if sport == "martial":
        MP = MARTIAL_P[si]
        punch_u = (0.38, 0.55) if si < 2 else (0.18, 0.34)
        c.layer("Pow", [grp("s", [star4(0, 0, 18), fill("#FFFFFF")])],
                p=(122, -116), s=pop_at(*punch_u, MP), r=spin(0, 1), parent=rig)
        if si >= 2:
            c.layer("Pow kick", [grp("s", [star4(0, 0, 22), fill("#FFC800")])],
                    p=(96, -66 if si < 4 else -98), s=pop_at(0.64, 0.82, MP), r=spin(0, 1), parent=rig)
    if sport == "dance":
        for i, col in enumerate(["#CE82FF", "#1CB0F6", "#FF4B4B"][: 1 + min(si, 2)]):
            c.layer(f"Note {i}", note(col)[::-1],
                    p=cyc([(0, [(70, 330, 105)[i], 270, 0]), (1, [(90, 315, 80)[i], 80, 0])], LOOP, i / 3),   # di samping, tidak menutup muka
                    o=cyc([(0, 0), (0.2, 100), (0.8, 100), (1, 0)], LOOP, i / 3),
                    r=osc(-15, 15, DANCE_BEAT[si] * 2))
    if sport == "archery":
        c.layer("Target", [E("c", 0, 0, 12, 12, "#FFC800"), E("r3", 0, 0, 26, 26, "#FF4B4B"), E("r2", 0, 0, 40, 40, "#FFFFFF"),
                           E("r1", 0, 0, 54, 54, "#FF4B4B"), R("stand", 0, 70, 8, 110, 3, "#8B5A2B")],
                p=(140, -116), r=cyc([(0, 0), (0.6, 0), (0.65, 8), (0.75, -4), (0.85, 0), (1, 0)], SP), parent=rig)
        hit_y = [-90, -106, -112, -116, -116][si]   # Pemula masih meleset, Juara+ kena tengah
        c.layer("Arrow", [grp("head", [path([(28, -6), (40, 0), (28, 6)]), fill(INK)]),
                          R("shaft", 4, 0, 52, 4, 2, "#8B5A2B"),
                          grp("fletch", [path([(-22, 0), (-14, -8), (-8, -8), (-14, 0), (-8, 8), (-14, 8)]), fill("#FF4B4B")])],
                p=cyc([(0, [76, -116, 0]), (0.5, [46, -116, 0]), (0.6, [104, hit_y, 0]), (1, [104, hit_y, 0])], SP),
                o=cyc([(0, 0), (0.08, 100), (0.9, 100), (1, 0)], SP), parent=rig)

    if si == 0:
        c.layer("Sweat", [E("drop", 0, 0, 12, 17, "#84D8FF")],
                p=cyc([(0, [64, -120, 0]), (1, [76, -60, 0])], 60), o=cyc([(0, 100), (0.8, 100), (1, 0)], 60), parent=head)
    if si == 4:
        for i, (x, y) in enumerate([(70, 90), (330, 100), (350, 240), (50, 230), (200, 40)]):
            c.layer(f"Sparkle {i}", [grp("s", [star4(0, 0, 14), fill("#FFFFFF")])],
                    p=(x, y), s=osc([0, 0], [110, 110], 30, i / 5), r=spin(0, 1))

    c.layers.reverse()
    return c.layers


def _darker(hexc):
    h = hexc.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return "#%02X%02X%02X" % (int(r * 0.85), int(g * 0.85), int(b * 0.85))


def circle_mask(cx=200, cy=200, r=190):
    k = r * 0.5523
    v = [[cx, cy - r], [cx + r, cy], [cx, cy + r], [cx - r, cy]]
    i = [[-k, 0], [0, -k], [k, 0], [0, k]]
    o = [[k, 0], [0, k], [-k, 0], [0, -k]]
    return {"inv": False, "mode": "a", "nm": "Lingkaran", "o": {"a": 0, "k": 100}, "x": {"a": 0, "k": 0},
            "pt": {"a": 0, "k": {"i": i, "o": o, "v": v, "c": True}}}


def comp(name, layers, op=LOOP, markers=None):
    # semua isi (air, tebing, aura, properti) dipotong ke lingkaran latar supaya bentuknya seragam
    scene = {"ddd": 0, "ind": 1, "ty": 0, "nm": "Scene", "refId": "scene", "sr": 1,
             "ks": {"o": {"a": 0, "k": 100}, "r": {"a": 0, "k": 0}, "p": {"a": 0, "k": [0, 0, 0]},
                    "a": {"a": 0, "k": [0, 0, 0]}, "s": {"a": 0, "k": [100, 100, 100]}},
             "ao": 0, "hasMask": True, "masksProperties": [circle_mask()], "w": W, "h": H,
             "ip": 0, "op": op, "st": 0, "bm": 0}
    return {"v": "5.7.4", "fr": FR, "ip": 0, "op": op, "w": W, "h": H, "nm": name, "ddd": 0,
            "assets": [{"id": "scene", "layers": layers}], "layers": [scene], "markers": markers or []}


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "animals")
    os.makedirs(out, exist_ok=True)
    for a in ANIMALS:
        combined, markers = [], []
        for si, cfg in enumerate(STAGES):
            layers = build(a, si)
            with open(os.path.join(out, f"{a['key']}_{cfg['key']}.json"), "w", encoding="utf-8") as f:
                json.dump(comp(f"Klubby {a['name']} – {cfg['label']}", layers), f, separators=(",", ":"))
            off, base = si * LOOP, si * 1000
            for L in json.loads(json.dumps(layers)):
                L["ind"] += base
                if "parent" in L:
                    L["parent"] += base
                L["st"], L["ip"], L["op"] = off, off, off + LOOP
                combined.append(L)
            markers.append({"tm": off, "cm": cfg["key"], "dr": LOOP})
        with open(os.path.join(out, f"{a['key']}_evolution.json"), "w", encoding="utf-8") as f:
            json.dump(comp(f"Klubby {a['name']} – Streak Evolution", combined, op=LOOP * len(STAGES), markers=markers),
                      f, separators=(",", ":"))
    print("ok", len(ANIMALS) * len(STAGES), "files")


if __name__ == "__main__":
    main()
