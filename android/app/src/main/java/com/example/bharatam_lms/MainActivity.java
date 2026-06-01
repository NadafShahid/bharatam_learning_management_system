package com.example.bharatam_lms;

import android.os.Bundle;
import android.view.WindowManager;
import android.widget.Toast;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CONTENT_PROTECTION_CHANNEL = "bharatam_lms/content_protection";
    private static final String RESTRICTION_MESSAGE =
            "Screenshot and screen recording are restricted due to copyright.";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CONTENT_PROTECTION_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if ("setProtectedContent".equals(call.method)) {
                Boolean enabled = call.argument("enabled");
                setProtectedContent(Boolean.TRUE.equals(enabled));
                result.success(null);
            } else if ("showRestrictionToast".equals(call.method)) {
                showRestrictionToast();
                result.success(null);
            } else {
                result.notImplemented();
            }
        });
    }

    private void setProtectedContent(boolean enabled) {
        if (enabled) {
            getWindow().setFlags(
                    WindowManager.LayoutParams.FLAG_SECURE,
                    WindowManager.LayoutParams.FLAG_SECURE
            );
            showRestrictionToast();
        } else {
            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
        }
    }

    private void showRestrictionToast() {
        Toast.makeText(this, RESTRICTION_MESSAGE, Toast.LENGTH_LONG).show();
    }
}
