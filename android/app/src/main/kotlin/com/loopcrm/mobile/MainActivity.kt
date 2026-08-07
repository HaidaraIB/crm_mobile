package com.loopcrm.mobile

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Play Console: enable edge-to-edge on pre-Android 15 as well.
        // FlutterFragmentActivity is required (extends ComponentActivity).
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
