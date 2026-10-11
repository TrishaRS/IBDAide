package com.ibdaide.app.core

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.tasks.await

/**
 * FR-5: on-device dish analysis. Photos never leave the device.
 * - ML Kit Text Recognition (OCR) for ingredient labels
 * - ML Kit Image Labeling for dish identification → matched against the
 *   FoodKnowledgeBase dish inventory by the rules engine
 * On Gemini Nano / Galaxy AI devices this can later be upgraded to the ML Kit
 * GenAI image-description API — see README.
 */
object IngredientInference {

    data class DishResult(val labels: List<String>, val likelyIngredients: List<String>)

    suspend fun ocrText(bitmap: Bitmap): String {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val result = recognizer.process(InputImage.fromBitmap(bitmap, 0)).await()
        return result.text
    }

    suspend fun analyzeDish(bitmap: Bitmap): DishResult {
        val labeler = ImageLabeling.getClient(
            ImageLabelerOptions.Builder().setConfidenceThreshold(0.45f).build())
        val labels = labeler.process(InputImage.fromBitmap(bitmap, 0)).await()
            .map { it.text.lowercase() }
            .take(10)
        // Ingredient hints come from the knowledge-base dish inventory (rules engine
        // merges them); labels themselves also feed the keyword matcher.
        return DishResult(labels = labels, likelyIngredients = labels)
    }
}
