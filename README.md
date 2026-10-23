# Klubby (Sports Community & Habit App) 🏸🏃‍♂️🏊‍♂️

> **The Hybrid of Reclub (Community & Tournaments) + Strava (Tracking & Dashboards) + Duolingo (2D Cute Gamification & Streak Evolution)**

Platform manajemen komunitas olahraga dan sesi main bareng (*mabar*) yang menggabungkan kemudahan logistik mabar, pencatatan performa multi-sport, dengan sentuhan visual kartun 2D dan psikologi streak ala Duolingo.

---

## 📚 Dokumentasi Proyek

1. **[MASTER_KLUBBY_BLUEPRINT.md](./MASTER_KLUBBY_BLUEPRINT.md)** — Master Blueprint lengkap yang mencakup latar belakang, katalog 10 modul fitur, analisis risiko & celah beserta solusinya, integrasi wearable (Samsung, Apple, Xiaomi, Amazfit, Huawei), hingga strategi bisnis berjenjang.
2. **[PRD_SPORTS_COMMUNITY_APP.md](./PRD_SPORTS_COMMUNITY_APP.md)** — Product Requirement Document (PRD) versi standar industri untuk engineering dan desainer UI/UX.
3. **[product_concept_hybrid.md](./product_concept_hybrid.md)** — Konsep awal penggabungan Reclub + Strava.
4. **[reclub_features.md](./reclub_features.md)** — Riset lengkap fitur aplikasi Reclub.
5. **[strava_features.md](./strava_features.md)** — Riset komparasi fitur Strava (Free vs Subscription).

---

## 🎨 Desain, Aset & Animasi

* **[swimmer_evolution.html](./swimmer_evolution.html)** — Simulasi interaktif animasi karakter perenang kartun (Eddy Duolingo Style):
  * **Hari 1:** Pemula (Pelampung bebek & kacamata miring).
  * **Hari 3:** Gaya bebas cepat (*crawl speed*).
  * **Streak 7+ Hari:** *Mode Kincir Angin Turbo (Windmill Arms)* dengan kecepatan perahu motor (*speedboat*).
* **[swimmer_streak_animation.json](./swimmer_streak_animation.json)** — File animasi Lottie siap pakai untuk Flutter / React Native.
* **`reclubv2.pen` & folder `images/`** — File desain canvas pen.dev yang berisi 2 Board Aset Gamifikasi dan 5 Layar Mobile (Home Feed, Clubs/Mabar, Record/Check-in, Leaderboard, Profile/Dashboard).

---

## 🛠️ Rekomendasi Tech Stack

* **Mobile App:** Flutter / React Native (iOS & Android)
* **Web Companion:** Next.js + TailwindCSS (WhatsApp Web-RSVP)
* **Backend:** Go / Node.js + Supabase (PostgreSQL & PostGIS)
* **Integrasi Sensor:** Google Health Connect, Apple HealthKit, Strava API
* **Pembayaran:** Midtrans / Xendit (QRIS Dinamis Otomatis)
