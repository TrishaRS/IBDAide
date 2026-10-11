package com.ibdaide.app.data

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface AppDao {
    // Profile
    @Query("SELECT * FROM user_profile WHERE id = 1") fun profileFlow(): Flow<UserProfile?>
    @Query("SELECT * FROM user_profile WHERE id = 1") suspend fun profile(): UserProfile?
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun upsertProfile(p: UserProfile)

    // Symptoms & BMs
    @Query("SELECT * FROM symptom_entries ORDER BY date DESC") fun symptomsFlow(): Flow<List<SymptomEntry>>
    @Query("SELECT * FROM symptom_entries") suspend fun symptoms(): List<SymptomEntry>
    @Insert suspend fun insert(e: SymptomEntry)
    @Query("SELECT * FROM bm_entries ORDER BY date DESC") fun bmsFlow(): Flow<List<BowelMovementEntry>>
    @Query("SELECT * FROM bm_entries") suspend fun bms(): List<BowelMovementEntry>
    @Insert suspend fun insert(e: BowelMovementEntry)

    // Food & hydration & triggers
    @Query("SELECT * FROM food_entries ORDER BY date DESC") fun foodsFlow(): Flow<List<FoodEntry>>
    @Query("SELECT * FROM food_entries") suspend fun foods(): List<FoodEntry>
    @Insert suspend fun insert(e: FoodEntry)
    @Insert suspend fun insert(e: HydrationEntry)
    @Query("SELECT * FROM hydration_entries") suspend fun hydration(): List<HydrationEntry>
    @Query("SELECT * FROM trigger_foods ORDER BY name") fun triggersFlow(): Flow<List<TriggerFood>>
    @Query("SELECT * FROM trigger_foods") suspend fun triggers(): List<TriggerFood>
    @Insert suspend fun insert(t: TriggerFood)
    @Delete suspend fun delete(t: TriggerFood)

    // Medications & doses
    @Query("SELECT * FROM medications ORDER BY name") fun medsFlow(): Flow<List<Medication>>
    @Query("SELECT * FROM medications") suspend fun meds(): List<Medication>
    @Query("SELECT * FROM medications WHERE id = :id") suspend fun med(id: String): Medication?
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun upsert(m: Medication)
    @Delete suspend fun delete(m: Medication)
    @Query("SELECT * FROM dose_events ORDER BY recordedAt DESC") fun dosesFlow(): Flow<List<DoseEvent>>
    @Query("SELECT * FROM dose_events") suspend fun doses(): List<DoseEvent>
    @Insert suspend fun insert(d: DoseEvent)

    // Providers & appointments & questions
    @Query("SELECT * FROM providers ORDER BY name") fun providersFlow(): Flow<List<Provider>>
    @Query("SELECT * FROM providers") suspend fun providers(): List<Provider>
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun upsert(p: Provider)
    @Delete suspend fun delete(p: Provider)
    @Query("SELECT * FROM appointments ORDER BY date") fun appointmentsFlow(): Flow<List<Appointment>>
    @Query("SELECT * FROM appointments") suspend fun appointments(): List<Appointment>
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun upsert(a: Appointment)
    @Delete suspend fun delete(a: Appointment)
    @Query("SELECT * FROM visit_questions ORDER BY createdAt DESC") fun questionsFlow(): Flow<List<VisitQuestion>>
    @Query("SELECT * FROM visit_questions") suspend fun questions(): List<VisitQuestion>
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun upsert(q: VisitQuestion)
    @Delete suspend fun delete(q: VisitQuestion)

    // QoL
    @Query("SELECT * FROM qol_checkins ORDER BY date") fun qolFlow(): Flow<List<QoLCheckin>>
    @Query("SELECT * FROM qol_checkins") suspend fun qol(): List<QoLCheckin>
    @Insert suspend fun insert(q: QoLCheckin)

    // Caches
    @Query("SELECT * FROM scanned_products WHERE barcode = :barcode") suspend fun cachedProduct(barcode: String): ScannedProduct?
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun upsert(p: ScannedProduct)
    @Query("SELECT * FROM news_items ORDER BY publishedAt DESC") fun newsFlow(): Flow<List<NewsItem>>
    @Query("SELECT * FROM news_items") suspend fun news(): List<NewsItem>
    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun insertAllNews(items: List<NewsItem>)
    @Update suspend fun update(item: NewsItem)

    // Wipe (settings ▸ delete all / restore)
    @Query("DELETE FROM user_profile") suspend fun wipeProfile()
    @Query("DELETE FROM symptom_entries") suspend fun wipeSymptoms()
    @Query("DELETE FROM bm_entries") suspend fun wipeBMs()
    @Query("DELETE FROM food_entries") suspend fun wipeFoods()
    @Query("DELETE FROM trigger_foods") suspend fun wipeTriggers()
    @Query("DELETE FROM hydration_entries") suspend fun wipeHydration()
    @Query("DELETE FROM medications") suspend fun wipeMeds()
    @Query("DELETE FROM dose_events") suspend fun wipeDoses()
    @Query("DELETE FROM providers") suspend fun wipeProviders()
    @Query("DELETE FROM appointments") suspend fun wipeAppointments()
    @Query("DELETE FROM visit_questions") suspend fun wipeQuestions()
    @Query("DELETE FROM qol_checkins") suspend fun wipeQoL()
    @Query("DELETE FROM scanned_products") suspend fun wipeProducts()
    @Query("DELETE FROM news_items") suspend fun wipeNews()

    suspend fun wipeAll() {
        wipeProfile(); wipeSymptoms(); wipeBMs(); wipeFoods(); wipeTriggers(); wipeHydration()
        wipeMeds(); wipeDoses(); wipeProviders(); wipeAppointments(); wipeQuestions()
        wipeQoL(); wipeProducts(); wipeNews()
    }
}

@Database(
    entities = [
        UserProfile::class, SymptomEntry::class, BowelMovementEntry::class, FoodEntry::class,
        TriggerFood::class, HydrationEntry::class, Medication::class, DoseEvent::class,
        Provider::class, Appointment::class, VisitQuestion::class, QoLCheckin::class,
        ScannedProduct::class, NewsItem::class,
    ],
    version = 1,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun dao(): AppDao

    companion object {
        @Volatile private var instance: AppDatabase? = null

        fun get(context: Context): AppDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(context.applicationContext, AppDatabase::class.java, "ibdaide.db")
                    .fallbackToDestructiveMigration()
                    .build()
                    .also { instance = it }
            }
    }
}
