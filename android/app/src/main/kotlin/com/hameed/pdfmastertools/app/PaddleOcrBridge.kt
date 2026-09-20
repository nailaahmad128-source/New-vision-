package com.hameed.pdfmastertools.app

import android.content.Context
import com.paddle.ocr.EngineConfig
import com.paddle.ocr.PaddleOCR
import com.paddle.ocr.PaddleOCRConfig
import com.paddle.ocr.model.OCRRunResult
import com.paddle.ocr.util.OpenCVUtils
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.File

class PaddleOcrBridge(
    private val context: Context,
) {
    companion object {
        const val CHANNEL = "com.hameed.pdfmastertools/paddle_ocr"

        private const val DET_MODEL = "models/det/inference.onnx"
        private const val REC_MODEL = "models/rec/inference.onnx"
        private const val REC_CONFIG = "models/rec/inference.yml"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val engineMutex = Mutex()

    @Volatile
    private var paddle: PaddleOCR? = null

    @Volatile
    private var disabled = false

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "recognizeFile" -> {
                val path = call.argument<String>("path")

                if (path.isNullOrBlank()) {
                    result.error(
                        "INVALID_PATH",
                        "OCR image path is missing",
                        null,
                    )
                    return
                }

                scope.launch {
                    try {
                        val output = recognizeFile(path)

                        result.success(output)
                    } catch (t: Throwable) {
                        result.error(
                            "PADDLE_OCR_FAILED",
                            t.message ?: "Paddle OCR failed",
                            null,
                        )
                    }
                }
            }

            "isAvailable" -> {
                result.success(!disabled)
            }

            else -> result.notImplemented()
        }
    }

    private suspend fun recognizeFile(path: String): Map<String, Any?> {
        if (disabled) {
            throw IllegalStateException("Paddle OCR is disabled after a previous initialization failure")
        }

        val file = File(path)

        if (!file.exists() || !file.isFile) {
            throw IllegalArgumentException("OCR file does not exist: $path")
        }

        val bytes = file.readBytes()

        if (bytes.isEmpty()) {
            throw IllegalArgumentException("OCR file is empty")
        }

        return engineMutex.withLock {
            val engine = getEngine()

            val result = engine.recognize(bytes)

            toMap(result)
        }
    }

    private suspend fun getEngine(): PaddleOCR {
        paddle?.let { return it }

        if (!OpenCVUtils.init(context)) {
            disabled = true
            throw IllegalStateException("OpenCV could not be initialized for Paddle OCR")
        }

        return try {
            val created = PaddleOCR.create(
                context = context,
                config = PaddleOCRConfig(
                    detImgMode = "BGR",
                    detLimitSideLen = 64,
                    detLimitType = "min",
                    detMaxSideLimit = 4000,
                    detThresh = 0.3f,
                    detBoxThresh = 0.6f,
                    detUnclipRatio = 1.5f,
                    detMaxCandidates = 3000,
                    detUseDilation = false,
                    detScoreMode = "fast",
                    detBoxType = "quad",
                    recScoreThresh = 0.0f,
                    recBatchSize = 1,
                ),
                engineConfig = EngineConfig(
                    numThreads = 4,
                ),
                detModelAssetPath = DET_MODEL,
                recModelAssetPath = REC_MODEL,
                recConfigAssetPath = REC_CONFIG,
            )

            paddle = created
            created
        } catch (t: Throwable) {
            disabled = true
            throw t
        }
    }

    private fun toMap(result: OCRRunResult): Map<String, Any?> {
        val lines = result.results.map { item ->
            mapOf(
                "text" to item.text,
                "confidence" to item.confidence.toDouble(),
                "points" to item.box.points.map { point ->
                    mapOf(
                        "x" to point.x.toDouble(),
                        "y" to point.y.toDouble(),
                    )
                },
            )
        }

        val text = lines
            .mapNotNull { it["text"] as? String }
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .joinToString("\n")

        val averageConfidence =
            if (result.results.isEmpty()) {
                0.0
            } else {
                result.results.map { it.confidence.toDouble() }.average()
            }

        return mapOf(
            "text" to text,
            "lines" to lines,
            "confidence" to averageConfidence,
            "lineCount" to result.lineCount,
            "detectionTimeMs" to result.detectionTimeMs,
            "recognitionTimeMs" to result.recognitionTimeMs,
            "totalTimeMs" to result.totalTimeMs,
            "coldLoadTimeMs" to result.coldLoadTimeMs,
        )
    }

    fun release() {
        val current = paddle
        paddle = null

        if (current == null) {
            scope.cancel()
            return
        }

        scope.launch(Dispatchers.IO) {
            try {
                current.release()
            } catch (_: Throwable) {
            } finally {
                scope.cancel()
            }
        }
    }
}
