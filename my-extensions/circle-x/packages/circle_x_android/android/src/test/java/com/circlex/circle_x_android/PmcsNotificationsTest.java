package com.circlex.circle_x_android;

import static org.junit.Assert.*;
import static org.robolectric.Shadows.shadowOf;

import android.Manifest;
import android.app.Application;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.provider.Settings;
import java.io.File;
import java.util.Arrays;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 33)
public class PmcsNotificationsTest {
  private Application context;
  private NotificationManager manager;
  private PmcsNotifications notifications;

  @Before
  public void setUp() {
    context = RuntimeEnvironment.getApplication();
    context.deleteDatabase(new File(context.getNoBackupFilesDir(),
        "circle_x_pmcs_notifications.db").getAbsolutePath());
    manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
    shadowOf(context).grantPermissions(Manifest.permission.POST_NOTIFICATIONS);
    notifications = new PmcsNotifications(context);
  }

  @After
  public void tearDown() {
    notifications.close();
  }

  @Test
  public void defaultsOffAndObservingDoesNotCreateChannelOrAlert() {
    assertEquals(false, notifications.status().get("enabled"));
    notifications.show("before-opt-in", "PMCS", "A-11");
    assertNull(manager.getNotificationChannel(PmcsNotifications.CHANNEL_ID));
    assertEquals(0, shadowOf(manager).size());
    notifications.setEnabled(true);
    notifications.show("before-opt-in", "PMCS", "A-11");
    assertEquals(0, shadowOf(manager).size());
  }

  @Test
  public void optInAndObservedIdsSurviveRestartAndDismissal() {
    notifications.setEnabled(true);
    notifications.show("report-1", "PMCS", "A-11");
    assertEquals(1, shadowOf(manager).size());
    manager.cancelAll();
    notifications.close();
    notifications = new PmcsNotifications(context);
    assertEquals(true, notifications.status().get("enabled"));
    notifications.show("report-1", "PMCS", "A-11 changed");
    assertEquals(0, shadowOf(manager).size());
    notifications.show("report-2", "PMCS", "A-12");
    assertEquals(1, shadowOf(manager).size());
  }

  @Test
  public void rememberingHistoryPersistsWithoutAlerts() {
    notifications.setEnabled(true);
    notifications.remember(Arrays.asList("old-1", "old-2", "old-1"));
    notifications.close();
    notifications = new PmcsNotifications(context);
    notifications.show("old-1", "PMCS", "Historical");
    notifications.show("old-2", "PMCS", "Historical");
    assertEquals(0, shadowOf(manager).size());
    notifications.show("new-1", "PMCS", "New");
    assertEquals(1, shadowOf(manager).size());
  }

  @Test
  public void deniedPermissionConsumesReceiptsWithoutBacklog() {
    notifications.setEnabled(true);
    shadowOf(context).denyPermissions(Manifest.permission.POST_NOTIFICATIONS);
    assertEquals(false, notifications.status().get("permissionGranted"));
    notifications.show("denied", "PMCS", "Private report");
    shadowOf(context).grantPermissions(Manifest.permission.POST_NOTIFICATIONS);
    notifications.show("denied", "PMCS", "Private report");
    assertEquals(0, shadowOf(manager).size());
    notifications.show("allowed", "PMCS", "Private report");
    assertEquals(1, shadowOf(manager).size());
  }

  @Test
  public void blockedChannelIsReflectedAndConsumesReceipt() {
    notifications.setEnabled(true);
    NotificationChannel channel = manager.getNotificationChannel(PmcsNotifications.CHANNEL_ID);
    channel.setImportance(NotificationManager.IMPORTANCE_NONE);
    manager.createNotificationChannel(channel);
    assertEquals(false, notifications.status().get("permissionGranted"));
    notifications.show("blocked", "PMCS", "A-11");
    assertEquals(0, shadowOf(manager).size());
  }

  @Test
  @Config(sdk = {23, 33})
  public void notificationsAreSilentPrivateAndUseDistinctStableTags() {
    notifications.setEnabled(true);
    notifications.show("Aa", "First PMCS", "A-11");
    notifications.show("BB", "Second PMCS", "A-12");
    // These strings have the same Java hashCode. Full report tags must avoid collisions.
    assertEquals(2, shadowOf(manager).size());
    Notification first = shadowOf(manager).getNotification("circle_x_pmcs:Aa", 0);
    assertNotNull(first);
    assertEquals("First PMCS", first.extras.getString(Notification.EXTRA_TITLE));
    assertEquals(Notification.PRIORITY_LOW, first.priority);
    assertEquals(Notification.VISIBILITY_PRIVATE, first.visibility);
    assertEquals(0, first.defaults);
    assertNull(first.sound);
    assertNull(first.vibrate);
    assertTrue((first.flags & Notification.FLAG_ONLY_ALERT_ONCE) != 0);
    assertTrue((first.flags & Notification.FLAG_AUTO_CANCEL) != 0);
    assertNotEquals(0, first.getSmallIcon().getResId());
    if (Build.VERSION.SDK_INT >= 26) {
      NotificationChannel channel = manager.getNotificationChannel(PmcsNotifications.CHANNEL_ID);
      assertEquals(NotificationManager.IMPORTANCE_LOW, channel.getImportance());
      assertNull(channel.getSound());
      assertFalse(channel.shouldVibrate());
      assertFalse(channel.shouldShowLights());
    }
  }

  @Test
  public void systemSettingsOpenOnlyThePmcsChannel() {
    notifications.setEnabled(true);
    notifications.openSettings();
    Intent intent = shadowOf(context).getNextStartedActivity();
    assertEquals(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS, intent.getAction());
    assertEquals(PmcsNotifications.CHANNEL_ID, intent.getStringExtra(Settings.EXTRA_CHANNEL_ID));
    assertEquals(context.getPackageName(), intent.getStringExtra(Settings.EXTRA_APP_PACKAGE));
  }

  @Test
  public void deniedPermissionOpensAppNotificationSettings() {
    notifications.setEnabled(true);
    shadowOf(context).denyPermissions(Manifest.permission.POST_NOTIFICATIONS);
    notifications.openSettings();
    Intent intent = shadowOf(context).getNextStartedActivity();
    assertEquals(Settings.ACTION_APP_NOTIFICATION_SETTINGS, intent.getAction());
    assertEquals(context.getPackageName(), intent.getStringExtra(Settings.EXTRA_APP_PACKAGE));
  }

  @Test
  public void closeCannotReopenDatabaseForLateDelivery() {
    notifications.setEnabled(true);
    notifications.close();
    assertThrows(IllegalStateException.class,
        () -> notifications.show("late", "PMCS", "A-11"));
    assertEquals(0, shadowOf(manager).size());
  }
}
