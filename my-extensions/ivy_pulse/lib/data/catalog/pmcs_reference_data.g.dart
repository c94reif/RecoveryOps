// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Unit, parts, and dispatch reference data used by the PMCS flow.
// Regenerate with tool/generate_catalog.sh after editing the TM source data.

import 'package:ivy_pulse/domain/entities/fault_severity.dart';
import 'package:ivy_pulse/domain/entities/reference/common_part.dart';
import 'package:ivy_pulse/domain/entities/reference/mission.dart';
import 'package:ivy_pulse/domain/entities/reference/priority_designator.dart';

/// Actions a maintainer can record against a corrected fault.
const List<String> correctiveActions = [
  'Repaired On-Site',
  'Adjusted / Tightened',
  'Replaced Component',
  'Topped Off Fluid',
  'Parts On Order',
  'Requires Higher Echelon',
  'Deadlined — NMC',
  'Deferred (Low Priority)',
  'No Action Required',
  'Operator Error — Retrained',
];

/// Enlisted, warrant, and officer ranks, in order of precedence.
const List<String> ranks = [
  'PVT',
  'PV2',
  'PFC',
  'SPC',
  'CPL',
  'SGT',
  'SSG',
  'SFC',
  'MSG',
  '1SG',
  'SGM',
  '2LT',
  '1LT',
  'CPT',
  'MAJ',
  'LTC',
  'COL',
  'BG',
  'MG',
  'WO1',
  'CW2',
  'CW3',
  'CW4',
  'CW5',
];

/// Dispatch profiles and how many days each is normally good for.
const List<Mission> missions = [
  Mission(
    type: 'Convoy',
    days: 3,
    description: 'Logistics movement, 1-3 days',
  ),
  Mission(
    type: 'Training Exercise',
    days: 14,
    description: 'Field training, up to 14 days',
  ),
  Mission(
    type: 'Combat Patrol',
    days: 7,
    description: 'Patrol operations, up to 7 days',
  ),
  Mission(
    type: 'Admin / Motor Pool',
    days: 1,
    description: 'Garrison admin movement, 1 day',
  ),
  Mission(
    type: 'Gunnery',
    days: 7,
    description: 'Range / gunnery qualification, up to 7 days',
  ),
  Mission(
    type: 'JRTC / NTC Rotation',
    days: 30,
    description: 'CTC rotation, up to 30 days',
  ),
];

/// Frequently demanded parts, for one-tap ordering against a fault.
const List<CommonPart> commonParts = [
  CommonPart(nsn: '2530-01-562-1743', name: 'Tire, Pneumatic (Stryker)'),
  CommonPart(nsn: '2530-01-529-2264', name: 'Runflat Insert'),
  CommonPart(nsn: '4710-01-534-7583', name: 'Radiator Hose, Upper'),
  CommonPart(nsn: '4710-01-534-7584', name: 'Radiator Hose, Lower'),
  CommonPart(nsn: '2940-01-533-8105', name: 'Air Filter Element'),
  CommonPart(nsn: '6140-01-485-1472', name: 'Battery, 6T'),
  CommonPart(nsn: '3040-01-534-2789', name: 'Drive Belt, Serpentine'),
  CommonPart(nsn: '4210-01-530-5411', name: 'Fire Extinguisher, 5lb'),
  CommonPart(nsn: '6220-01-534-1156', name: 'Headlight Assembly, BO'),
  CommonPart(nsn: '6220-01-534-1157', name: 'Tail Light Assembly'),
  CommonPart(nsn: '2520-01-534-6742', name: 'Brake Pad Set'),
  CommonPart(nsn: '2520-01-534-6743', name: 'Brake Fluid, DOT 5'),
  CommonPart(nsn: '9150-01-197-7688', name: 'Engine Oil, 15W-40'),
  CommonPart(nsn: '9150-01-534-7712', name: 'Coolant, ELC'),
  CommonPart(nsn: '9150-01-534-7713', name: 'Transmission Fluid'),
  CommonPart(nsn: '5340-01-534-8901', name: 'Antenna, AS-3900'),
  CommonPart(nsn: '5820-01-534-8902', name: 'Handset, H-250'),
  CommonPart(nsn: '2510-01-534-6744', name: 'CTIS Airline Kit'),
  CommonPart(nsn: '5330-01-534-7777', name: 'Seal Kit, Ramp Hydraulic'),
  CommonPart(nsn: '9150-01-053-6607', name: 'CLP (Weapon Lubricant)'),
];

/// Requisition priority designators, most urgent first.
const List<PriorityDesignator> priorityDesignators = [
  PriorityDesignator(code: '02', label: 'NMCS (Not Mission Capable Supply)'),
  PriorityDesignator(code: '03', label: 'PMCS Priority'),
  PriorityDesignator(code: '06', label: 'Initial Issue'),
  PriorityDesignator(code: '09', label: 'Routine'),
];

/// Fault status symbols an operator or maintainer can assign.
const List<FaultSeverity> severityOptions = [
  FaultSeverity.redX,
  FaultSeverity.circleX,
  FaultSeverity.dash,
];
