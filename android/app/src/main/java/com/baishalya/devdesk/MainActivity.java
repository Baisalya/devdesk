package com.baishalya.devdesk;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import androidx.annotation.NonNull;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "devdesk/secure_secrets";
    private static final String KEY_ALIAS = "devdesk_workspace_secret_key_v1";
    private static final String PREFS_NAME = "devdesk_secure_secrets_v1";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(this::handleSecureSecretCall);
    }

    private void handleSecureSecretCall(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "isAvailable":
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.M);
                    return;
                case "write":
                    writeSecret(requireArgument(call, "key"), requireArgument(call, "value"));
                    result.success(null);
                    return;
                case "read":
                    result.success(readSecret(requireArgument(call, "key")));
                    return;
                case "delete":
                    preferences().edit().remove(requireArgument(call, "key")).commit();
                    result.success(null);
                    return;
                case "clearAll":
                    preferences().edit().clear().commit();
                    result.success(null);
                    return;
                default:
                    result.notImplemented();
            }
        } catch (Exception error) {
            result.error("secure_store_failure", "Protected storage operation failed.", null);
        }
    }

    private String requireArgument(MethodCall call, String name) {
        String value = call.argument(name);
        if (value == null || value.length() == 0) {
            throw new IllegalArgumentException("Missing argument");
        }
        return value;
    }

    private SharedPreferences preferences() {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    private void writeSecret(String key, String value) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey());
        byte[] encrypted = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));
        String payload = Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP)
                + "."
                + Base64.encodeToString(encrypted, Base64.NO_WRAP);
        if (!preferences().edit().putString(key, payload).commit()) {
            throw new IllegalStateException("Could not commit protected value");
        }
    }

    private String readSecret(String key) throws Exception {
        String payload = preferences().getString(key, null);
        if (payload == null) return null;
        String[] parts = payload.split("\\.", 2);
        if (parts.length != 2) throw new IllegalStateException("Invalid protected payload");
        byte[] iv = Base64.decode(parts[0], Base64.NO_WRAP);
        byte[] encrypted = Base64.decode(parts[1], Base64.NO_WRAP);
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), new GCMParameterSpec(128, iv));
        return new String(cipher.doFinal(encrypted), StandardCharsets.UTF_8);
    }

    private SecretKey getOrCreateKey() throws Exception {
        KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
        keyStore.load(null);
        if (keyStore.containsAlias(KEY_ALIAS)) {
            return ((KeyStore.SecretKeyEntry) keyStore.getEntry(KEY_ALIAS, null)).getSecretKey();
        }
        KeyGenerator generator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                "AndroidKeyStore"
        );
        generator.init(new KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT
        )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build());
        return generator.generateKey();
    }
}
