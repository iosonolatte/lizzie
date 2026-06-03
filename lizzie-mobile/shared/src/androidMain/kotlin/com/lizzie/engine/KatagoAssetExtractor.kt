package com.lizzie.engine

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileOutputStream

/**
 * Extracts bundled KataGo binary and model files from Android assets to
 * internal storage so they can be executed.
 *
 * Assets location:
 *   katago/arm64-v8a/katago        — native binary
 *   katago/configs/gtp.cfg         — KataGo config
 *   katago/models/ (model files, e.g. .bin.gz)         — network weights
 */
class KatagoAssetExtractor(private val context: Context) {

    companion object {
        private const val TAG = "KatagoExtractor"
        private const val ASSET_PREFIX = "katago"
    }

    data class ExtractedFiles(
        val binaryPath: String,
        val configPath: String?,
        val modelPath: String?,
        val workingDir: String,
    )

    /**
     * Extract all KataGo files to internal storage.
     * Returns paths to the extracted files.
     */
    fun extract(): ExtractedFiles {
        val targetDir = File(context.filesDir, "katago")
        targetDir.mkdirs()

        val binaryDir = File(targetDir, "arm64-v8a")
        binaryDir.mkdirs()

        val configDir = File(targetDir, "configs")
        configDir.mkdirs()

        val modelsDir = File(targetDir, "models")
        modelsDir.mkdirs()

        // Extract binary from assets
        val binaryFile = File(binaryDir, "katago")
        if (!binaryFile.exists()) {
            extractAsset("$ASSET_PREFIX/arm64-v8a/katago", binaryFile)
            binaryFile.setExecutable(true)
            Log.i(TAG, "Extracted binary: ${binaryFile.absolutePath}")
        }

        // Extract config
        val configFile = File(configDir, "gtp.cfg")
        if (!configFile.exists()) {
            try {
                extractAsset("$ASSET_PREFIX/configs/gtp.cfg", configFile)
            } catch (e: Exception) {
                Log.w(TAG, "No bundled config found, mobile defaults will be used")
            }
        }

        // Find model
        val modelFile = findModelFile(modelsDir)

        return ExtractedFiles(
            binaryPath = binaryFile.absolutePath,
            configPath = if (configFile.exists()) configFile.absolutePath else null,
            modelPath = modelFile?.absolutePath,
            workingDir = targetDir.absolutePath,
        )
    }

    /**
     * Check if assets are bundled (return false if not yet downloaded).
     */
    fun hasAssets(): Boolean {
        return try {
            context.assets.open("$ASSET_PREFIX/arm64-v8a/katago").use { true }
        } catch (e: Exception) {
            false
        }
    }

    private fun findModelFile(modelsDir: File): File? {
        val candidates = modelsDir.listFiles { f ->
            f.name.endsWith(".bin.gz") || f.name.endsWith(".txt.gz")
        }
        return candidates?.firstOrNull()
    }

    private fun extractAsset(assetPath: String, destFile: File) {
        destFile.parentFile?.mkdirs()
        context.assets.open(assetPath).use { input ->
            FileOutputStream(destFile).use { output ->
                input.copyTo(output)
            }
        }
    }
}