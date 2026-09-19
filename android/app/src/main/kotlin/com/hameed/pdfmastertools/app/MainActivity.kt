package com.hameed.pdfmastertools

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.exifinterface.media.ExifInterface
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import java.io.File
import java.io.ByteArrayOutputStream
import java.io.FileOutputStream
import kotlin.math.hypot
import org.opencv.android.OpenCVLoader
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Result of a single detection pass: the best document quadrilateral found
 * (already ordered tl/tr/br/bl, in the coordinate space of the Mat that was
 * passed in), plus a Laplacian-variance sharpness score for that frame so
 * the Flutter side can refuse to auto-capture a blurry frame (requirement:
 * do not capture when a better/sharper frame can be obtained).
 */
data class DetectionResult(
    val corners: List<Point>?,
    val sharpness: Double
)

class MainActivity : FlutterActivity() {
    // Native channel used only to open this app's system settings screen
    // (Settings.ACTION_APPLICATION_DETAILS_SETTINGS). This requires no
    // Android permission of any kind, so it lets qr_scan_screen.dart send
    // a user to Settings after camera permission is permanently denied
    // without depending on permission_handler.
    private val settingsChannel = "com.hameed.pdfmastertools/app_settings"
    private val scannerChannel = "com.hameed.pdfmastertools/scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, settingsChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "openAppSettings") {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.fromParts("package", packageName, null)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, scannerChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "detectDocumentFrame") {
                    val bytes = call.argument<ByteArray>("bytes")
                    val width = call.argument<Int>("width")
                    val height = call.argument<Int>("height")
                    val rotation = call.argument<Int>("rotation") ?: 0
                    val mode = call.argument<String>("mode") ?: "document"

                    if (bytes == null || width == null || height == null) {
                        result.error("INVALID_FRAME", "Frame data is missing", null)
                        return@setMethodCallHandler
                    }

                    if (!OpenCVLoader.initLocal()) {
                        result.error(
                            "OPENCV_INIT",
                            "OpenCV could not be initialized",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        // Android YUV420:
                        // Read the Y/luma plane while respecting row/pixel stride.
                        val rowStride = call.argument<Int>("rowStride") ?: width
                        val pixelStride = call.argument<Int>("pixelStride") ?: 1

                        if (rowStride <= 0 || pixelStride <= 0 || bytes.isEmpty()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }

                        val yBytes = ByteArray(width * height)

                        for (y in 0 until height) {
                            val srcRow = y * rowStride
                            val dstRow = y * width

                            for (x in 0 until width) {
                                val srcIndex = srcRow + x * pixelStride

                                if (srcIndex >= 0 && srcIndex < bytes.size) {
                                    yBytes[dstRow + x] = bytes[srcIndex]
                                }
                            }
                        }

                        var mat = Mat(
                            height,
                            width,
                            org.opencv.core.CvType.CV_8UC1
                        )

                        mat.put(0, 0, yBytes)

                        val normalizedRotation =
                            ((rotation % 360) + 360) % 360

                        if (normalizedRotation != 0) {
                            val rotated = Mat()

                            when (normalizedRotation) {
                                90 -> org.opencv.core.Core.rotate(
                                    mat,
                                    rotated,
                                    org.opencv.core.Core.ROTATE_90_CLOCKWISE
                                )

                                180 -> org.opencv.core.Core.rotate(
                                    mat,
                                    rotated,
                                    org.opencv.core.Core.ROTATE_180
                                )

                                270 -> org.opencv.core.Core.rotate(
                                    mat,
                                    rotated,
                                    org.opencv.core.Core.ROTATE_90_COUNTERCLOCKWISE
                                )

                                else -> mat.copyTo(rotated)
                            }

                            mat.release()
                            mat = rotated
                        }

                        val detection = findBestDocument(mat, mode)

                        val detected = detection.corners?.takeIf {
                            isUsableDocumentQuad(
                                it,
                                mat.width().toDouble(),
                                mat.height().toDouble(),
                                mode
                            )
                        }

                        result.success(
                            mapOf(
                                "corners" to detected?.map {
                                    mapOf(
                                        "x" to (it.x / mat.width()),
                                        "y" to (it.y / mat.height())
                                    )
                                },
                                "sharpness" to detection.sharpness
                            )
                        )

                        mat.release()
                    } catch (_: Exception) {
                        result.success(null)
                    }
                } else if (call.method == "detectDocument") {
                    val path = call.argument<String>("path")
                    val mode = call.argument<String>("mode") ?: "document"
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "Image path is missing", null)
                        return@setMethodCallHandler
                    }
                    if (!OpenCVLoader.initLocal()) {
                        result.error("OPENCV_INIT", "OpenCV could not be initialized", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val bitmap = decodeOrientedBitmap(path)
                            ?: throw IllegalArgumentException("Unable to decode image")

                        val mat = Mat()
                        org.opencv.android.Utils.bitmapToMat(bitmap, mat)

                        val best = findBestDocument(mat, mode).corners?.takeIf {
                            isUsableDocumentQuad(
                                it,
                                mat.width().toDouble(),
                                mat.height().toDouble(),
                                mode
                            )
                        }

                        val points = best?.map {
                            mapOf(
                                "x" to (it.x / mat.width()),
                                "y" to (it.y / mat.height())
                            )
                        }

                        result.success(points)

                        best?.let { MatOfPoint2f(*it.toTypedArray()).release() }
                        mat.release()
                        bitmap.recycle()
                    } catch (e: Exception) {
                        result.error("DETECT_FAILED", e.message, null)
                    }
                } else if (call.method == "perspectiveCrop") {
                    val path = call.argument<String>("path")
                    val rawPoints = call.argument<List<Map<String, Any>>>("points")
                    if (path.isNullOrBlank() || rawPoints == null || rawPoints.size != 4) {
                        result.error("INVALID_INPUT", "Image path and four document corners are required", null)
                        return@setMethodCallHandler
                    }
                    if (!OpenCVLoader.initLocal()) {
                        result.error("OPENCV_INIT", "OpenCV could not be initialized", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val bitmap = decodeOrientedBitmap(path) ?: throw IllegalArgumentException("Unable to decode image")
                        val src = Mat()
                        org.opencv.android.Utils.bitmapToMat(bitmap, src)
                        val w = src.width().toDouble()
                        val h = src.height().toDouble()
                        val pts = rawPoints.map { Point((it["x"] as Number).toDouble() * w, (it["y"] as Number).toDouble() * h) }
                        val ordered = orderCorners(pts)
                        val topW = hypot(ordered[1].x - ordered[0].x, ordered[1].y - ordered[0].y)
                        val bottomW = hypot(ordered[2].x - ordered[3].x, ordered[2].y - ordered[3].y)
                        val leftH = hypot(ordered[3].x - ordered[0].x, ordered[3].y - ordered[0].y)
                        val rightH = hypot(ordered[2].x - ordered[1].x, ordered[2].y - ordered[1].y)
                        val outW = maxOf(400, maxOf(topW, bottomW).toInt())
                        val outH = maxOf(400, maxOf(leftH, rightH).toInt())
                        val srcPts = MatOfPoint2f(*ordered.toTypedArray())
                        val dstPts = MatOfPoint2f(
                            Point(0.0, 0.0), Point((outW - 1).toDouble(), 0.0),
                            Point((outW - 1).toDouble(), (outH - 1).toDouble()), Point(0.0, (outH - 1).toDouble())
                        )
                        val transform = Imgproc.getPerspectiveTransform(srcPts, dstPts)
                        val warped = Mat()
                        Imgproc.warpPerspective(src, warped, transform, Size(outW.toDouble(), outH.toDouble()))
                        val outFile = File(cacheDir, "scan_${System.currentTimeMillis()}.jpg")
                        val bitmapOut = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
                        org.opencv.android.Utils.matToBitmap(warped, bitmapOut)
                        FileOutputStream(outFile).use { bitmapOut.compress(Bitmap.CompressFormat.JPEG, 95, it) }
                        result.success(outFile.absolutePath)
                        bitmap.recycle(); bitmapOut.recycle()
                        src.release(); srcPts.release(); dstPts.release(); transform.release(); warped.release()
                    } catch (e: Exception) {
                        result.error("CROP_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun decodeOrientedBitmap(path: String): Bitmap? {
        val raw = BitmapFactory.decodeFile(path) ?: return null

        return try {
            val exif = ExifInterface(path)

            val orientation = exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )

            val matrix = Matrix()

            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 ->
                    matrix.postRotate(90f)

                ExifInterface.ORIENTATION_ROTATE_180 ->
                    matrix.postRotate(180f)

                ExifInterface.ORIENTATION_ROTATE_270 ->
                    matrix.postRotate(270f)

                ExifInterface.ORIENTATION_FLIP_HORIZONTAL ->
                    matrix.setScale(-1f, 1f)

                ExifInterface.ORIENTATION_FLIP_VERTICAL ->
                    matrix.setScale(1f, -1f)

                ExifInterface.ORIENTATION_TRANSPOSE -> {
                    matrix.setRotate(90f)
                    matrix.postScale(-1f, 1f)
                }

                ExifInterface.ORIENTATION_TRANSVERSE -> {
                    matrix.setRotate(270f)
                    matrix.postScale(-1f, 1f)
                }

                else -> return raw
            }

            val oriented = Bitmap.createBitmap(
                raw,
                0,
                0,
                raw.width,
                raw.height,
                matrix,
                true
            )

            if (oriented !== raw) {
                raw.recycle()
            }

            oriented
        } catch (_: Exception) {
            raw
        }
    }

    /**
     * Mode-tuned detection constants. ID cards are physically small (an
     * ISO/IEC 7810 ID-1 card is far smaller than an A4 page) and have a
     * predictable aspect ratio, so we admit smaller candidates and reward
     * closeness to that aspect ratio. Books fill more of the frame and the
     * spine/crease breaks strict left/right symmetry, so rectangularity is
     * weighted less harshly there. Document mode keeps the original,
     * already-tuned general-purpose behavior.
     */
    private data class ModeTuning(
        val minAreaRatio: Double,
        val rectangularityWeight: Double,
        val idCardAspectBonus: Boolean,
        val usableMinAreaRatio: Double,
        val usableMinSideFraction: Double
    )

    private fun tuningFor(mode: String): ModeTuning = when (mode) {
        "idCard" -> ModeTuning(
            minAreaRatio = 0.007,
            rectangularityWeight = 1.15,
            idCardAspectBonus = true,
            usableMinAreaRatio = 0.012,
            usableMinSideFraction = 0.05
        )
        "book" -> ModeTuning(
            minAreaRatio = 0.05,
            rectangularityWeight = 0.55,
            idCardAspectBonus = false,
            usableMinAreaRatio = 0.06,
            usableMinSideFraction = 0.10
        )
        else -> ModeTuning(
            minAreaRatio = 0.018,
            rectangularityWeight = 1.0,
            idCardAspectBonus = false,
            usableMinAreaRatio = 0.025,
            usableMinSideFraction = 0.08
        )
    }

    private fun findBestDocument(
        input: Mat,
        mode: String = "document"
    ): DetectionResult {
        if (input.empty() || input.width() < 20 || input.height() < 20) {
            return DetectionResult(null, 0.0)
        }

        val tuning = tuningFor(mode)

        // Work on a smaller image for fast live detection.
        // The final crop still uses the original high-resolution photo.
        val working = Mat()

        val targetWidth = 960.0
        val scale = minOf(
            1.0,
            targetWidth / input.width().toDouble()
        )

        val targetHeight =
            (input.height() * scale).toInt().coerceAtLeast(1)

        Imgproc.resize(
            input,
            working,
            Size(
                (input.width() * scale),
                targetHeight.toDouble()
            ),
            0.0,
            0.0,
            Imgproc.INTER_AREA
        )
        val gray = Mat()

        if (working.channels() == 1) {
            working.copyTo(gray)
        } else {
            Imgproc.cvtColor(
                working,
                gray,
                Imgproc.COLOR_RGBA2GRAY
            )
        }

        // Sharpness must be measured before we blur the working frame for
        // edge detection, otherwise every frame would look equally blurry.
        val sharpness = run {
            val lap = Mat()
            Imgproc.Laplacian(gray, lap, CvType.CV_64F)
            val mean = MatOfDouble()
            val stddev = MatOfDouble()
            Core.meanStdDev(lap, mean, stddev)
            val sd = stddev.toArray().getOrElse(0) { 0.0 }
            lap.release()
            mean.release()
            stddev.release()
            sd * sd
        }

        Imgproc.GaussianBlur(
            gray,
            gray,
            Size(5.0, 5.0),
            0.0
        )

        val imageArea =
            working.width().toDouble() *
            working.height().toDouble()

        var best: List<Point>? = null
        var bestScore = Double.NEGATIVE_INFINITY

        fun evaluateEdges(edges: Mat) {
            val contours = ArrayList<MatOfPoint>()

            Imgproc.findContours(
                edges,
                contours,
                Mat(),
                Imgproc.RETR_LIST,
                Imgproc.CHAIN_APPROX_SIMPLE
            )

            for (contour in contours) {
                try {
                    val area = Imgproc.contourArea(contour)

                    // Keep smaller documents too, especially cards/receipts.
                    if (area < imageArea * tuning.minAreaRatio) {
                        continue
                    }

                    val contour2f =
                        MatOfPoint2f(*contour.toArray())

                    val perimeter =
                        Imgproc.arcLength(contour2f, true)

                    if (perimeter <= 0.0) {
                        contour2f.release()
                        continue
                    }

                    val approx = MatOfPoint2f()

                    Imgproc.approxPolyDP(
                        contour2f,
                        approx,
                        0.018 * perimeter,
                        true
                    )

                    if (approx.total() == 4L) {
                        val points =
                            approx.toArray().toList()

                        if (isConvexQuad(points)) {
                            val ratio = area / imageArea

                            val rectangularity =
                                rectangularityScore(points)

                            val edgeBonus = when {
                                ratio >= 0.18 -> 18.0
                                ratio >= 0.10 -> 10.0
                                ratio >= 0.05 -> 5.0
                                else -> 0.0
                            }

                            // Penalize extremely thin or strange quads.
                            val ordered = orderCorners(points)
                            val top =
                                distance(ordered[0], ordered[1])
                            val right =
                                distance(ordered[1], ordered[2])
                            val bottom =
                                distance(ordered[2], ordered[3])
                            val left =
                                distance(ordered[3], ordered[0])

                            val widthAverage =
                                (top + bottom) / 2.0
                            val heightAverage =
                                (right + left) / 2.0

                            if (widthAverage <= 1.0 ||
                                heightAverage <= 1.0) {
                                approx.release()
                                contour2f.release()
                                continue
                            }

                            val aspect =
                                maxOf(
                                    widthAverage,
                                    heightAverage
                                ) / minOf(
                                    widthAverage,
                                    heightAverage
                                )

                            if (aspect > 12.0) {
                                approx.release()
                                contour2f.release()
                                continue
                            }

                            val centerX =
                                points.sumOf { it.x } / 4.0
                            val centerY =
                                points.sumOf { it.y } / 4.0

                            // Prefer candidates reasonably close to the
                            // camera center. This reduces random table edges.
                            val centerDistance =
                                kotlin.math.sqrt(
                                    ((centerX / working.width()) - 0.5) *
                                    ((centerX / working.width()) - 0.5) +
                                    ((centerY / working.height()) - 0.5) *
                                    ((centerY / working.height()) - 0.5)
                                )

                            val centerBonus =
                                maxOf(
                                    0.0,
                                    8.0 - centerDistance * 16.0
                                )

                            // ID-1 cards have a fixed ~1.586 aspect ratio
                            // (either orientation). Reward candidates that
                            // match it so a nearby card wins over other
                            // rectangular clutter in the frame.
                            val idAspectBonus =
                                if (tuning.idCardAspectBonus) {
                                    maxOf(
                                        0.0,
                                        6.0 - kotlin.math.abs(aspect - 1.586) * 5.0
                                    )
                                } else {
                                    0.0
                                }

                            val score =
                                ratio * 100.0 +
                                rectangularity * tuning.rectangularityWeight +
                                edgeBonus +
                                centerBonus +
                                idAspectBonus

                            if (score > bestScore) {
                                bestScore = score
                                best = ordered
                            }
                        }
                    }

                    approx.release()
                    contour2f.release()
                } finally {
                    contour.release()
                }
            }
        }

        // Pass 1: normal Canny edges.
        val edges = Mat()

        Imgproc.Canny(
            gray,
            edges,
            45.0,
            150.0
        )

        val closeKernel =
            Imgproc.getStructuringElement(
                Imgproc.MORPH_RECT,
                Size(5.0, 5.0)
            )

        Imgproc.morphologyEx(
            edges,
            edges,
            Imgproc.MORPH_CLOSE,
            closeKernel
        )

        evaluateEdges(edges)

        // Pass 2: adaptive threshold helps with uneven lighting,
        // shadows and darker paper.
        val threshold = Mat()

        Imgproc.adaptiveThreshold(
            gray,
            threshold,
            255.0,
            Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C,
            Imgproc.THRESH_BINARY,
            31,
            11.0
        )

        val thresholdEdges = Mat()

        Imgproc.morphologyEx(
            threshold,
            thresholdEdges,
            Imgproc.MORPH_GRADIENT,
            closeKernel
        )

        evaluateEdges(thresholdEdges)

        // Pass 3: inverted threshold helps dark documents/cards.
        val inverted = Mat()

        Imgproc.adaptiveThreshold(
            gray,
            inverted,
            255.0,
            Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C,
            Imgproc.THRESH_BINARY_INV,
            31,
            9.0
        )

        val invertedEdges = Mat()

        Imgproc.morphologyEx(
            inverted,
            invertedEdges,
            Imgproc.MORPH_GRADIENT,
            closeKernel
        )

        evaluateEdges(invertedEdges)

        val scaleX =
            input.width().toDouble() / working.width().toDouble()

        val scaleY =
            input.height().toDouble() / working.height().toDouble()

        val result = best?.map {
            Point(
                it.x * scaleX,
                it.y * scaleY
            )
        }?.let {
            orderCorners(it)
        }

        invertedEdges.release()
        inverted.release()
        thresholdEdges.release()
        threshold.release()
        closeKernel.release()
        edges.release()
        gray.release()
        working.release()

        return DetectionResult(result, sharpness)
    }

    private fun isUsableDocumentQuad(
        points: List<Point>,
        width: Double,
        height: Double,
        mode: String = "document"
    ): Boolean {
        if (points.size != 4 || width <= 0.0 || height <= 0.0) return false

        val tuning = tuningFor(mode)

        val ordered = orderCorners(points)

        val top = distance(ordered[0], ordered[1])
        val right = distance(ordered[1], ordered[2])
        val bottom = distance(ordered[2], ordered[3])
        val left = distance(ordered[3], ordered[0])

        val minSide = minOf(top, right, bottom, left)
        val maxSide = maxOf(top, right, bottom, left)

        if (minSide < minOf(width, height) * tuning.usableMinSideFraction) return false
        if (maxSide / minSide > 8.5) return false

        val area = kotlin.math.abs(
            ordered[0].x * ordered[1].y - ordered[1].x * ordered[0].y +
            ordered[1].x * ordered[2].y - ordered[2].x * ordered[1].y +
            ordered[2].x * ordered[3].y - ordered[3].x * ordered[2].y +
            ordered[3].x * ordered[0].y - ordered[0].x * ordered[3].y
        ) / 2.0

        if (area / (width * height) < tuning.usableMinAreaRatio) return false

        return isConvexQuad(ordered)
    }

    private fun distance(a: Point, b: Point): Double {
        val dx = a.x - b.x
        val dy = a.y - b.y
        return kotlin.math.sqrt(dx * dx + dy * dy)
    }

    private fun isConvexQuad(points: List<Point>): Boolean {
        if (points.size != 4) return false

        var sign = 0

        for (i in 0 until 4) {
            val a = points[i]
            val b = points[(i + 1) % 4]
            val c = points[(i + 2) % 4]

            val cross =
                (b.x - a.x) * (c.y - b.y) -
                (b.y - a.y) * (c.x - b.x)

            if (kotlin.math.abs(cross) < 1.0) return false

            val current = if (cross > 0) 1 else -1

            if (sign == 0) {
                sign = current
            } else if (sign != current) {
                return false
            }
        }

        return true
    }

    private fun rectangularityScore(points: List<Point>): Double {
        if (points.size != 4) return 0.0

        val ordered = orderCorners(points)

        val top = hypot(
            ordered[1].x - ordered[0].x,
            ordered[1].y - ordered[0].y
        )

        val bottom = hypot(
            ordered[2].x - ordered[3].x,
            ordered[2].y - ordered[3].y
        )

        val left = hypot(
            ordered[3].x - ordered[0].x,
            ordered[3].y - ordered[0].y
        )

        val right = hypot(
            ordered[2].x - ordered[1].x,
            ordered[2].y - ordered[1].y
        )

        val widthBalance =
            1.0 - kotlin.math.abs(top - bottom) /
                maxOf(top, bottom, 1.0)

        val heightBalance =
            1.0 - kotlin.math.abs(left - right) /
                maxOf(left, right, 1.0)

        return (widthBalance + heightBalance) * 5.0
    }

    private fun orderCorners(points: List<Point>): List<Point> {
        val tl = points.minByOrNull { it.x + it.y }!!
        val br = points.maxByOrNull { it.x + it.y }!!
        val tr = points.maxByOrNull { it.x - it.y }!!
        val bl = points.minByOrNull { it.x - it.y }!!
        return listOf(tl, tr, br, bl)
    }
}
