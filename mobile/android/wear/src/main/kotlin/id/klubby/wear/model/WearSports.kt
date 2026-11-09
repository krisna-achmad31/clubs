package id.klubby.wear.model

import androidx.health.services.client.data.ExerciseType

/** How the live screen shows speed for a sport (same units as the phone app). */
enum class SpeedUnit { PACE_KM, PACE_100M, KMH, NONE }

/**
 * A Klubby sport the watch can record. [id] matches `Sports.all` in the phone
 * app (lib/core/entities/sport.dart), so a synced workout lands on the right sport.
 */
data class WearSport(
    val id: String,
    val name: String,
    val emoji: String,
    val type: ExerciseType,
    /** Uses GPS: route, distance, pace, elevation. */
    val outdoor: Boolean = false,
    /** Shows distance (outdoor GPS or pool lengths). */
    val distance: Boolean = outdoor,
    val speed: SpeedUnit = if (distance) SpeedUnit.PACE_KM else SpeedUnit.NONE,
    /** Auto-pause is offered for running and cycling only, like Strava. */
    val autoPause: Boolean = false,
)

object WearSports {
    val all: List<WearSport> = listOf(
        WearSport("lari", "Lari", "🏃", ExerciseType.RUNNING, outdoor = true, autoPause = true),
        WearSport("jalan", "Jalan", "🚶", ExerciseType.WALKING, outdoor = true, autoPause = true),
        WearSport("sepeda", "Sepeda", "🚴", ExerciseType.BIKING, outdoor = true, speed = SpeedUnit.KMH, autoPause = true),
        WearSport("trail", "Trail Run", "⛰️", ExerciseType.RUNNING, outdoor = true, autoPause = true),
        WearSport("mtb", "MTB", "🚵", ExerciseType.BIKING, outdoor = true, speed = SpeedUnit.KMH, autoPause = true),
        WearSport("hiking", "Hiking", "🥾", ExerciseType.HIKING, outdoor = true),
        WearSport("renang", "Renang (kolam)", "🏊", ExerciseType.SWIMMING_POOL, distance = true, speed = SpeedUnit.PACE_100M),
        WearSport("badminton", "Badminton", "🏸", ExerciseType.BADMINTON),
        WearSport("padel", "Padel", "🎾", ExerciseType.TENNIS),
        WearSport("tenis", "Tenis", "🎾", ExerciseType.TENNIS),
        WearSport("pickleball", "Pickleball", "🏓", ExerciseType.TENNIS),
        WearSport("tenis_meja", "Tenis Meja", "🏓", ExerciseType.TABLE_TENNIS),
        WearSport("squash", "Squash", "🎾", ExerciseType.SQUASH),
        WearSport("futsal", "Futsal", "⚽", ExerciseType.SOCCER),
        WearSport("mini_soccer", "Mini Soccer", "⚽", ExerciseType.SOCCER),
        WearSport("sepak_bola", "Sepak Bola", "⚽", ExerciseType.SOCCER),
        WearSport("basket", "Basket", "🏀", ExerciseType.BASKETBALL),
        WearSport("voli", "Voli", "🏐", ExerciseType.VOLLEYBALL),
        WearSport("fitness", "Fitness", "🏋️", ExerciseType.STRENGTH_TRAINING),
        WearSport("yoga", "Yoga", "🧘", ExerciseType.YOGA),
        WearSport("pilates", "Pilates", "🧘", ExerciseType.PILATES),
        WearSport("senam", "Senam", "💃", ExerciseType.DANCING),
        WearSport("tinju", "Tinju", "🥊", ExerciseType.BOXING),
        WearSport("bela_diri", "Bela Diri", "🥋", ExerciseType.MARTIAL_ARTS),
    )

    fun byId(id: String?): WearSport = all.firstOrNull { it.id == id } ?: all.first()

    fun byType(type: ExerciseType): WearSport = all.firstOrNull { it.type == type } ?: all.first()

    /** Most-used sports first (Strava does the same), then the rest in catalogue order. */
    fun ordered(recentIds: List<String>): List<WearSport> {
        val recent = recentIds.mapNotNull { id -> all.firstOrNull { it.id == id } }
        return recent + all.filterNot { it in recent }
    }
}
