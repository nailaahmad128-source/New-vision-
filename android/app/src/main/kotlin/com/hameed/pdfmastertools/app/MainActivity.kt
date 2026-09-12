package com.hameed.pdfmastertools

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.graphics.Matrix
import java.io.File
import java.io.FileOutputStream
import androidx.exifinterface.media.ExifInterface
import kotlin.math.hypot
import org.opencv.android.OpenCVLoader
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                when (call.method) {
                    "detectDocumentBytes" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_BYTES", "JPEG frame is missing", null)
                            return@setMethodCallHandler
                        }
                        if (!OpenCVLoader.initLocal()) {
                            result.error("OPENCV_INIT", "OpenCV could not be initialized", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                                ?: throw IllegalArgumentException("Unable to decode camera frame")
                            val mat = Mat()
                            org.opencv.android.Utils.bitmapToMat(bitmap, mat)
                            val quad = detectBestDocument(mat)
                            val points = quad?.toArray()?.map {
                                mapOf("x" to (it.x / mat.width()), "y" to (it.y / mat.height()))
                            }
                            result.success(points)
                            bitmap.recycle()
                            mat.release()
                        } catch (e: Exception) {
                            result.error("DETECT_FRAME_FAILED", e.message, null)
                        }
                    }
                    "detectDocument" -> {
                        val path = call.argument<String>("path")
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
                            val quad = detectBestDocument(mat)
                            val points = quad?.toArray()?.map {
                                mapOf("x" to (it.x / mat.width()), "y" to (it.y / mat.height()))
                            }
                            result.success(points)
                            bitmap.recycle()
                            mat.release()
                        } catch (e: Exception) {
                            result.error("DETECT_FAILED", e.message, null)
                        }
                    }
                    "perspectiveCrop" -> {
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
                            val bitmap = decodeOrientedBitmap(path)
                                ?: throw IllegalArgumentException("Unable to decode image")
                            val src = Mat()
                            org.opencv.android.Utils.bitmapToMat(bitmap, src)
                            val w = src.width().toDouble()
                            val h = src.height().toDouble()
                            val pts = rawPoints.map {
                                Point(
                                    (it["x"] as Number).toDouble() * w,
                                    (it["y"] as Number).toDouble() * h,
                                )
                            }
                            val ordered = orderCorners(pts)
                            val topW = distance(ordered[0], ordered[1])
                            val bottomW = distance(ordered[3], ordered[2])
                            val leftH = distance(ordered[0], ordered[3])
                            val rightH = distance(ordered[1], ordered[2])
                            val rawW = maxOf(600, maxOf(topW, bottomW).toInt())
                            val rawH = maxOf(800, maxOf(leftH, rightH).toInt())
                            val outputScale = minOf(1.0, 3600.0 / maxOf(rawW, rawH).toDouble())
                            val outW = maxOf(600, (rawW * outputScale).toInt())
                            val outH = maxOf(800, (rawH * outputScale).toInt())
                            val srcPts = MatOfPoint2f(*ordered.toTypedArray())
                            val dstPts = MatOfPoint2f(
                                Point(0.0, 0.0), Point((outW - 1).toDouble(), 0.0),
                                Point((outW - 1).toDouble(), (outH - 1).toDouble()), Point(0.0, (outH - 1).toDouble())
                            )
                            val transform = Imgproc.getPerspectiveTransform(srcPts, dstPts)
                            val warped = Mat()
                            Imgproc.warpPerspective(src, warped, transform, Size(outW.toDouble(), outH.toDouble()), Imgproc.INTER_LANCZOS4)
                            val outFile = File(cacheDir, "scan_${System.currentTimeMillis()}.jpg")
                            val bitmapOut = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
                            org.opencv.android.Utils.matToBitmap(warped, bitmapOut)
                            FileOutputStream(outFile).use { bitmapOut.compress(Bitmap.CompressFormat.JPEG, 96, it) }
                            result.success(outFile.absolutePath)
                            bitmap.recycle()
                            bitmapOut.recycle()
                            src.release(); srcPts.release(); dstPts.release(); transform.release(); warped.release()
                        } catch (e: Exception) {
                            result.error("CROP_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun decodeOrientedBitmap(path: String): Bitmap? {
        val bitmap = BitmapFactory.decodeFile(path) ?: return null
        return try {
            val exif = ExifInterface(path)
            val orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            val matrix = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.preScale(1f, -1f)
                ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.setRotate(90f); matrix.preScale(-1f, 1f) }
                ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.setRotate(270f); matrix.preScale(-1f, 1f) }
                else -> return bitmap
            }
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true).also {
                if (it !== bitmap) bitmap.recycle()
            }
        } catch (_: Exception) {
            bitmap
        }
    }

    private fun detectBestDocument(input: Mat): MatOfPoint2f? {
        val maxSide = maxOf(input.width(), input.height())
        val scale = if (maxSide > 1800) 1800.0 / maxSide else 1.0
        val working = Mat()
        if (scale < 1.0) {
            Imgproc.resize(input, working, Size(input.width() * scale, input.height() * scale), 0.0, 0.0, Imgproc.INTER_AREA)
        } else {
            input.copyTo(working)
        }

        val gray = Mat()
        Imgproc.cvtColor(working, gray, Imgproc.COLOR_RGBA2GRAY)
        Imgproc.GaussianBlur(gray, gray, Size(5.0, 5.0), 0.0)

        val maps = mutableListOf<Mat>()
        val edges = Mat()
        Imgproc.Canny(gray, edges, 45.0, 140.0)
        val closeKernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(5.0, 5.0))
        Imgproc.morphologyEx(edges, edges, Imgproc.MORPH_CLOSE, closeKernel)
        closeKernel.release()
        maps.add(edges)

        val adaptive = Mat()
        Imgproc.adaptiveThreshold(
            gray, adaptive, 255.0,
            Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C,
            Imgproc.THRESH_BINARY_INV, 41, 9.0
        )
        val thresholdKernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(7.0, 7.0))
        Imgproc.morphologyEx(adaptive, adaptive, Imgproc.MORPH_CLOSE, thresholdKernel)
        thresholdKernel.release()
        maps.add(adaptive)

        val imageArea = working.width().toDouble() * working.height().toDouble()
        val minArea = imageArea * 0.045
        val maxArea = imageArea * 0.985
        var best: MatOfPoint2f? = null
        var bestScore = 0.0

        for (map in maps) {
            val contours = ArrayList<MatOfPoint>()
            Imgproc.findContours(
                map, contours, Mat(),
                Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE
            )
            for (contour in contours) {
                val area = Imgproc.contourArea(contour)
                if (area < minArea || area > maxArea) {
                    contour.release()
                    continue
                }

                val c2f = MatOfPoint2f(*contour.toArray())
                val peri = Imgproc.arcLength(c2f, true)
                val approx = MatOfPoint2f()
                Imgproc.approxPolyDP(c2f, approx, 0.018 * peri, true)

                if (approx.total() == 4L) {
                    val ordered = orderCorners(approx.toArray())
                    val convex = Imgproc.isContourConvex(MatOfPoint(*ordered.toTypedArray()))
                    if (convex) {
                        val topW = distance(ordered[0], ordered[1])
                        val bottomW = distance(ordered[3], ordered[2])
                        val leftH = distance(ordered[0], ordered[3])
                        val rightH = distance(ordered[1], ordered[2])
                        val avgW = (topW + bottomW) / 2.0
                        val avgH = (leftH + rightH) / 2.0
                        val aspect = if (avgW > avgH) avgW / avgH else avgH / avgW
                        val aspectScore = if (aspect in 1.15..2.4) 1.0 else
                            (1.0 - kotlin.math.abs(aspect - 1.7) / 2.0).coerceIn(0.0, 1.0)

                        val rectangularity = (area / imageArea).coerceIn(0.0, 1.0)
                        val angleScore = rightAngleScore(ordered)
                        val center = Point(working.width() / 2.0, working.height() / 2.0)
                        val quadCenter = Point(
                            ordered.map { it.x }.average(),
                            ordered.map { it.y }.average()
                        )
                        val centerScore = 1.0 - (
                            distance(center, quadCenter) /
                                hypot(working.width().toDouble(), working.height().toDouble())
                            ).coerceIn(0.0, 1.0)

                        // Favor large, rectangular, near-center documents while still
                        // accepting receipts/cards with non-A4 aspect ratios.
                        val score =
                            rectangularity * 0.52 +
                            angleScore * 0.28 +
                            aspectScore * 0.12 +
                            centerScore * 0.08

                        if (score > bestScore) {
                            best?.release()
                            val scaled = if (scale < 1.0) {
                                ordered.map { Point(it.x / scale, it.y / scale) }
                            } else {
                                ordered
                            }
                            best = MatOfPoint2f(*scaled.toTypedArray())
                            bestScore = score
                        }
                    }
                }
                c2f.release()
                approx.release()
                contour.release()
            }
            map.release()
        }

        gray.release()
        working.release()
        return best
    }

    private fun rightAngleScore(points: List<Point>): Double {
        if (points.size != 4) return 0.0
        var total = 0.0
        for (i in 0 until 4) {
            val a = points[(i + 3) % 4]
            val b = points[i]
            val c = points[(i + 1) % 4]
            val ab = Point(a.x - b.x, a.y - b.y)
            val cb = Point(c.x - b.x, c.y - b.y)
            val denom = hypot(ab.x, ab.y) * hypot(cb.x, cb.y)
            val cos = if (denom == 0.0) 1.0 else kotlin.math.abs((ab.x * cb.x + ab.y * cb.y) / denom)
            total += 1.0 - cos.coerceIn(0.0, 1.0)
        }
        return total / 4.0
    }

    private fun distance(a: Point, b: Point): Double = hypot(a.x - b.x, a.y - b.y)

    private fun orderCorners(points: List<Point>): List<Point> {
        val tl = points.minByOrNull { it.x + it.y }!!
        val br = points.maxByOrNull { it.x + it.y }!!
        val tr = points.maxByOrNull { it.x - it.y }!!
        val bl = points.minByOrNull { it.x - it.y }!!
        return listOf(tl, tr, br, bl)
    }
}
