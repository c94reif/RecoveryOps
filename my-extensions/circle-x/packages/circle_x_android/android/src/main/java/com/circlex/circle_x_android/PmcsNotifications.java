package com.circlex.circle_x_android;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

final class PmcsNotifications {
  static final String CHANNEL_ID = "circle_x_pmcs_silent_v1";
  private final Context context;
  private final NotificationManager manager;
  private final PmcsNotificationStore store;
  private boolean closed;

  PmcsNotifications(Context context) {
    this.context = context.getApplicationContext();
    manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
    store = new PmcsNotificationStore(this.context);
  }

  synchronized Map<String, Object> status() {
    ensureOpen();
    Map<String, Object> status = new HashMap<>();
    status.put("supported", true);
    status.put("enabled", store.isEnabled());
    status.put("permissionGranted", permissionGranted());
    return status;
  }

  boolean needsRuntimePermission() {
    return Build.VERSION.SDK_INT >= 33
        && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED;
  }

  private boolean permissionGranted() {
    if (needsRuntimePermission() || !NotificationManagerCompat.from(context).areNotificationsEnabled()) {
      return false;
    }
    if (Build.VERSION.SDK_INT >= 26) {
      NotificationChannel channel = manager.getNotificationChannel(CHANNEL_ID);
      return channel == null || channel.getImportance() != NotificationManager.IMPORTANCE_NONE;
    }
    return true;
  }

  synchronized void setEnabled(boolean enabled) {
    ensureOpen();
    // Channel creation is intentional only after a user opts in. Legacy targets
    // can trigger Android's permission prompt when creating their first channel.
    store.setEnabled(enabled);
    if (enabled) ensureChannel();
  }

  private void ensureChannel() {
    if (Build.VERSION.SDK_INT < 26) return;
    NotificationChannel channel = new NotificationChannel(
        CHANNEL_ID, "Circle X PMCS reports", NotificationManager.IMPORTANCE_LOW);
    channel.setDescription("Silent updates for your selected units");
    channel.setSound(null, null);
    channel.enableVibration(false);
    channel.enableLights(false);
    channel.setLockscreenVisibility(Notification.VISIBILITY_PRIVATE);
    manager.createNotificationChannel(channel);
  }

  synchronized void remember(List<String> reportIds) {
    ensureOpen();
    store.remember(reportIds);
  }

  synchronized void show(String reportId, String title, String body) {
    ensureOpen();
    // Commit before posting. Disabled/denied receipts are consumed as well,
    // so opting in later cannot replay reports already seen on this phone.
    if (!store.claim(reportId)) return;
    if (!store.isEnabled() || !permissionGranted()) return;
    try {
      ensureChannel();
      manager.notify("circle_x_pmcs:" + reportId, 0, buildNotification(title, body));
    } catch (SecurityException denied) {
      // Permission may have changed since the check. Keep this receipt consumed.
    } catch (RuntimeException failure) {
      // A synchronous build/post failure did not deliver the report. Allow retry.
      store.release(reportId);
      throw failure;
    }
  }

  private Notification buildNotification(String title, String body) {
    NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID);
    builder.setSmallIcon(R.drawable.ic_circle_x_pmcs_notification)
        .setContentTitle(title)
        .setContentText(body)
        .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
        .setCategory(Notification.CATEGORY_STATUS)
        .setVisibility(Notification.VISIBILITY_PRIVATE)
        .setPriority(Notification.PRIORITY_LOW)
        .setDefaults(0)
        .setSound(null)
        .setVibrate(null)
        .setLights(0, 0, 0)
        .setSilent(true)
        .setOnlyAlertOnce(true)
        .setAutoCancel(true);
    Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
    if (launch != null) {
      launch.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
      int flags = PendingIntent.FLAG_UPDATE_CURRENT;
      if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
      builder.setContentIntent(PendingIntent.getActivity(context, 0, launch, flags));
    }
    return builder.build();
  }

  synchronized void openSettings() {
    ensureOpen();
    Intent settings;
    if (Build.VERSION.SDK_INT >= 26 && !needsRuntimePermission()
        && NotificationManagerCompat.from(context).areNotificationsEnabled()
        && manager.getNotificationChannel(CHANNEL_ID) != null) {
      settings = new Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
          .putExtra(Settings.EXTRA_APP_PACKAGE, context.getPackageName())
          .putExtra(Settings.EXTRA_CHANNEL_ID, CHANNEL_ID);
    } else if (Build.VERSION.SDK_INT >= 26) {
      settings = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
          .putExtra(Settings.EXTRA_APP_PACKAGE, context.getPackageName());
    } else {
      settings = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
          Uri.parse("package:" + context.getPackageName()));
    }
    settings.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    try {
      context.startActivity(settings);
    } catch (android.content.ActivityNotFoundException unavailable) {
      context.startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
          Uri.parse("package:" + context.getPackageName())).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
    }
  }

  synchronized void close() {
    closed = true;
    store.close();
  }

  private void ensureOpen() {
    if (closed) throw new IllegalStateException("Notification helper was detached");
  }
}
