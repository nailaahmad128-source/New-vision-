package com.hameed.pdfmastertools

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import io.flutter.plugins.googlemobileads.NativeAdFactory

class ScanFlowNativeAdFactory(private val context: Context) :
    NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_grid, null) as NativeAdView

        adView.headlineView = adView.findViewById(R.id.ad_headline)
        adView.bodyView = adView.findViewById(R.id.ad_body)
        adView.iconView = adView.findViewById(R.id.ad_icon)
        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)

        (adView.headlineView as TextView).text = nativeAd.headline

        if (nativeAd.body != null) {
            (adView.bodyView as TextView).text = nativeAd.body
            adView.bodyView?.visibility = View.VISIBLE
        } else {
            adView.bodyView?.visibility = View.GONE
        }

        if (nativeAd.icon != null) {
            (adView.iconView as ImageView).setImageDrawable(nativeAd.icon?.drawable)
            adView.iconView?.visibility = View.VISIBLE
        } else {
            adView.iconView?.visibility = View.GONE
        }

        if (nativeAd.callToAction != null) {
            (adView.callToActionView as Button).text = nativeAd.callToAction
            adView.callToActionView?.visibility = View.VISIBLE
        } else {
            adView.callToActionView?.visibility = View.GONE
        }

        adView.setNativeAd(nativeAd)
        return adView
    }
}
