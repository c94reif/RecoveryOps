import 'package:flutter/material.dart';

/// Semantic icon registry — maps concepts to [IconData] values.
///
/// Prevents different files from choosing different icons for the same action.
/// If a custom icon font is added in the future, change values here and all
/// consumers update automatically.
class LatticeIcons {
  LatticeIcons._();

  // ── Actions ──

  static const IconData close = Icons.close;
  static const IconData settings = Icons.settings;
  static const IconData search = Icons.search;
  static const IconData save = Icons.save;
  static const IconData send = Icons.send;
  static const IconData add = Icons.add;
  static const IconData delete = Icons.delete_outline;
  static const IconData edit = Icons.edit;
  static const IconData copy = Icons.copy;
  static const IconData undo = Icons.undo;
  static const IconData refresh = Icons.refresh;
  static const IconData info = Icons.info_outline;
  static const IconData check = Icons.check_circle;
  static const IconData warning = Icons.warning_amber;
  static const IconData error = Icons.error_outline;

  // ── Navigation ──

  static const IconData back = Icons.arrow_back;
  static const IconData menu = Icons.menu;
  static const IconData expand = Icons.expand_more;
  static const IconData collapse = Icons.expand_less;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData popOut = Icons.open_in_new;
  static const IconData dock = Icons.view_sidebar;

  // ── Domain: Map ──

  static const IconData map = Icons.map_outlined;
  static const IconData location = Icons.location_on;
  static const IconData myLocation = Icons.my_location;
  static const IconData addLocation = Icons.add_location_alt;
  static const IconData layers = Icons.layers_outlined;
  static const IconData measure = Icons.straighten;
  static const IconData satellite = Icons.satellite_alt;

  // ── Domain: Tasks & Entities ──

  static const IconData fireMission = Icons.gps_fixed;
  static const IconData task = Icons.assignment;
  static const IconData entity = Icons.radar;
  static const IconData shield = Icons.shield_outlined;
  static const IconData fireSupport = Icons.local_fire_department;

  // ── Domain: Communication ──

  static const IconData chat = Icons.chat_outlined;
  static const IconData mic = Icons.mic;
  static const IconData speaker = Icons.volume_up;
  static const IconData contacts = Icons.contacts_outlined;

  // ── Domain: System ──

  static const IconData plugin = Icons.extension;
  static const IconData pin = Icons.push_pin;
  static const IconData unpin = Icons.push_pin_outlined;
  static const IconData person = Icons.person;
  static const IconData time = Icons.access_time;
  static const IconData battery = Icons.battery_std;
  static const IconData network = Icons.wifi;
  static const IconData grid = Icons.grid_view_rounded;
  static const IconData dns = Icons.dns_outlined;
  static const IconData cellTower = Icons.cell_tower;
  static const IconData debug = Icons.bug_report_outlined;
  static const IconData log = Icons.receipt_long;

  // ── Domain: Media ──

  static const IconData camera = Icons.photo_camera;
  static const IconData gallery = Icons.photo_library;
  static const IconData attach = Icons.add_a_photo;
}
