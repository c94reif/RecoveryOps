package com.circlex.circle_x_android;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener;
import io.flutter.plugin.common.StandardMethodCodec;
import java.util.ArrayList;
import java.util.List;

public class CircleXAndroidPlugin implements FlutterPlugin, ActivityAware,
    MethodChannel.MethodCallHandler, RequestPermissionsResultListener {
  static final String CHANNEL_NAME = "circle_x/pmcs_notifications";
  static final int PERMISSION_REQUEST = 48216;
  private final Handler main = new Handler(Looper.getMainLooper());
  private final List<MethodChannel.Result> permissionResults = new ArrayList<>();
  private volatile PmcsNotifications notifications;
  private MethodChannel channel;
  private ActivityPluginBinding activityBinding;
  private boolean permissionInFlight;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    initialize(binding.getApplicationContext());
    // SQLite commits and notification posting run serially off the UI thread.
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME,
        StandardMethodCodec.INSTANCE, binding.getBinaryMessenger().makeBackgroundTaskQueue());
    channel.setMethodCallHandler(this);
  }

  void initialize(Context context) {
    notifications = new PmcsNotifications(context);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    PmcsNotifications current = notifications;
    if (current == null) {
      result.error("detached", "Notification helper is unavailable", null);
      return;
    }
    try {
      switch (call.method) {
        case "getStatus":
          result.success(current.status());
          break;
        case "setEnabled":
          Object enabled = call.argument("enabled");
          if (!(enabled instanceof Boolean)) throw new IllegalArgumentException("enabled must be a boolean");
          current.setEnabled((Boolean) enabled);
          main.post(() -> requestPermissionIfNeeded(current, (Boolean) enabled, result));
          break;
        case "rememberReports":
          Object ids = call.argument("reportIds");
          if (!(ids instanceof List<?>)) throw new IllegalArgumentException("reportIds must be a list");
          List<String> reportIds = new ArrayList<>();
          for (Object id : (List<?>) ids) reportIds.add(requiredText(id, "reportId"));
          current.remember(reportIds);
          result.success(null);
          break;
        case "showReport":
          String reportId = requiredText(call.argument("reportId"), "reportId");
          String title = requiredText(call.argument("title"), "title");
          Object body = call.argument("body");
          if (!(body instanceof String)) throw new IllegalArgumentException("body must be text");
          current.show(reportId, title, (String) body);
          result.success(null);
          break;
        case "openSettings":
          current.openSettings();
          result.success(null);
          break;
        default:
          result.notImplemented();
      }
    } catch (IllegalArgumentException invalid) {
      result.error("invalid_arguments", invalid.getMessage(), null);
    } catch (RuntimeException failure) {
      result.error("notification_error", failure.getMessage(), null);
    }
  }

  private static String requiredText(Object value, String field) {
    if (!(value instanceof String) || ((String) value).trim().isEmpty()) {
      throw new IllegalArgumentException(field + " must be nonempty text");
    }
    return (String) value;
  }

  private synchronized void requestPermissionIfNeeded(PmcsNotifications current,
      boolean enabled, MethodChannel.Result result) {
    if (notifications != current) {
      result.error("detached", "Notification helper was detached", null);
      return;
    }
    try {
      if (!enabled || !Boolean.TRUE.equals(current.status().get("enabled"))
          || !current.needsRuntimePermission()) {
        result.success(current.status());
        return;
      }
      Activity activity = activityBinding == null ? null : activityBinding.getActivity();
      if (activity == null || activity.isFinishing() || activity.isDestroyed()) {
        // Opt-in is retained, but no prompt is possible without a foreground Activity.
        result.success(current.status());
        return;
      }
      permissionResults.add(result);
      if (permissionInFlight) return;
      permissionInFlight = true;
      try {
        activity.requestPermissions(new String[] {Manifest.permission.POST_NOTIFICATIONS}, PERMISSION_REQUEST);
      } catch (RuntimeException failure) {
        finishPermissionRequests();
      }
    } catch (RuntimeException failure) {
      result.error("notification_error", failure.getMessage(), null);
    }
  }

  private synchronized void finishPermissionRequests() {
    permissionInFlight = false;
    List<MethodChannel.Result> pending = new ArrayList<>(permissionResults);
    permissionResults.clear();
    for (MethodChannel.Result result : pending) {
      try {
        if (notifications == null) result.error("detached", "Notification helper was detached", null);
        else result.success(notifications.status());
      } catch (RuntimeException failure) {
        result.error("notification_error", failure.getMessage(), null);
      }
    }
  }

  @Override
  public synchronized boolean onRequestPermissionsResult(int requestCode,
      @NonNull String[] permissions, @NonNull int[] grantResults) {
    if (requestCode != PERMISSION_REQUEST) return false;
    finishPermissionRequests();
    return true;
  }

  @Override
  public synchronized void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activityBinding = binding;
    binding.addRequestPermissionsResultListener(this);
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public synchronized void onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity();
  }

  @Override
  public synchronized void onDetachedFromActivity() {
    if (activityBinding != null) activityBinding.removeRequestPermissionsResultListener(this);
    activityBinding = null;
    // Never retain an Activity or leave Dart waiting through a detach/rotation.
    finishPermissionRequests();
  }

  @Override
  public synchronized void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) channel.setMethodCallHandler(null);
    channel = null;
    onDetachedFromActivity();
    PmcsNotifications previous = notifications;
    notifications = null;
    if (previous != null) previous.close();
  }
}
