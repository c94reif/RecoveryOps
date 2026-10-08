package com.circlex.circle_x_android;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;
import static org.robolectric.Shadows.shadowOf;

import android.Manifest;
import android.app.Activity;
import android.app.Application;
import android.content.pm.PackageManager;
import android.os.Looper;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.util.Arrays;
import java.util.Collections;
import java.util.Map;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 33)
public class CircleXAndroidPluginTest {
  private Application context;
  private CircleXAndroidPlugin plugin;
  private Activity activity;
  private ActivityPluginBinding binding;

  @Before
  public void setUp() {
    context = RuntimeEnvironment.getApplication();
    context.deleteDatabase(new File(context.getNoBackupFilesDir(),
        "circle_x_pmcs_notifications.db").getAbsolutePath());
    shadowOf(context).denyPermissions(Manifest.permission.POST_NOTIFICATIONS);
    plugin = new CircleXAndroidPlugin();
    plugin.initialize(context);
    activity = Robolectric.buildActivity(Activity.class).setup().get();
    binding = mock(ActivityPluginBinding.class);
    when(binding.getActivity()).thenReturn(activity);
    plugin.onAttachedToActivity(binding);
  }

  @After
  public void tearDown() {
    plugin.onDetachedFromEngine(null);
  }

  private Reply invoke(String method, Map<String, Object> arguments) {
    Reply reply = new Reply();
    plugin.onMethodCall(new MethodCall(method, arguments), reply);
    shadowOf(Looper.getMainLooper()).idle();
    return reply;
  }

  @Test
  public void concurrentEnableRequestsShareOnePermissionPromptAndFinishOnGrant() {
    Reply first = invoke("setEnabled", Collections.singletonMap("enabled", true));
    Reply second = invoke("setEnabled", Collections.singletonMap("enabled", true));
    assertEquals(0, first.completions);
    assertEquals(0, second.completions);
    assertArrayEquals(new String[] {Manifest.permission.POST_NOTIFICATIONS},
        shadowOf(activity).getLastRequestedPermission().requestedPermissions);
    shadowOf(context).grantPermissions(Manifest.permission.POST_NOTIFICATIONS);
    assertTrue(plugin.onRequestPermissionsResult(CircleXAndroidPlugin.PERMISSION_REQUEST,
        new String[] {Manifest.permission.POST_NOTIFICATIONS},
        new int[] {PackageManager.PERMISSION_GRANTED}));
    assertEquals(true, first.status().get("permissionGranted"));
    assertEquals(true, second.status().get("enabled"));
    assertEquals(1, first.completions);
    assertEquals(1, second.completions);
  }

  @Test
  public void denialIsAUsableStatusAndReceiptNeverAsksForPermission() {
    Reply enabling = invoke("setEnabled", Collections.singletonMap("enabled", true));
    plugin.onRequestPermissionsResult(CircleXAndroidPlugin.PERMISSION_REQUEST,
        new String[] {Manifest.permission.POST_NOTIFICATIONS},
        new int[] {PackageManager.PERMISSION_DENIED});
    assertEquals(false, enabling.status().get("permissionGranted"));
    assertEquals(true, enabling.status().get("enabled"));
    Reply receipt = invoke("showReport", Map.of("reportId", "pmcs-1", "title", "PMCS", "body", "A-11"));
    assertEquals(1, receipt.completions);
    assertNull(receipt.error);
    assertFalse(plugin.onRequestPermissionsResult(12, new String[0], new int[0]));
  }

  @Test
  public void disablingWhilePromptIsOpenWinsWhenPermissionReturns() {
    Reply enabling = invoke("setEnabled", Collections.singletonMap("enabled", true));
    Reply disabling = invoke("setEnabled", Collections.singletonMap("enabled", false));
    assertEquals(false, disabling.status().get("enabled"));
    shadowOf(context).grantPermissions(Manifest.permission.POST_NOTIFICATIONS);
    plugin.onRequestPermissionsResult(CircleXAndroidPlugin.PERMISSION_REQUEST,
        new String[] {Manifest.permission.POST_NOTIFICATIONS},
        new int[] {PackageManager.PERMISSION_GRANTED});
    assertEquals(false, enabling.status().get("enabled"));
    assertEquals(1, enabling.completions);
  }

  @Test
  public void activityDetachCompletesPermissionWaitersAndRemovesListener() {
    Reply enabling = invoke("setEnabled", Collections.singletonMap("enabled", true));
    plugin.onDetachedFromActivityForConfigChanges();
    verify(binding).removeRequestPermissionsResultListener(plugin);
    assertEquals(1, enabling.completions);
    assertEquals(false, enabling.status().get("permissionGranted"));
    plugin.onReattachedToActivityForConfigChanges(binding);
    plugin.onRequestPermissionsResult(CircleXAndroidPlugin.PERMISSION_REQUEST,
        new String[0], new int[0]);
    assertEquals(1, enabling.completions);
  }

  @Test
  public void noActivityRetainsOptInWithoutHangingOrPrompting() {
    plugin.onDetachedFromActivity();
    Reply enabling = invoke("setEnabled", Collections.singletonMap("enabled", true));
    assertEquals(1, enabling.completions);
    assertEquals(true, enabling.status().get("enabled"));
    assertEquals(false, enabling.status().get("permissionGranted"));
    assertNull(shadowOf(activity).getLastRequestedPermission());
  }

  @Test
  public void engineDetachBeforePermissionDispatchCompletesOnce() {
    Reply reply = new Reply();
    plugin.onMethodCall(new MethodCall("setEnabled", Collections.singletonMap("enabled", true)), reply);
    plugin.onDetachedFromEngine(null);
    shadowOf(Looper.getMainLooper()).idle();
    assertEquals(1, reply.completions);
    assertEquals("detached", reply.error);
  }

  @Test
  public void invalidBatchIsRejectedBeforeAnyIdsAreRemembered() {
    Reply invalid = invoke("rememberReports", Map.of("reportIds", Arrays.asList("valid", 7)));
    assertEquals("invalid_arguments", invalid.error);
    shadowOf(context).grantPermissions(Manifest.permission.POST_NOTIFICATIONS);
    invoke("setEnabled", Collections.singletonMap("enabled", true));
    Reply valid = invoke("showReport", Map.of("reportId", "valid", "title", "PMCS", "body", "A-11"));
    assertNull(valid.error);
    android.app.NotificationManager manager =
        (android.app.NotificationManager) context.getSystemService(Application.NOTIFICATION_SERVICE);
    assertEquals(1, shadowOf(manager).size());
  }

  private static final class Reply implements MethodChannel.Result {
    Object value;
    String error;
    int completions;

    @Override
    public void success(Object value) {
      this.value = value;
      completions++;
    }

    @Override
    public void error(String code, String message, Object details) {
      error = code;
      completions++;
    }

    @Override
    public void notImplemented() {
      error = "not_implemented";
      completions++;
    }

    @SuppressWarnings("unchecked")
    Map<String, Object> status() {
      assertNull(error);
      return (Map<String, Object>) value;
    }
  }
}
