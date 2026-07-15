package com.example.marine_survey_app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity — local_auth (biometric
// app-lock, 14 July 2026 walkthrough ask) requires the host Activity to be
// a FragmentActivity on Android to show the system biometric prompt.
class MainActivity : FlutterFragmentActivity()
