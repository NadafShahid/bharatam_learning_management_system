package com.example.bharatam_lms.Activities;


import android.app.ProgressDialog;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import android.os.CountDownTimer;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;
import com.google.android.gms.auth.api.phone.SmsRetriever;
import com.google.android.gms.auth.api.phone.SmsRetrieverClient;
import com.google.android.gms.tasks.Task;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.example.bharatam_lms.R;

import java.util.Locale;

public class PhoneAuth extends AppCompatActivity {
    private EditText etMobile, etOtp;
    private Button btnSendOtp, btnVerifyOtp;
    private TextView tvResendOtp, tvTimer;
    private View otpContainer;
    private String serverOtp = "";
    private RequestQueue requestQueue;
    private CountDownTimer countDownTimer;

    // SMS API credentials
    private final String username = "Experts";
    private final String authkey = "ba9dcdcdfcXX";
    private final String senderId = "EXTSKL";
    private final String accusage = "1";
    private final String TAG = "PhoneAuth";
    private final String TRAINER_BYPASS = "9898989898";
    private final String STUDENT_BYPASS = "9999999999";
    private final String BYPASS_OTP = "123456";
    private ProgressDialog progressDialog;
    private boolean isExistingUser = false;
    private boolean isOtpSent = false;
    private boolean isOtpVerified = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_phone_auth);
        initializeViews();
        setupTextWatchers();
        setupClickListeners();
    }

    private void initializeViews() {
        etMobile = findViewById(R.id.etMobile);
        etOtp = findViewById(R.id.etOtp);
        btnSendOtp = findViewById(R.id.btnSendOtp);
        btnVerifyOtp = findViewById(R.id.btnVerifyOtp);
        tvResendOtp = findViewById(R.id.tvResendOtp);
        tvTimer = findViewById(R.id.tvTimer);
        otpContainer = findViewById(R.id.otpContainer);
        requestQueue = Volley.newRequestQueue(this);

        // Initially hide OTP container
        otpContainer.setVisibility(View.GONE);
        btnVerifyOtp.setVisibility(View.GONE);
        tvResendOtp.setVisibility(View.GONE);
        tvTimer.setVisibility(View.GONE);
    }

    private void setupTextWatchers() {
        etMobile.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {}

            @Override
            public void afterTextChanged(Editable s) {
                // Background check removed to ensure no interference with OTP flow
            }
        });
    }

    private void setupClickListeners() {
        btnSendOtp.setOnClickListener(v -> sendOtp());
        btnVerifyOtp.setOnClickListener(v -> verifyOtp());
        tvResendOtp.setOnClickListener(v -> resendOtp());
    }

    private void sendOtp() {
        String mobile = etMobile.getText().toString().trim();

        // Validate mobile number
        if (mobile.length() != 10) {
            etMobile.setError("Enter valid 10-digit number");
            etMobile.requestFocus();
            return;
        }

        // Bypass logic for testing
        if (mobile.equals(TRAINER_BYPASS) || mobile.equals(STUDENT_BYPASS)) {
            serverOtp = BYPASS_OTP;
            isOtpSent = true;
            Toast.makeText(this, "Bypass Mode Activated", Toast.LENGTH_SHORT).show();
            showOtpFields();
            startCountdownTimer();
            return;
        }

        // Generate 6-digit OTP
        serverOtp = String.valueOf((int) (Math.random() * 900000) + 100000);
        String messageText = "Your Verification Code for login is " + serverOtp + ". - Expertskill Technology.";
        String url = Uri.parse("https://mobicomm.dove-sms.com/submitsms.jsp").buildUpon()
                .appendQueryParameter("user", username)
                .appendQueryParameter("key", authkey)
                .appendQueryParameter("mobile", mobile)
                .appendQueryParameter("message", messageText)
                .appendQueryParameter("accusage", accusage)
                .appendQueryParameter("senderid", senderId)
                .build()
                .toString();

        Log.d(TAG, "FINAL URL: " + url);

        // Show progress dialog for sending OTP
        showProgressDialog("Sending OTP...");

        StringRequest request = new StringRequest(Request.Method.GET, url,
                response -> {
                    hideProgressDialog();
                    Log.d(TAG, "SMS API Response: " + response);
                    
                    String normalizedResponse = response.toLowerCase(Locale.US);
                    if (normalizedResponse.contains("success") ||
                            normalizedResponse.contains("submit_success") ||
                            normalizedResponse.contains("submitted")) {
                        isOtpSent = true;
                        Toast.makeText(this, "OTP sent successfully", Toast.LENGTH_SHORT).show();
                        showOtpFields();
                        startCountdownTimer();
                        startSmsRetriever();
                    } else {
                        isOtpSent = false;
                        Toast.makeText(this, "API Error: " + response, Toast.LENGTH_LONG).show();
                        Log.e(TAG, "SMS API Error Details: " + response);
                    }
                },
                error -> {
                    hideProgressDialog();
                    isOtpSent = false;
                    Log.e(TAG, "Network Error: " + error.getMessage());
                    Toast.makeText(this, "Network Error. Please check internet.", Toast.LENGTH_SHORT).show();
                });

        request.setTag(TAG);
        requestQueue.add(request);
    }

    private void showOtpFields() {
        otpContainer.setVisibility(View.VISIBLE);
        btnVerifyOtp.setVisibility(View.VISIBLE);
        tvTimer.setVisibility(View.VISIBLE);
        btnSendOtp.setEnabled(false);
        btnSendOtp.setAlpha(0.5f);
        btnSendOtp.setText("OTP Sent");

        // Disable mobile editing after OTP is sent
        etMobile.setEnabled(false);
        etMobile.setAlpha(0.7f);
    }

    private void startCountdownTimer() {
        if (countDownTimer != null) {
            countDownTimer.cancel();
        }

        countDownTimer = new CountDownTimer(120000, 1000) {
            @Override
            public void onTick(long millisUntilFinished) {
                long minutes = millisUntilFinished / 60000;
                long seconds = (millisUntilFinished % 60000) / 1000;
                tvTimer.setText(String.format("Resend OTP in %02d:%02d", minutes, seconds));
            }

            @Override
            public void onFinish() {
                tvTimer.setVisibility(View.GONE);
                tvResendOtp.setVisibility(View.VISIBLE);
                tvResendOtp.setText("Resend OTP");
            }
        }.start();
    }

    private void resendOtp() {
        tvResendOtp.setVisibility(View.GONE);

        // Re-enable mobile field for potential changes
        etMobile.setEnabled(true);
        etMobile.setAlpha(1.0f);
        btnSendOtp.setEnabled(true);
        btnSendOtp.setAlpha(1.0f);
        btnSendOtp.setText("Send OTP");

        // Clear OTP field
        etOtp.setText("");
        isOtpSent = false;
        isOtpVerified = false;

        // Hide OTP container temporarily
        otpContainer.setVisibility(View.GONE);
        btnVerifyOtp.setVisibility(View.GONE);
        tvTimer.setVisibility(View.GONE);

        // Send OTP again
        sendOtp();
    }

    private void verifyOtp() {
        String inputOtp = etOtp.getText().toString().trim();

        if (!isOtpSent) {
            Toast.makeText(this, "Please send OTP first", Toast.LENGTH_SHORT).show();
            return;
        }

        if (inputOtp.isEmpty() || inputOtp.length() != 6) {
            etOtp.setError("Enter valid 6-digit OTP");
            etOtp.requestFocus();
            return;
        }

        if (inputOtp.equals(serverOtp)) {
            isOtpVerified = true;

            // Stop the countdown timer
            if (countDownTimer != null) {
                countDownTimer.cancel();
            }
            tvTimer.setVisibility(View.GONE);
            tvResendOtp.setVisibility(View.GONE);

            Toast.makeText(this, "OTP Verified Successfully!", Toast.LENGTH_SHORT).show();
            handleSuccessfulVerification();
        } else {
            Toast.makeText(this, "Invalid OTP! Please try again.", Toast.LENGTH_SHORT).show();
            etOtp.setError("Invalid OTP");
            etOtp.requestFocus();
            etOtp.selectAll(); // Select all text for easy correction
        }
    }

    private void handleSuccessfulVerification() {
        if (!isOtpVerified) {
            Toast.makeText(this, "Please verify OTP first", Toast.LENGTH_SHORT).show();
            return;
        }

        String mobile = etMobile.getText().toString().trim();

        // Save user preferences
        SharedPreferences prefs = getSharedPreferences("UserPrefs", MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putBoolean("isLoggedIn", true);
        editor.putString("mobile", mobile);
        editor.putBoolean("isExistingUser", isExistingUser);
        editor.apply();

        // Show gender dialog AFTER OTP verification
        showGenderDialog(mobile);
    }

    private void showGenderDialog(String mobile) {
        final String[] genders = {"Male", "Female", "Other"};

        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle("Select Your Gender");
        builder.setItems(genders, (dialog, which) -> {
            String selectedGender = genders[which];

            // Save gender immediately after selection
            SharedPreferences prefs = getSharedPreferences("UserPrefs", MODE_PRIVATE);
            SharedPreferences.Editor editor = prefs.edit();
            editor.putString("gender", selectedGender);
            editor.apply();

            dialog.dismiss();

            // Show success message
            String message = isExistingUser ?
                    "Welcome back! Login successful." :
                    "Registration completed successfully!";
            Toast.makeText(this, "Gender: " + selectedGender + " selected. " + message, Toast.LENGTH_LONG).show();

            // Navigate to dashboard after a short delay
            new android.os.Handler().postDelayed(() -> {
                navigateToDashboard();
            }, 1500);
        });

        builder.setCancelable(false);
        builder.show();
    }

    private void navigateToDashboard() {
        Intent intent = new Intent(this, DashboardActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }

    private void startSmsRetriever() {
        SmsRetrieverClient client = SmsRetriever.getClient(this);
        Task<Void> task = client.startSmsRetriever();

        task.addOnSuccessListener(aVoid ->
                Log.d(TAG, "SMS Retriever started successfully")
        );

        task.addOnFailureListener(e -> {
            Log.e(TAG, "Failed to start SMS Retriever", e);
        });
    }

    private void showProgressDialog(String message) {
        if (progressDialog != null && progressDialog.isShowing()) {
            progressDialog.dismiss();
        }
        progressDialog = new ProgressDialog(this);
        progressDialog.setMessage(message);
        progressDialog.setCancelable(false);
        progressDialog.show();
    }

    private void hideProgressDialog() {
        if (progressDialog != null && progressDialog.isShowing()) {
            progressDialog.dismiss();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (countDownTimer != null) {
            countDownTimer.cancel();
        }
        if (requestQueue != null) {
            requestQueue.cancelAll(TAG);
        }
        hideProgressDialog();
    }

    @Override
    public void onBackPressed() {
        String mobile = etMobile.getText().toString().trim();
        if (isOtpSent && !isOtpVerified && !mobile.equals(TRAINER_BYPASS) && !mobile.equals(STUDENT_BYPASS)) {
            new AlertDialog.Builder(this)
                    .setTitle("Confirm Exit")
                    .setMessage("OTP verification is in progress. Are you sure you want to exit?")
                    .setPositiveButton("Exit", (dialog, which) -> {
                        super.onBackPressed();
                    })
                    .setNegativeButton("Cancel", null)
                    .show();
        } else {
            super.onBackPressed();
        }
    }
}
