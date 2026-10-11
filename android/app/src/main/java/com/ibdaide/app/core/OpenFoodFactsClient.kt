package com.ibdaide.app.core

import com.google.gson.JsonParser
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/** Open Food Facts lookups. Only barcode digits or a user-typed food name are sent (NFR-2). */

data class OFFProduct(val barcode: String, val name: String, val brand: String, val ingredientsText: String)

class OFFException(message: String) : Exception(message)

object OpenFoodFactsClient {

    private const val UA = "IBDAide/1.0 (Android; contact: trisha.rsny@gmail.com)"

    private fun get(url: String): String {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.setRequestProperty("User-Agent", UA)
        conn.connectTimeout = 10_000
        conn.readTimeout = 15_000
        try {
            if (conn.responseCode != 200) throw OFFException("Couldn't reach the food database (HTTP ${conn.responseCode}).")
            return conn.inputStream.bufferedReader().readText()
        } finally {
            conn.disconnect()
        }
    }

    suspend fun fetch(barcode: String): OFFProduct = withContext(Dispatchers.IO) {
        val clean = barcode.filter { it.isDigit() }
        val body = get("https://world.openfoodfacts.org/api/v2/product/$clean?fields=product_name,brands,ingredients_text")
        val root = JsonParser.parseString(body).asJsonObject
        if (root.get("status")?.asInt != 1) {
            throw OFFException("Product not found. Try photographing the ingredient label instead.")
        }
        val p = root.getAsJsonObject("product")
        val ingredients = p?.get("ingredients_text")?.takeIf { !it.isJsonNull }?.asString ?: ""
        OFFProduct(
            barcode = clean,
            name = p?.get("product_name")?.takeIf { !it.isJsonNull }?.asString ?: "Unknown product",
            brand = p?.get("brands")?.takeIf { !it.isJsonNull }?.asString ?: "",
            ingredientsText = ingredients,
        )
    }

    suspend fun search(name: String): List<OFFProduct> = withContext(Dispatchers.IO) {
        val q = URLEncoder.encode(name, "UTF-8")
        val body = get("https://world.openfoodfacts.org/cgi/search.pl?search_terms=$q&search_simple=1&action=process&json=1&page_size=10&fields=code,product_name,brands,ingredients_text")
        val root = JsonParser.parseString(body).asJsonObject
        (root.getAsJsonArray("products") ?: return@withContext emptyList())
            .mapNotNull { el ->
                val p = el.asJsonObject
                val ingredients = p.get("ingredients_text")?.takeIf { !it.isJsonNull }?.asString ?: ""
                if (ingredients.isEmpty()) null
                else OFFProduct(
                    barcode = p.get("code")?.takeIf { !it.isJsonNull }?.asString ?: "",
                    name = p.get("product_name")?.takeIf { !it.isJsonNull }?.asString ?: "Unknown product",
                    brand = p.get("brands")?.takeIf { !it.isJsonNull }?.asString ?: "",
                    ingredientsText = ingredients,
                )
            }
    }
}
