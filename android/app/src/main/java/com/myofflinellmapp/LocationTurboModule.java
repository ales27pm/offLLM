package com.myofflinellmapp;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.os.Looper;
import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.module.annotations.ReactModule;

/**
 * LocationTurboModule provides access to the device's current location and
 * continuous updates. It uses the system {@link LocationManager} rather
 * than Google Play services, keeping the dependency footprint small. This
 * module requires that the app has been granted ACCESS_FINE_LOCATION or
 * ACCESS_COARSE_LOCATION permissions. Location updates are delivered on
 * the main looper to ensure callbacks occur on the UI thread.
 */
@ReactModule(name = LocationTurboModule.NAME)
public class LocationTurboModule extends ReactContextBaseJavaModule {
    public static final String NAME = "LocationTurboModule";
    private LocationListener continuousListener;

    public LocationTurboModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @NonNull
    @Override
    public String getName() {
        return NAME;
    }

    @ReactMethod
    public void getCurrentLocation(String accuracy, Promise promise) {
        LocationManager manager = (LocationManager) getReactApplicationContext().getSystemService(Context.LOCATION_SERVICE);
        if (manager == null) {
            promise.reject("location_error", "Location service unavailable");
            return;
        }
        String provider = chooseProvider(manager, accuracy);
        if (provider == null) {
            promise.reject("location_error", "No location provider available");
            return;
        }
        // Check permissions
        if (!hasLocationPermission()) {
            promise.reject("permission_denied", "Location permission denied");
            return;
        }
        // Try last known location first
        @SuppressLint("MissingPermission") Location last = manager.getLastKnownLocation(provider);
        if (last != null) {
            promise.resolve(locationToMap(last));
            return;
        }
        // Request single update
        LocationListener singleListener = new LocationListener() {
            @Override
            public void onLocationChanged(@NonNull Location location) {
                promise.resolve(locationToMap(location));
                manager.removeUpdates(this);
            }
            @Override public void onStatusChanged(String provider, int status, Bundle extras) {}
            @Override public void onProviderEnabled(@NonNull String provider) {}
            @Override public void onProviderDisabled(@NonNull String provider) {}
        };
        try {
            manager.requestSingleUpdate(provider, singleListener, Looper.getMainLooper());
        } catch (SecurityException e) {
            promise.reject("permission_denied", "Location permission denied", e);
        }
    }

    @ReactMethod
    public void startUpdates(int intervalMillis) {
        LocationManager manager = (LocationManager) getReactApplicationContext().getSystemService(Context.LOCATION_SERVICE);
        if (manager == null) return;
        String provider = chooseProvider(manager, "high");
        if (provider == null) return;
        if (!hasLocationPermission()) return;
        if (continuousListener != null) {
            manager.removeUpdates(continuousListener);
            continuousListener = null;
        }
        continuousListener = new LocationListener() {
            @Override
            public void onLocationChanged(@NonNull Location location) {
                // emit event to JS via DeviceEventEmitter (not implemented here). You can
                // integrate with RCTDeviceEventEmitter if needed. For now this is a
                // no-op placeholder.
            }
            @Override public void onStatusChanged(String provider, int status, Bundle extras) {}
            @Override public void onProviderEnabled(@NonNull String provider) {}
            @Override public void onProviderDisabled(@NonNull String provider) {}
        };
        try {
            manager.requestLocationUpdates(provider, Math.max(1000, intervalMillis), 0f, continuousListener, Looper.getMainLooper());
        } catch (SecurityException ignored) {
            // permission denied
        }
    }

    @ReactMethod
    public void stopUpdates() {
        LocationManager manager = (LocationManager) getReactApplicationContext().getSystemService(Context.LOCATION_SERVICE);
        if (manager == null) return;
        if (continuousListener != null) {
            try {
                manager.removeUpdates(continuousListener);
            } catch (SecurityException ignored) {
            }
            continuousListener = null;
        }
    }

    private boolean hasLocationPermission() {
        ReactApplicationContext ctx = getReactApplicationContext();
        return ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }

    private String chooseProvider(LocationManager manager, String accuracy) {
        String provider;
        if ("high".equalsIgnoreCase(accuracy)) {
            provider = LocationManager.GPS_PROVIDER;
        } else if ("medium".equalsIgnoreCase(accuracy)) {
            provider = LocationManager.NETWORK_PROVIDER;
        } else {
            provider = LocationManager.PASSIVE_PROVIDER;
        }
        if (manager.isProviderEnabled(provider)) {
            return provider;
        }
        // Fallback to any enabled provider
        if (manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) return LocationManager.NETWORK_PROVIDER;
        if (manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) return LocationManager.GPS_PROVIDER;
        if (manager.isProviderEnabled(LocationManager.PASSIVE_PROVIDER)) return LocationManager.PASSIVE_PROVIDER;
        return null;
    }

    private WritableMap locationToMap(Location location) {
        WritableMap map = new WritableNativeMap();
        map.putDouble("latitude", location.getLatitude());
        map.putDouble("longitude", location.getLongitude());
        if (location.hasAltitude()) map.putDouble("altitude", location.getAltitude());
        if (location.hasAccuracy()) map.putDouble("accuracy", location.getAccuracy());
        if (location.hasSpeed()) map.putDouble("speed", location.getSpeed());
        if (location.hasBearing()) map.putDouble("course", location.getBearing());
        return map;
    }
}
