package com.circlex.circle_x_android;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.database.sqlite.SQLiteStatement;
import java.io.File;
import java.util.List;

/** Phone-local opt-in and durable report IDs; neither participates in Android backup. */
final class PmcsNotificationStore extends SQLiteOpenHelper {
  PmcsNotificationStore(Context context) {
    super(context, new File(context.getNoBackupFilesDir(),
        "circle_x_pmcs_notifications.db").getAbsolutePath(), null, 1);
  }

  @Override
  public void onCreate(SQLiteDatabase db) {
    db.execSQL("CREATE TABLE observed_reports (report_id TEXT PRIMARY KEY NOT NULL)");
    db.execSQL("CREATE TABLE settings (id INTEGER PRIMARY KEY CHECK(id = 1), "
        + "enabled INTEGER NOT NULL DEFAULT 0)");
    db.execSQL("INSERT INTO settings (id, enabled) VALUES (1, 0)");
  }

  @Override
  public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
    throw new IllegalStateException("Unsupported notification database upgrade");
  }

  synchronized boolean isEnabled() {
    try (Cursor row = getReadableDatabase().rawQuery(
        "SELECT enabled FROM settings WHERE id = 1", null)) {
      return row.moveToFirst() && row.getInt(0) != 0;
    }
  }

  synchronized void setEnabled(boolean enabled) {
    ContentValues values = new ContentValues();
    values.put("enabled", enabled ? 1 : 0);
    if (getWritableDatabase().update("settings", values, "id = 1", null) != 1) {
      throw new IllegalStateException("Notification settings could not be saved");
    }
  }

  synchronized boolean claim(String reportId) {
    try (SQLiteStatement insert = getWritableDatabase().compileStatement(
        "INSERT OR IGNORE INTO observed_reports (report_id) VALUES (?)")) {
      insert.bindString(1, reportId);
      return insert.executeInsert() != -1;
    }
  }

  synchronized void remember(List<String> reportIds) {
    SQLiteDatabase db = getWritableDatabase();
    db.beginTransaction();
    try (SQLiteStatement insert = db.compileStatement(
        "INSERT OR IGNORE INTO observed_reports (report_id) VALUES (?)")) {
      for (String reportId : reportIds) {
        insert.bindString(1, reportId);
        insert.executeInsert();
      }
      db.setTransactionSuccessful();
    } finally {
      db.endTransaction();
    }
  }

  synchronized void release(String reportId) {
    getWritableDatabase().delete("observed_reports", "report_id = ?",
        new String[] {reportId});
  }
}
