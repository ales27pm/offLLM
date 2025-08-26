package com.myofflinellmapp;

import androidx.annotation.NonNull;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.module.annotations.ReactModule;

/**
 * LlamaTurboModule exposes llama.cpp based language model functionality to React
 * Native. This class replaces the previous LlamaRNModule name to align with
 * the C++ JNI symbols defined in {@code llama_jni.cpp}. The name constant and
 * React module annotation must match the JNI function prefixes
 * (e.g. Java_com_myofflinellmapp_LlamaTurboModule_...).
 */
@ReactModule(name = LlamaTurboModule.NAME)
public class LlamaTurboModule extends ReactContextBaseJavaModule {
    /**
     * The exported name of this module. Must be kept in sync with the
     * registration in the C++ JNI layer. Changing this string requires
     * updating the JNI function names in {@code llama_jni.cpp}.
     */
    public static final String NAME = "LlamaTurboModule";

    // Native methods are implemented in the accompanying C++ file.
    private native long nativeLoadModel(String modelPath, String quantizationType, int contextSize, int maxThreads);
    private native String nativeGenerate(long ctxPtr, String prompt, int maxTokens, float temperature, boolean useSparseAttention);
    private native float[] nativeEmbed(long ctxPtr, String text);
    private native void nativeClearKVCache(long ctxPtr);
    private native void nativeAddMessageBoundary(long ctxPtr);
    private native int nativeGetKVCacheSize(long ctxPtr);
    private native int nativeGetKVCacheMaxSize(long ctxPtr);
    private native WritableMap nativeGetPerformanceMetrics(long ctxPtr);
    private native void nativeAdjustPerformanceMode(long ctxPtr, String mode);
    private native void nativeFreeModel(long ctxPtr);

    /**
     * Pointer to the internal llama.cpp context. A value of zero indicates that
     * no model has been loaded.
     */
    private long mCtxPtr = 0;

    static {
        System.loadLibrary("llama_rn");
    }

    public LlamaTurboModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @Override
    @NonNull
    public String getName() {
        return NAME;
    }

    /**
     * Load a language model from the given path. The options map can specify
     * quantizationType (e.g. "none", "Q4_0") and contextSize. If options
     * are omitted, sensible defaults are used. This method resolves with a
     * status object containing metadata about the loaded model.
     */
    @ReactMethod
    public void loadModel(String modelPath, ReadableMap options, Promise promise) {
        try {
            // If options is null, create an empty map to avoid NPEs
            String quantizationType = "none";
            int contextSize = 4096;
            int maxThreads = Math.max(1, Runtime.getRuntime().availableProcessors() - 1);
            if (options != null) {
                if (options.hasKey("quantizationType")) {
                    quantizationType = options.getString("quantizationType");
                }
                if (options.hasKey("contextSize")) {
                    contextSize = options.getInt("contextSize");
                }
                if (options.hasKey("maxThreads")) {
                    maxThreads = options.getInt("maxThreads");
                }
            }

            mCtxPtr = nativeLoadModel(modelPath, quantizationType, contextSize, maxThreads);
            WritableMap result = new WritableNativeMap();
            result.putString("status", "loaded");
            result.putString("model", modelPath);
            result.putString("quantizationType", quantizationType);
            result.putInt("contextSize", contextSize);
            promise.resolve(result);
        } catch (Exception e) {
            promise.reject("LOAD_ERROR", "Failed to load model: " + e.getMessage());
        }
    }

    /**
     * Generate a completion given the prompt and generation options. The
     * options map can specify maxTokens, temperature and useSparseAttention.
     */
    @ReactMethod
    public void generate(String prompt, ReadableMap options, Promise promise) {
        if (mCtxPtr == 0) {
            promise.reject("NO_MODEL", "Model not loaded");
            return;
        }
        try {
            int maxTokens = 256;
            float temperature = 0.7f;
            boolean useSparseAttention = false;
            if (options != null) {
                if (options.hasKey("maxTokens")) {
                    maxTokens = options.getInt("maxTokens");
                }
                if (options.hasKey("temperature")) {
                    temperature = (float) options.getDouble("temperature");
                }
                if (options.hasKey("useSparseAttention")) {
                    useSparseAttention = options.getBoolean("useSparseAttention");
                }
            }
            String result = nativeGenerate(mCtxPtr, prompt, maxTokens, temperature, useSparseAttention);
            promise.resolve(result);
        } catch (Exception e) {
            promise.reject("GENERATE_ERROR", "Generation failed: " + e.getMessage());
        }
    }

    /**
     * Compute the embedding for the given text. Returns a float array. The
     * values are returned as a WritableNativeArray for consumption in JS.
     */
    @ReactMethod
    public void embed(String text, Promise promise) {
        if (mCtxPtr == 0) {
            promise.reject("NO_MODEL", "Model not loaded");
            return;
        }
        try {
            float[] embedding = nativeEmbed(mCtxPtr, text);
            WritableNativeArray result = convertToWritableArray(embedding);
            promise.resolve(result);
        } catch (Exception e) {
            promise.reject("EMBED_ERROR", "Embedding failed: " + e.getMessage());
        }
    }

    @ReactMethod
    public void clearKVCache(Promise promise) {
        if (mCtxPtr != 0) {
            nativeClearKVCache(mCtxPtr);
        }
        promise.resolve(null);
    }

    @ReactMethod
    public void addMessageBoundary(Promise promise) {
        if (mCtxPtr != 0) {
            nativeAddMessageBoundary(mCtxPtr);
        }
        promise.resolve(null);
    }

    @ReactMethod
    public void getKVCacheSize(Promise promise) {
        int size = mCtxPtr != 0 ? nativeGetKVCacheSize(mCtxPtr) : 0;
        int maxSize = mCtxPtr != 0 ? nativeGetKVCacheMaxSize(mCtxPtr) : 512;
        WritableMap result = new WritableNativeMap();
        result.putInt("size", size);
        result.putInt("maxSize", maxSize);
        promise.resolve(result);
    }

    @ReactMethod
    public void getPerformanceMetrics(Promise promise) {
        if (mCtxPtr == 0) {
            promise.reject("NO_MODEL", "Model not loaded");
            return;
        }
        try {
            WritableMap metrics = nativeGetPerformanceMetrics(mCtxPtr);
            promise.resolve(metrics);
        } catch (Exception e) {
            promise.reject("METRICS_ERROR", "Failed to get metrics: " + e.getMessage());
        }
    }

    @ReactMethod
    public void adjustPerformanceMode(String mode, Promise promise) {
        if (mCtxPtr != 0) {
            nativeAdjustPerformanceMode(mCtxPtr, mode);
        }
        promise.resolve(null);
    }

    @ReactMethod
    public void freeModel(Promise promise) {
        if (mCtxPtr != 0) {
            nativeFreeModel(mCtxPtr);
            mCtxPtr = 0;
        }
        promise.resolve(null);
    }

    private WritableNativeArray convertToWritableArray(float[] array) {
        WritableNativeArray result = new WritableNativeArray();
        for (float value : array) {
            result.pushDouble(value);
        }
        return result;
    }
}

