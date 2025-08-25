package com.myofflinellmapp;

import androidx.annotation.NonNull;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.module.annotations.ReactModule;

@ReactModule(name = LlamaRNModule.NAME)
public class LlamaRNModule extends ReactContextBaseJavaModule {
    public static final String NAME = "LlamaRN";
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
    
    private long mCtxPtr = 0;

    static {
        System.loadLibrary("llama_rn");
    }

    public LlamaRNModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @Override
    @NonNull
    public String getName() {
        return NAME;
    }

    @ReactMethod
    public void loadModel(String modelPath, ReadableMap options, Promise promise) {
        try {
            String quantizationType = options.hasKey("quantizationType") ? 
                options.getString("quantizationType") : "none";
            int contextSize = options.hasKey("contextSize") ? 
                options.getInt("contextSize") : 4096;
            int maxThreads = options.hasKey("maxThreads") ? 
                options.getInt("maxThreads") : Math.max(1, Runtime.getRuntime().availableProcessors() - 1);
            
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

    @ReactMethod
    public void generate(String prompt, ReadableMap options, Promise promise) {
        if (mCtxPtr == 0) {
            promise.reject("NO_MODEL", "Model not loaded");
            return;
        }

        try {
            int maxTokens = options.hasKey("maxTokens") ? options.getInt("maxTokens") : 256;
            float temperature = options.hasKey("temperature") ? 
                (float) options.getDouble("temperature") : 0.7f;
            boolean useSparseAttention = options.hasKey("useSparseAttention") && 
                options.getBoolean("useSparseAttention");
            
            String result = nativeGenerate(mCtxPtr, prompt, maxTokens, temperature, useSparseAttention);
            promise.resolve(result);
        } catch (Exception e) {
            promise.reject("GENERATE_ERROR", "Generation failed: " + e.getMessage());
        }
    }

    @ReactMethod
    public void embed(String text, Promise promise) {
        if (mCtxPtr == 0) {
            promise.reject("NO_MODEL", "Model not loaded");
            return;
        }

        try {
            float[] embedding = nativeEmbed(mCtxPtr, text);
            promise.resolve(convertToWritableArray(embedding));
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
