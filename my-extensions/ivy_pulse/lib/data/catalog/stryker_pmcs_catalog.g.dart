// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Stryker family PMCS checks transcribed from TM 9-2355-311-10.
// Regenerate with tool/generate_catalog.sh after editing the TM source data.

import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/pmcs_category.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';

/// Stryker PMCS catalog — 78 TM checks across before, during,
/// and after operations.
const PmcsCatalog strykerPmcsCatalog = PmcsCatalog(
  vehicleType: VehicleType.stryker,
  phases: {
    PmcsPhase.before: [
      PmcsCategory(
        name: 'EXTERIOR / HULL',
        items: [
          PmcsCheckItem(
            id: 'B-EXT-01',
            item: 'Hull & Body Panels',
            check: 'Inspect hull for cracks, dents, holes, or battle damage',
            faults: [
              'No Damage',
              'Cracks Found',
              'Dents/Gouges',
              'Holes/Penetration',
              'Panels Missing',
            ],
          ),
          PmcsCheckItem(
            id: 'B-EXT-02',
            item: 'Doors & Hatches',
            check: 'All doors and hatches open, close, and latch properly',
            faults: [
              'Operational',
              'Stuck/Binding',
              'Latch Broken',
              'Seal Damaged',
              'Hinge Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'B-EXT-03',
            item: 'Ramp',
            check: 'Rear ramp operates and seals correctly',
            faults: [
              'Operational',
              'Hydraulic Leak',
              'Won\'t Open',
              'Won\'t Close',
              'Seal Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'B-EXT-04',
            item: 'Tow Bar & Shackles',
            check: 'Tow bar stowed, shackles present and secured',
            faults: [
              'Present/Secured',
              'Tow Bar Missing',
              'Shackle Missing',
              'Not Secured',
              'Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'B-EXT-05',
            item: 'Pioneer Tools',
            check: 'Ax, shovel, pickax present and secured',
            faults: [
              'All Present',
              'Ax Missing',
              'Shovel Missing',
              'Pickax Missing',
              'Not Secured',
            ],
          ),
          PmcsCheckItem(
            id: 'B-EXT-06',
            item: 'Fire Extinguishers',
            check: 'Inspect external fire extinguishers',
            faults: [
              'Serviceable',
              'Gauge in Red',
              'Pin Missing',
              'Extinguisher Missing',
              'Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'B-EXT-07',
            item: 'Antennas',
            check: 'All antennas installed and undamaged',
            faults: [
              'All Good',
              'Antenna Missing',
              'Antenna Bent',
              'Base Mount Loose',
              'Coax Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'B-EXT-08',
            item: 'Slat Armor / Cage',
            check: 'Slat armor panels secure and undamaged',
            faults: [
              'N/A or Good',
              'Panel Loose',
              'Panel Missing',
              'Bolts Missing',
              'Deformed',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'ENGINE COMPARTMENT',
        items: [
          PmcsCheckItem(
            id: 'B-ENG-01',
            item: 'Engine Oil Level',
            check: 'Check dipstick—oil between ADD and FULL',
            faults: [
              'Level OK',
              'Low—Add Oil',
              'Overfull',
              'Oil Contaminated',
              'Dipstick Missing',
            ],
          ),
          PmcsCheckItem(
            id: 'B-ENG-02',
            item: 'Coolant Level',
            check: 'Check coolant at FULL COLD mark',
            faults: [
              'Level OK',
              'Low—Add Coolant',
              'Coolant Discolored',
              'Reservoir Cracked',
              'Cap Missing/Bad',
            ],
          ),
          PmcsCheckItem(
            id: 'B-ENG-03',
            item: 'Drive Belts',
            check: 'Inspect belts for wear, cracks, fraying',
            faults: [
              'Good Condition',
              'Cracked',
              'Frayed',
              'Loose Tension',
              'Belt Missing',
            ],
          ),
          PmcsCheckItem(
            id: 'B-ENG-04',
            item: 'Radiator Hoses',
            check: 'Check hoses for leaks, bulging, cracks',
            faults: [
              'Good Condition',
              'Leaking',
              'Bulging',
              'Cracked',
              'Clamp Loose',
            ],
          ),
          PmcsCheckItem(
            id: 'B-ENG-05',
            item: 'Air Filter',
            check: 'Inspect air filter indicator and condition',
            faults: [
              'Serviceable',
              'Indicator Red',
              'Filter Dirty',
              'Housing Damaged',
              'Clamp Loose',
            ],
          ),
          PmcsCheckItem(
            id: 'B-ENG-06',
            item: 'Battery',
            check: 'Terminals clean, connections tight',
            faults: [
              'Good Condition',
              'Corrosion',
              'Loose Terminal',
              'Low Charge',
              'Cable Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'B-ENG-07',
            item: 'Fluid Leaks',
            check: 'Inspect under vehicle for any fluid leaks',
            faults: [
              'No Leaks',
              'Class I (Seep)',
              'Class II (Drip)',
              'Class III (Stream)',
              'Unknown Fluid',
            ],
          ),
          PmcsCheckItem(
            id: 'B-ENG-08',
            item: 'Transmission Fluid',
            check: 'Check transmission dipstick level',
            faults: [
              'Level OK',
              'Low',
              'Overfull',
              'Burnt Smell',
              'Contaminated',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'TIRES / WHEELS / CTIS',
        items: [
          PmcsCheckItem(
            id: 'B-TIR-01',
            item: 'Tire Pressure (All 8)',
            check: 'Verify CTIS display correct pressure',
            faults: [
              'All Normal',
              '1+ Low',
              '1+ Flat',
              'CTIS Inop',
              'Gauge Unreadable',
            ],
          ),
          PmcsCheckItem(
            id: 'B-TIR-02',
            item: 'Tire Condition',
            check: 'Inspect all 8 tires for cuts, bulges',
            faults: [
              'Good Condition',
              'Cut/Gash',
              'Bulge',
              'Low Tread',
              'Runflat Showing',
            ],
          ),
          PmcsCheckItem(
            id: 'B-TIR-03',
            item: 'Lug Bolts',
            check: 'All lug bolts present and torqued',
            faults: [
              'All Tight',
              'Bolt(s) Loose',
              'Bolt(s) Missing',
              'Studs Damaged',
              'Cross-Threaded',
            ],
          ),
          PmcsCheckItem(
            id: 'B-TIR-04',
            item: 'Runflat Inserts',
            check: 'Verify runflat inserts intact',
            faults: [
              'All Good',
              'Insert Cracked',
              'Insert Missing',
              'Cannot Verify',
              'Shifted',
            ],
          ),
          PmcsCheckItem(
            id: 'B-TIR-05',
            item: 'CTIS Lines',
            check: 'Check CTIS airline connections',
            faults: [
              'All Connected',
              'Line Disconnected',
              'Line Leaking',
              'Fitting Cracked',
              'Line Kinked',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'FUEL SYSTEM',
        items: [
          PmcsCheckItem(
            id: 'B-FUL-01',
            item: 'Fuel Level',
            check: 'Check fuel gauge',
            faults: [
              'Full',
              '3/4 Tank',
              '1/2 Tank',
              '1/4 Tank',
              'Gauge Inop',
            ],
          ),
          PmcsCheckItem(
            id: 'B-FUL-02',
            item: 'Fuel Cap',
            check: 'Fuel cap present and seals',
            faults: [
              'Sealed',
              'Cap Missing',
              'Seal Damaged',
              'Cap Cracked',
              'Won\'t Tighten',
            ],
          ),
          PmcsCheckItem(
            id: 'B-FUL-03',
            item: 'Fuel Lines',
            check: 'Visible fuel lines free of leaks',
            faults: [
              'No Issues',
              'Leak Detected',
              'Line Chafed',
              'Fitting Loose',
              'Line Kinked',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'BRAKES',
        items: [
          PmcsCheckItem(
            id: 'B-BRK-01',
            item: 'Brake Fluid',
            check: 'Reservoir between MIN and MAX',
            faults: [
              'Level OK',
              'Low',
              'Empty',
              'Fluid Dark',
              'Reservoir Cracked',
            ],
          ),
          PmcsCheckItem(
            id: 'B-BRK-02',
            item: 'Brake Lines',
            check: 'Inspect visible brake lines',
            faults: [
              'Good Condition',
              'Leak Detected',
              'Line Chafed',
              'Fitting Loose',
              'Line Kinked',
            ],
          ),
          PmcsCheckItem(
            id: 'B-BRK-03',
            item: 'Parking Brake',
            check: 'Parking brake engages and holds',
            faults: [
              'Holds Firm',
              'Slips',
              'Won\'t Engage',
              'Won\'t Release',
              'Cable Frayed',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'ELECTRICAL / LIGHTING',
        items: [
          PmcsCheckItem(
            id: 'B-ELC-01',
            item: 'Headlights (B/O & Full)',
            check: 'Blackout and service headlights',
            faults: [
              'All Operational',
              'BO Light Out',
              'Service Light Out',
              'Both Out',
              'Lens Cracked',
            ],
          ),
          PmcsCheckItem(
            id: 'B-ELC-02',
            item: 'Tail / Brake Lights',
            check: 'All rear and brake lights',
            faults: [
              'All Operational',
              'Tail Light Out',
              'Brake Light Out',
              'Both Out',
              'Lens Cracked',
            ],
          ),
          PmcsCheckItem(
            id: 'B-ELC-03',
            item: 'Turn Signals / Markers',
            check: 'Turn signals and side markers',
            faults: [
              'All Operational',
              'Left Signal Out',
              'Right Signal Out',
              'Markers Out',
              'Flasher Bad',
            ],
          ),
          PmcsCheckItem(
            id: 'B-ELC-04',
            item: 'Instrument Panel',
            check: 'All gauges and warning lights',
            faults: [
              'All Operational',
              'Gauge(s) Inop',
              'Warning Light Out',
              'Panel Dark',
              'Dimmer Broken',
            ],
          ),
          PmcsCheckItem(
            id: 'B-ELC-05',
            item: 'Horn',
            check: 'Horn operational',
            faults: [
              'Operational',
              'Inoperative',
              'Weak Sound',
              'Stuck On',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'WEAPONS / TURRET',
        items: [
          PmcsCheckItem(
            id: 'B-WPN-01',
            item: 'RWS / Weapon Mount',
            check: 'Mount secure and undamaged',
            faults: [
              'Secure',
              'Mount Loose',
              'Bolts Missing',
              'Damaged',
              'N/A',
            ],
          ),
          PmcsCheckItem(
            id: 'B-WPN-02',
            item: 'Turret Rotation',
            check: 'Traverses smoothly full range',
            faults: [
              'Smooth Operation',
              'Grinding',
              'Binding',
              'Limited Range',
              'Inoperative',
            ],
          ),
          PmcsCheckItem(
            id: 'B-WPN-03',
            item: 'Weapon Cradle',
            check: 'Weapon seats properly, pins secure',
            faults: [
              'Properly Seated',
              'Pin Missing',
              'Cradle Damaged',
              'Won\'t Lock',
              'N/A',
            ],
          ),
          PmcsCheckItem(
            id: 'B-WPN-04',
            item: 'Ammo Storage',
            check: 'Ammo cans secure, rack loaded per SOP',
            faults: [
              'Properly Stored',
              'Can Loose',
              'Can Missing',
              'Incorrect Load',
              'N/A',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'COMMUNICATIONS',
        items: [
          PmcsCheckItem(
            id: 'B-COM-01',
            item: 'SINCGARS Radio',
            check: 'Radio powers on, passes self-test',
            faults: [
              'Operational',
              'No Power',
              'Self-Test Fail',
              'Display Bad',
              'N/A',
            ],
          ),
          PmcsCheckItem(
            id: 'B-COM-02',
            item: 'BFT / JCR',
            check: 'BFT powers on and acquires GPS',
            faults: [
              'Operational',
              'No Power',
              'No GPS Lock',
              'Display Bad',
              'N/A',
            ],
          ),
          PmcsCheckItem(
            id: 'B-COM-03',
            item: 'Intercom System',
            check: 'Intercom clear at all crew stations',
            faults: [
              'All Clear',
              'Static',
              'Station Dead',
              'Intermittent',
              'Cable Bad',
            ],
          ),
          PmcsCheckItem(
            id: 'B-COM-04',
            item: 'Headsets / CVC',
            check: 'Crew headsets present and functional',
            faults: [
              'All Good',
              'Headset Missing',
              'Mic Dead',
              'Speaker Dead',
              'Cord Frayed',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'BII / SAFETY EQUIPMENT',
        items: [
          PmcsCheckItem(
            id: 'B-BII-01',
            item: 'First Aid Kit',
            check: 'First aid kit present and stocked',
            faults: [
              'Complete',
              'Kit Missing',
              'Items Missing',
              'Expired Items',
              'Case Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'B-BII-02',
            item: 'CLP & Rags',
            check: 'CLP lubricant and supplies present',
            faults: [
              'Present',
              'CLP Missing',
              'Rags Missing',
              'Low Supply',
              'N/A',
            ],
          ),
          PmcsCheckItem(
            id: 'B-BII-03',
            item: 'Vehicle Manual (TM)',
            check: 'TM present in vehicle',
            faults: [
              'Present',
              'Missing',
              'Damaged',
              'Incomplete',
            ],
          ),
          PmcsCheckItem(
            id: 'B-BII-04',
            item: 'DA Form 5988-E',
            check: 'Form present and current',
            faults: [
              'Present/Current',
              'Missing',
              'Outdated',
              'Incomplete',
            ],
          ),
        ],
      ),
    ],
    PmcsPhase.during: [
      PmcsCategory(
        name: 'ENGINE MONITORING',
        items: [
          PmcsCheckItem(
            id: 'D-ENG-01',
            item: 'Oil Pressure',
            check: 'Gauge reads 25-65 PSI',
            faults: [
              'Normal',
              'Low Pressure',
              'High Pressure',
              'Gauge Fluctuating',
              'Warning Light On',
            ],
          ),
          PmcsCheckItem(
            id: 'D-ENG-02',
            item: 'Engine Temperature',
            check: 'Temp gauge in normal range',
            faults: [
              'Normal Range',
              'Running Hot',
              'Overheating',
              'Running Cold',
              'Warning Light On',
            ],
          ),
          PmcsCheckItem(
            id: 'D-ENG-03',
            item: 'Engine Sounds',
            check: 'No unusual knocking, grinding',
            faults: [
              'Normal',
              'Knocking',
              'Grinding',
              'Whining',
              'Backfiring',
            ],
          ),
          PmcsCheckItem(
            id: 'D-ENG-04',
            item: 'Exhaust',
            check: 'Normal color, no excessive smoke',
            faults: [
              'Normal',
              'White Smoke',
              'Black Smoke',
              'Blue Smoke',
              'Excessive Volume',
            ],
          ),
          PmcsCheckItem(
            id: 'D-ENG-05',
            item: 'Transmission',
            check: 'Shifts smoothly, no slipping',
            faults: [
              'Shifting Normal',
              'Slipping',
              'Hard Shifts',
              'Won\'t Shift',
              'Grinding',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'DRIVING / HANDLING',
        items: [
          PmcsCheckItem(
            id: 'D-DRV-01',
            item: 'Steering',
            check: 'Responsive, no excessive play',
            faults: [
              'Normal',
              'Excessive Play',
              'Pulling Left',
              'Pulling Right',
              'Hard to Turn',
            ],
          ),
          PmcsCheckItem(
            id: 'D-DRV-02',
            item: 'Brakes',
            check: 'Respond normally, no pulling/fade',
            faults: [
              'Normal',
              'Pulling',
              'Fading',
              'Spongy Pedal',
              'Grinding Noise',
            ],
          ),
          PmcsCheckItem(
            id: 'D-DRV-03',
            item: 'Suspension',
            check: 'Normal ride, no bottoming out',
            faults: [
              'Normal',
              'Bottoming Out',
              'Listing Left',
              'Listing Right',
              'Excessive Bounce',
            ],
          ),
          PmcsCheckItem(
            id: 'D-DRV-04',
            item: 'CTIS Response',
            check: 'Adjusts pressure for terrain',
            faults: [
              'Responding',
              'Slow Response',
              'No Response',
              'Error Displayed',
              'Pressure Drops',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'ELECTRICAL / SYSTEMS',
        items: [
          PmcsCheckItem(
            id: 'D-ELC-01',
            item: 'Voltmeter',
            check: 'Charging system 26-28V',
            faults: [
              'Normal (26-28V)',
              'Low Voltage',
              'High Voltage',
              'Fluctuating',
              'Gauge Inop',
            ],
          ),
          PmcsCheckItem(
            id: 'D-ELC-02',
            item: 'Warning Indicators',
            check: 'No unexpected warning lights',
            faults: [
              'All Clear',
              'Engine Warning',
              'Brake Warning',
              'Battery Warning',
              'Multiple Warnings',
            ],
          ),
          PmcsCheckItem(
            id: 'D-ELC-03',
            item: 'NBC System',
            check: 'NBC overpressure operational',
            faults: [
              'Operational',
              'Low Pressure',
              'Filter Alarm',
              'Inoperative',
              'N/A',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'COMMS / SITUATIONAL',
        items: [
          PmcsCheckItem(
            id: 'D-COM-01',
            item: 'Radio Comms',
            check: 'Maintaining radio contact',
            faults: [
              'Clear Comms',
              'Static/Broken',
              'Lost Contact',
              'Intermittent',
              'TX Only/RX Only',
            ],
          ),
          PmcsCheckItem(
            id: 'D-COM-02',
            item: 'BFT Tracking',
            check: 'Showing current position',
            faults: [
              'Tracking Normal',
              'Position Stale',
              'No Updates',
              'Wrong Position',
              'System Down',
            ],
          ),
          PmcsCheckItem(
            id: 'D-COM-03',
            item: 'Intercom',
            check: 'Crew intercom remains clear',
            faults: [
              'Clear',
              'Static Developed',
              'Crew Station Out',
              'Intermittent',
              'Feedback/Echo',
            ],
          ),
        ],
      ),
    ],
    PmcsPhase.after: [
      PmcsCategory(
        name: 'COOL-DOWN INSPECTION',
        items: [
          PmcsCheckItem(
            id: 'A-CDN-01',
            item: 'Engine Cool-Down',
            check: 'Idle 3-5 min; listen for anomalies',
            faults: [
              'Normal Shutdown',
              'Unusual Noise',
              'Smoke Observed',
              'Leak Developed',
              'Temp Stayed High',
            ],
          ),
          PmcsCheckItem(
            id: 'A-CDN-02',
            item: 'Fluid Leaks',
            check: 'Check under vehicle for new leaks',
            faults: [
              'No New Leaks',
              'Oil Leak',
              'Coolant Leak',
              'Fuel Leak',
              'Hydraulic Leak',
            ],
          ),
          PmcsCheckItem(
            id: 'A-CDN-03',
            item: 'Battle Damage',
            check: 'Inspect for damage from operations',
            faults: [
              'No Damage',
              'Minor Damage',
              'Major Damage',
              'Damage Logged',
              'Requires Evac',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'TIRES & RUNNING GEAR',
        items: [
          PmcsCheckItem(
            id: 'A-TIR-01',
            item: 'Tire Condition',
            check: 'Re-inspect all 8 tires',
            faults: [
              'All Good',
              'Flat Tire',
              'Low Tire',
              'Cut/Damage',
              'Debris Embedded',
            ],
          ),
          PmcsCheckItem(
            id: 'A-TIR-02',
            item: 'Wheel Hubs',
            check: 'Feel hubs for excessive heat',
            faults: [
              'Normal Temp',
              'Hot—Left Front',
              'Hot—Right Front',
              'Hot—Left Rear',
              'Hot—Right Rear',
            ],
          ),
          PmcsCheckItem(
            id: 'A-TIR-03',
            item: 'Drive Shafts',
            check: 'Inspect for damage or loose fittings',
            faults: [
              'Good Condition',
              'Loose Fitting',
              'Damaged',
              'Missing Guard',
              'Vibration Noted',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'WEAPONS & AMMO',
        items: [
          PmcsCheckItem(
            id: 'A-WPN-01',
            item: 'Weapon Cleared',
            check: 'Cleared and safed per SOP',
            faults: [
              'Cleared/Safed',
              'Malfunction—See NCO',
              'Ammo Jam',
              'Round Stuck',
              'N/A',
            ],
          ),
          PmcsCheckItem(
            id: 'A-WPN-02',
            item: 'Ammo Count',
            check: 'Reconcile ammunition',
            faults: [
              'Count Matches',
              'Discrepancy Found',
              'Rounds Missing',
              'Count Complete',
              'N/A',
            ],
          ),
          PmcsCheckItem(
            id: 'A-WPN-03',
            item: 'Weapon Cleaned',
            check: 'Wiped down / cleaned per SOP',
            faults: [
              'Cleaned',
              'Needs Cleaning',
              'CLP Applied',
              'Deferred to Maint',
              'N/A',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'FLUIDS & LEVELS',
        items: [
          PmcsCheckItem(
            id: 'A-FLD-01',
            item: 'Engine Oil',
            check: 'Recheck oil after cool-down',
            faults: [
              'Level OK',
              'Low—Topped Off',
              'Low—Needs Oil',
              'Overfull',
              'Oil Very Dark',
            ],
          ),
          PmcsCheckItem(
            id: 'A-FLD-02',
            item: 'Coolant',
            check: 'Recheck coolant at FULL COLD',
            faults: [
              'Level OK',
              'Low—Topped Off',
              'Low—Needs Coolant',
              'Discolored',
              'Contaminated',
            ],
          ),
          PmcsCheckItem(
            id: 'A-FLD-03',
            item: 'Fuel Level',
            check: 'Note fuel remaining',
            faults: [
              'Full',
              '3/4 Tank',
              '1/2 Tank',
              '1/4 Tank',
              'Near Empty',
            ],
          ),
          PmcsCheckItem(
            id: 'A-FLD-04',
            item: 'Hydraulic Fluid',
            check: 'Check hydraulic reservoir',
            faults: [
              'Level OK',
              'Low',
              'Very Low',
              'Contaminated',
              'Reservoir Damage',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'COMMS & ELECTRONICS',
        items: [
          PmcsCheckItem(
            id: 'A-COM-01',
            item: 'Radios Secured',
            check: 'Radios per SOP/OPORD',
            faults: [
              'Secured/Set',
              'Won\'t Power Down',
              'Left On Per Order',
              'Freq Reset Needed',
              'N/A',
            ],
          ),
          PmcsCheckItem(
            id: 'A-COM-02',
            item: 'BFT Status',
            check: 'BFT correct mode',
            faults: [
              'Set Correctly',
              'Mode Incorrect',
              'System Error',
              'GPS Lost',
              'N/A',
            ],
          ),
          PmcsCheckItem(
            id: 'A-COM-03',
            item: 'EPLRS/Crypto',
            check: 'Crypto fill current',
            faults: [
              'Current/Good',
              'Crypto Expired',
              'EPLRS Down',
              'Zeroize Needed',
              'N/A',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'DOCUMENTATION',
        items: [
          PmcsCheckItem(
            id: 'A-DOC-01',
            item: '5988-E Updated',
            check: 'All faults recorded',
            faults: [
              'Updated',
              'Needs Updating',
              'Form Missing',
              'N/A',
            ],
          ),
          PmcsCheckItem(
            id: 'A-DOC-02',
            item: 'Mileage Logged',
            check: 'Record odometer',
            faults: [
              'Logged',
              'Odometer Inop',
              'Needs Logging',
            ],
          ),
          PmcsCheckItem(
            id: 'A-DOC-03',
            item: 'Reported to NCO',
            check: 'RED X faults reported',
            faults: [
              'Reported',
              'Awaiting NCO',
              'No Faults to Report',
              'NCO Notified',
            ],
          ),
        ],
      ),
    ],
  },
);
