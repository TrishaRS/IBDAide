package com.ibdaide.app.ui

import android.graphics.Bitmap
import android.graphics.ImageDecoder
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Whatshot
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import com.ibdaide.app.core.FoodEvaluation
import com.ibdaide.app.core.FoodRulesEngine
import com.ibdaide.app.core.IngredientInference
import com.ibdaide.app.core.OpenFoodFactsClient
import com.ibdaide.app.data.AppDao
import com.ibdaide.app.data.FoodEntry
import com.ibdaide.app.data.ScannedProduct
import kotlinx.coroutines.launch

@Composable
fun ScanScreen(dao: AppDao, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val profile by dao.profileFlow().collectAsState(initial = null)
    val triggers by dao.triggersFlow().collectAsState(initial = emptyList())
    val triggerNames = triggers.map { it.name }
    val flareMode = profile?.flareMode == true

    var mode by remember { mutableStateOf(0) } // 0 barcode, 1 dish, 2 lookup
    var manualBarcode by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var resultTitle by remember { mutableStateOf("") }
    var resultSubtitle by remember { mutableStateOf("") }
    var uncertain by remember { mutableStateOf(false) }
    var evaluation by remember { mutableStateOf<FoodEvaluation?>(null) }

    suspend fun lookupBarcode(code: String) {
        loading = true; error = null; evaluation = null
        try {
            val clean = code.filter { it.isDigit() }
            val product = dao.cachedProduct(clean)?.let {
                com.ibdaide.app.core.OFFProduct(it.barcode, it.name, it.brand, it.ingredientsText)
            } ?: OpenFoodFactsClient.fetch(clean).also {
                dao.upsert(ScannedProduct(it.barcode, it.name, it.brand, it.ingredientsText))
            }
            if (product.ingredientsText.isEmpty()) {
                error = "No ingredient list on file for this product. Try photographing the label in Dish photo mode."
            } else {
                resultTitle = product.name
                resultSubtitle = (if (product.brand.isEmpty()) "" else product.brand + " · ") +
                        "Open Food Facts · evaluated on-device"
                uncertain = false
                evaluation = FoodRulesEngine.evaluate(product.ingredientsText, triggerNames, flareMode)
            }
        } catch (e: Exception) {
            error = e.message
        } finally {
            loading = false
        }
    }

    suspend fun analyzeBitmap(bitmap: Bitmap) {
        loading = true; error = null; evaluation = null
        try {
            val ocr = IngredientInference.ocrText(bitmap)
            if (ocr.lowercase().contains("ingredient") || ocr.length > 120) {
                resultTitle = "Ingredient label"
                resultSubtitle = "Read on-device with text recognition"
                uncertain = false
                evaluation = FoodRulesEngine.evaluate(ocr, triggerNames, flareMode)
            } else {
                val dish = IngredientInference.analyzeDish(bitmap)
                if (dish.labels.isEmpty()) {
                    error = "Couldn't identify this dish. Try a clearer photo or the ingredient label."
                } else {
                    val eval = FoodRulesEngine.evaluateDish(dish.labels, dish.likelyIngredients, triggerNames, flareMode)
                    resultTitle = eval.dishName ?: dish.labels.first().replaceFirstChar(Char::uppercase)
                    resultSubtitle = "Likely ingredients via on-device image analysis" +
                            if (eval.dishName != null) " · matched in the built-in food guide" else ""
                    uncertain = true
                    evaluation = eval
                }
            }
        } catch (e: Exception) {
            error = "Analysis failed: ${e.message}"
        } finally {
            loading = false
        }
    }

    // In-app camera capture (lesson from iOS build: dish photos must be takeable in-app)
    val cameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bitmap ->
        bitmap?.let { scope.launch { analyzeBitmap(it) } }
    }
    val libraryLauncher = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        uri?.let {
            scope.launch {
                runCatching {
                    ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, it)) { d, _, _ ->
                        d.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                    }
                }.getOrNull()?.let { bmp -> analyzeBitmap(bmp) } ?: run { error = "Couldn't read that photo." }
            }
        }
    }

    Column(
        modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("Scan", style = MaterialTheme.typography.headlineSmall)
            profile?.let { p ->
                FilterChip(
                    selected = p.flareMode,
                    onClick = { scope.launch { dao.upsertProfile(p.copy(flareMode = !p.flareMode)) } },
                    label = { Text(if (p.flareMode) "Flare mode ON" else "Flare mode off") },
                    leadingIcon = { Icon(Icons.Default.Whatshot, contentDescription = null) },
                )
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("Barcode", "Dish photo", "Lookup").forEachIndexed { i, label ->
                FilterChip(selected = mode == i, onClick = { mode = i; error = null }, label = { Text(label) })
            }
        }

        when (mode) {
            0 -> {
                Button(onClick = {
                    GmsBarcodeScanning.getClient(context).startScan()
                        .addOnSuccessListener { barcode ->
                            barcode.rawValue?.let { scope.launch { lookupBarcode(it) } }
                        }
                        .addOnFailureListener { error = "Scanner unavailable: ${it.message}" }
                }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Default.QrCodeScanner, contentDescription = null)
                    Text("  Scan a barcode")
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = manualBarcode, onValueChange = { manualBarcode = it },
                        label = { Text("Or enter barcode digits") }, modifier = Modifier.weight(1f))
                    OutlinedButton(
                        onClick = { scope.launch { lookupBarcode(manualBarcode) } },
                        enabled = manualBarcode.filter { it.isDigit() }.length >= 8,
                    ) { Text("Look up") }
                }
            }
            1 -> {
                Button(onClick = { cameraLauncher.launch(null) }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Default.CameraAlt, contentDescription = null)
                    Text("  Take a photo of the dish or label")
                }
                OutlinedButton(onClick = {
                    libraryLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Default.PhotoLibrary, contentDescription = null)
                    Text("  Or choose an existing photo")
                }
                Text("Analyzed on this phone — the photo never leaves your device.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            else -> FoodLookupSection(dao, triggerNames, flareMode)
        }

        if (mode != 2) {
            if (loading) CircularProgressIndicator(Modifier.padding(8.dp))
            error?.let { Text(it, color = Brand.Red, style = MaterialTheme.typography.bodySmall) }
            evaluation?.let { eval ->
                EvaluationCard(resultTitle, resultSubtitle, eval, uncertain)
                OutlinedButton(onClick = {
                    scope.launch {
                        dao.insert(FoodEntry(name = resultTitle,
                            source = if (mode == 0) "barcode" else "dish-scan"))
                    }
                }) { Text("Log as meal") }
            }
            Text("Estimates only — can be wrong or incomplete. Not medical advice. Photos never leave your phone.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
