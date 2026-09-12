package com.hameed.pdfmastertools

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import java.io.File
import java.io.FileOutputStream
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
                if (call.method == "detectDocument") {
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
                        val bitmap = BitmapFactory.decodeFile(path)
                            ?: throw IllegalArgumentException("Unable to decode image")
                        val mat = Mat()
                        org.opencv.android.Utils.bitmapToMat(bitmap, mat)
                        val gray = Mat()
                        Imgproc.cvtColor(mat, gray, Imgproc.COLOR_RGBA2GRAY)
                        Imgproc.GaussianBlur(gray, gray, Size(5.0, 5.0), 0.0)
                        val edges = Mat()
                        Imgproc.Canny(gray, edges, 60.0, 180.0)
                        val contours = ArrayList<MatOfPoint>()
                        Imgproc.findContours(edges, contours, Mat(), Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE)

                        val imageArea = mat.width().toDouble() * mat.height().toDouble()
                        var best: MatOfPoint2f? = null
                        var bestArea = 0.0
                        for (contour in contours) {
                            val area = Imgproc.contourArea(contour)
                            if (area < imageArea * 0.15 || area <= bestArea) continue
                            val c2f = MatOfPoint2f(*contour.toArray())
                            val peri = Imgproc.arcLength(c2f, true)
                            val approx = MatOfPoint2f()
                            Imgproc.approxPolyDP(c2f, approx, 0.02 * peri, true)
                            if (approx.total() == 4L) {
                                best = approx
                                bestArea = area
                            }
                            c2f.release()
                        }

                        val points = best?.toArray()?.map {
                            mapOf("x" to (it.x / mat.width()), "y" to (it.y / mat.height()))
                        }
                        result.success(points)
                        best?.release()
                        contours.forEach { it.release() }
                        gray.release(); edges.release(); mat.release()
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
                        val bitmap = BitmapFactory.decodeFile(path) ?: throw IllegalArgumentException("Unable to decode image")
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

    private fun orderCorners(points: List<Point>): List<Point> {
        val tl = points.minByOrNull { it.x + it.y }!!
        val br = points.maxByOrNull { it.x + it.y }!!
        val tr = points.maxByOrNull { it.x - it.y }!!
        val bl = points.minByOrNull { it.x - it.y }!!
        return listOf(tl, tr, br, bl)
    }
}
