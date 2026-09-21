// GENERATED FILE — DO NOT EDIT BY HAND.
//
// JLTV PMCS checks transcribed from TM 9-2320-400-10 PMCS tables.
// Regenerate with tool/generate_catalog.sh after editing the TM source data.

import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';
import 'package:ivy_pulse/domain/entities/pmcs_category.dart';
import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';
import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';
import 'package:ivy_pulse/domain/entities/vehicle_type.dart';

/// JLTV PMCS catalog — 94 TM checks across before, during, and
/// after operations.
///
/// Item ids carrying the `CRIT` marker have a "Not Mission Capable If"
/// condition in the TM and are graded as critical systems by the classifier.
const PmcsCatalog jltvPmcsCatalog = PmcsCatalog(
  vehicleType: VehicleType.jltv,
  phases: {
    PmcsPhase.before: [
      PmcsCategory(
        name: 'DRIVER SIDE FRONT',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-B01',
            item: 'Wheel/Tire',
            check:
                'Inspect tire for flat conditions, cuts, gouges, cracks, bulging or other damage. Inspect wheel for broken, cracked, or bent surfaces. Visually check if tire tread wear is approaching the tire wear bar. Inspect CTIS valve for leaks.',
            faults: [
              'Serviceable',
              'Minor Cosmetic Damage',
              'Cut/Gouge/Bulge Present',
              'Ply/Belt Exposed or Audible Leak',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B02',
            item: 'Fluid Leaks',
            check:
                'Inspect driver side front for obvious damage and evidence of leaks.',
            faults: [
              'No Leaks',
              'Class I Seep',
              'Class II Drip',
              'Class III Brake/Fuel Leak Present',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B03',
            item: 'Splash Guard',
            check: 'Inspect splash guard for cracks and obvious damage.',
            faults: [
              'Serviceable',
              'Minor Crack',
              'Significant Crack',
              'Missing or Severely Damaged',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'DRIVER SIDE',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-B04',
            item: 'Doors and Ballistic Glass',
            check:
                'Check front and rear doors, door latches, weldments, combat locks, and hinges for improper operation, binding, and damage. Check ballistic glass for delamination, broken exterior glass, excessive scratches, or large, deep cracks.',
            faults: [
              'Serviceable',
              'Minor Scratch/Scuff',
              'Latch/Hinge Binding',
              'Delamination Impairing Vision or Prevents Operation',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'DRIVER SIDE REAR',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-B05',
            item: 'Wheel/Tire',
            check:
                'Inspect tire for flat conditions, cuts, gouges, cracks, bulging or other damage. Inspect wheel for broken, cracked, or bent surfaces. Visually check if tire tread wear is approaching tire wear bar. Inspect CTIS valve for leaks.',
            faults: [
              'Serviceable',
              'Minor Cosmetic Damage',
              'Cut/Gouge/Bulge Present',
              'Ply/Belt Exposed or Audible Leak',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B06',
            item: 'Splash Guard',
            check: 'Inspect splash guard for cracks and obvious damage.',
            faults: [
              'Serviceable',
              'Minor Crack',
              'Significant Crack',
              'Missing or Severely Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B07',
            item: 'Fluid Leaks',
            check:
                'Inspect driver side rear for obvious damage and evidence of leaks.',
            faults: [
              'No Leaks',
              'Class I Seep',
              'Class II Drip',
              'Class III Brake/Fuel Leak Present',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'REAR OF VEHICLE',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-B08',
            item: 'Gladhands (Rear)',
            check:
                'Check rear gladhand couplers and grommets for damage or missing gladhand covers.',
            faults: [
              'Serviceable',
              'Minor Damage',
              'Grommet Worn',
              'Covers Missing',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B09',
            item: 'Fuel Priming Pump (if installed)',
            check:
                'Check fuel priming pump for proper operation, leaks, or damage.',
            faults: [
              'Serviceable',
              'Minor Damage',
              'Leaking (Minor)',
              'Fuel Leak Present',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B10',
            item: 'Rear Camera Lens (M1278/M1280/M1281)',
            check:
                'Inspect for broken, scratched, or dirty camera lens glass. Applies to M1278, M1280, M1281 variants.',
            faults: [
              'Clear/Serviceable',
              'Dirty (Cleanable)',
              'Scratched',
              'Broken or Severely Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B11',
            item: 'Rear Camera (M1279)',
            check:
                'Inspect for broken, scratched, or dirty camera lens glass. Applies to M1279 variant.',
            faults: [
              'Clear/Serviceable',
              'Dirty (Cleanable)',
              'Scratched',
              'Broken or Severely Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B12',
            item: 'Pintle Hook',
            check:
                'Inspect pintle hook for secure mounting, cracks, damage, and proper operation. Ensure safety latch engages and safety pin is secured and functional.',
            faults: [
              'Serviceable',
              'Minor Cosmetic Damage',
              'Latch Stiff/Difficult',
              'Safety Latch Won\'t Engage or Pin Missing',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B13',
            item: 'Tailgate (M1279)',
            check:
                'Check tailgate for proper operation. Applies to M1279 variant.',
            faults: [
              'Operational',
              'Stiff/Hard to Open',
              'Latch Issues',
              'Inoperable',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B14',
            item: 'Drain Valves and Control Manifold',
            check:
                'Inspect drain valves for obvious damage. Ensure eight solenoid screws are positioned fully counterclockwise.',
            faults: [
              'Serviceable',
              'Minor Damage',
              'Solenoid Stiff/Difficult',
              'Valve Damaged or L2/L3/R4 Solenoid Won\'t Rotate',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'PASSENGER SIDE REAR',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-B15',
            item: 'Wheel/Tire',
            check:
                'Inspect tire for flat conditions, cuts, gouges, cracks, bulging or other damage. Inspect wheel for broken, cracked, or bent surfaces. Visually check if tire tread wear is approaching the tire wear bar. Inspect CTIS valve for leaks.',
            faults: [
              'Serviceable',
              'Minor Cosmetic Damage',
              'Cut/Gouge/Bulge Present',
              'Ply/Belt Exposed or Audible Leak',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B16',
            item: 'Fluid Leaks',
            check:
                'Inspect passenger side rear for obvious damage and evidence of leaks.',
            faults: [
              'No Leaks',
              'Class I Seep',
              'Class II Drip',
              'Class III Brake/Fuel Leak Present',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B17',
            item: 'Splash Guard',
            check: 'Inspect splash guard for cracks and obvious damage.',
            faults: [
              'Serviceable',
              'Minor Crack',
              'Significant Crack',
              'Missing or Severely Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B18',
            item: 'Brake Reservoirs',
            check:
                'Inspect two service brake reservoirs and one park brake reservoir for damage and leaks. Ensure brake fluid is between FILL and LOW lines.',
            faults: [
              'Level OK (Between FILL/LOW)',
              'Fluid Low — Add',
              'Fluid Very Low',
              'Brake Fluid Leak Present',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'PASSENGER SIDE',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-B19',
            item: 'Doors and Ballistic Glass',
            check:
                'Check front and rear doors, door latches, weldments, combat locks, and hinges for improper operation, binding, and damage. Check ballistic glass for delamination, broken exterior glass, excessive scratches, or large, deep cracks.',
            faults: [
              'Serviceable',
              'Minor Scratch/Scuff',
              'Latch/Hinge Binding',
              'Delamination Impairing Vision or Prevents Operation',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B20',
            item: 'Muffler',
            check:
                'Inspect muffler, clamps, and pipes for looseness, leaks, or damage.',
            faults: [
              'Serviceable',
              'Minor Damage',
              'Loose/Rattling',
              'Damage Impedes Operation',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'PASSENGER SIDE FRONT',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-B21',
            item: 'Wheel/Tire',
            check:
                'Inspect tire for flat conditions, cuts, gouges, cracks, bulging or other damage. Inspect wheel for broken, cracked, or bent surfaces. Visually check if tire tread wear is approaching tire wear bar. Inspect CTIS valve for leaks.',
            faults: [
              'Serviceable',
              'Minor Cosmetic Damage',
              'Cut/Gouge/Bulge Present',
              'Ply/Belt Exposed or Audible Leak',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B22',
            item: 'Fluid Leaks',
            check:
                'Inspect passenger side front for obvious damage and evidence of leaks.',
            faults: [
              'No Leaks',
              'Class I Seep',
              'Class II Drip',
              'Class III Brake/Fuel Leak Present',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B23',
            item: 'Splash Guard',
            check: 'Inspect splash guard for cracks and obvious damage.',
            faults: [
              'Serviceable',
              'Minor Crack',
              'Significant Crack',
              'Missing or Severely Damaged',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'FRONT OF VEHICLE',
        items: [
          PmcsCheckItem(
            id: 'JLTV-B24',
            item: 'Front Facing Camera Lens',
            check: 'Inspect for broken, scratched, or dirty camera lens glass.',
            faults: [
              'Clear/Serviceable',
              'Dirty (Cleanable)',
              'Scratched',
              'Broken or Severely Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B25',
            item: 'Gladhands (Front)',
            check:
                'Inspect front gladhand couplers and grommets for damage or missing gladhand plugs.',
            faults: [
              'Serviceable',
              'Minor Damage',
              'Grommet Worn',
              'Plug Missing',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B26',
            item: 'Windshield',
            check:
                'Inspect driver and passenger windshield ballistic glass for delamination, broken exterior glass, excessive scratches, or large, deep cracks.',
            faults: [
              'Serviceable',
              'Minor Scratch',
              'Crack (Non-Vision Impairing)',
              'Delamination Impairing Vision or Cracked/Broken',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'ENGINE COMPARTMENT',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-B27',
            item: 'Engine Fluid Leaks (Passenger Side)',
            check:
                'Inspect passenger side for obvious damage and evidence of leaks.',
            faults: [
              'No Leaks',
              'Class I Seep',
              'Class II Drip',
              'Class III Brake/Fuel Leak Present',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B28',
            item: 'Hood and Latch (Driver Side)',
            check:
                'Inspect hood for cracks and obvious damage. Check hood latch for improper operation and damage.',
            faults: [
              'Serviceable',
              'Minor Cosmetic Damage',
              'Latch Stiff/Difficult',
              'Cracks/Damage Prevents Proper Operation',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B29',
            item: 'Hood and Latch (Passenger Side)',
            check:
                'Inspect hood for cracks and obvious damage. Check hood latch for improper operation and damage.',
            faults: [
              'Serviceable',
              'Minor Cosmetic Damage',
              'Latch Stiff/Difficult',
              'Cracks/Severely Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B30',
            item: 'Flat Tow Valve',
            check:
                'Raise and support hood. Ensure flat tow valve is in CLOSED (NORMAL) position.',
            faults: [
              'Closed/Normal',
              'Position Uncertain',
              'Hard to Verify',
              'In Open/Towing Position',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B31',
            item: 'Air Cleaner',
            check:
                'Inspect air cleaner for obvious damage, loose, or missing hardware.',
            faults: [
              'Serviceable',
              'Loose Hardware',
              'Minor Damage',
              'Missing or Damage Prevents Operation',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B32',
            item: 'Driver Side Brake Reservoir',
            check:
                'Inspect brake reservoir for obvious damage, leaks, and ensure fluid is between FILL and LOW lines.',
            faults: [
              'Level OK (Between FILL/LOW)',
              'Fluid Low — Add',
              'Fluid Very Low',
              'Brake Fluid Leak Present',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B33',
            item: 'Passenger Side Front Brake Reservoir',
            check:
                'Inspect brake reservoir for obvious damage, leaks, and ensure fluid is between FILL and LOW lines.',
            faults: [
              'Level OK (Between FILL/LOW)',
              'Fluid Low — Add',
              'Fluid Very Low',
              'Brake Fluid Leak Present',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B34',
            item: 'Transmission Fluid',
            check:
                'Inspect transmission dipstick and ensure fluid level is within COLD range.',
            faults: [
              'Within COLD Range',
              'Slightly Low',
              'Below COLD Range',
              'Significantly Out of Range',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B35',
            item: 'Fluid Leaks (Engine Compartment)',
            check:
                'Inspect engine compartment for obvious damage and evidence of leaks.',
            faults: [
              'No Leaks',
              'Class I Seep',
              'Class II Drip',
              'Class III Brake/Fuel Leak Present',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B36',
            item: 'Cooling System',
            check:
                'Inspect radiator, transmission oil cooler, clamps, tubes, and hoses for leaks, cuts, loose clamps, debris, and damage.',
            faults: [
              'Serviceable',
              'Minor Wear/Loose Clamp',
              'Debris Accumulation',
              'Class III Trans Oil Cooler Leak or Damage Prevents Operation',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B37',
            item: 'Accessory Drive/Belts',
            check:
                'Inspect that belts are present and check for cracking, fraying, glazing, and other damage.',
            faults: [
              'Serviceable',
              'Minor Glazing/Wear',
              'Cracked/Fraying',
              'Belt Missing or Severely Damaged',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'CREW COMPARTMENT',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-B38',
            item: 'Mirrors',
            check: 'Check mirrors for proper operation and damage.',
            faults: [
              'All Operational',
              'Adjustment Loose',
              'Cracked (Non-Impairing)',
              'Mirror Missing, Inoperable, or Impairs Vision',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B39',
            item: 'Horn',
            check:
                'Turn VEH BAT switch ON. Push horn button to verify horn is working properly.',
            faults: [
              'Operational',
              'Intermittent',
              'Weak Sound',
              'Inoperable',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B40',
            item: 'Cab AFES',
            check:
                'Inspect optical sensors for position and obstructions. Turn ignition switch ON and inspect AFES control panel POWER LED for solid illumination and FAULT LED is off. Inspect pressure gauge on extinguisher cylinder.',
            faults: [
              'Serviceable',
              'Sensor Obstructed (Clearable)',
              'Gauge Not in Green',
              'POWER LED Not Solid, FAULT LED Active, or Cylinder Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B41',
            item: 'Fire Extinguisher',
            check:
                'Inspect fire extinguisher for proper charge, damage, or broken/missing seal. Check for replacement date.',
            faults: [
              'Serviceable',
              'Seal Broken',
              'Not Properly Charged',
              'Missing, Out of Date, or Inoperable',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B42',
            item: 'Seat Belts and Seats',
            check:
                'Check seat belts and buckles for proper operation. Check seats for proper operation.',
            faults: [
              'Serviceable',
              'Worn/Frayed (Minor)',
              'Buckle Stiff/Difficult',
              'Damaged or Inoperable Seat Belt',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B43',
            item: 'Vehicle Systems (DSDU)',
            check:
                'Start Driver Smart Display Unit (DSDU) and check for proper operation. Check main instrument panel and DSDU SYSTEM CHECKS screen for any red warning indicators. Check fuel level. Check CSDU and ASDU (if installed). Check TOW Missile Safe Fire Condition (M1281 only).',
            faults: [
              'All Systems Normal',
              'Amber Warning Indicator',
              'Red Warning Indicator',
              'DSDU Inoperative or Multiple Red Warnings',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B44',
            item: 'Starter',
            check:
                'Start engine and listen for slow cranking operation or unusual noises.',
            faults: [
              'Normal Crank',
              'Slightly Slow Crank',
              'Slow Crank with Noise',
              'Fails to Crank or Unusual Noise',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B45',
            item: 'HVAC System',
            check:
                'Inspect HVAC controls for proper operation in all settings. Inspect rear fan control for proper operation (M1278, M1280, M1281 only).',
            faults: [
              'Fully Operational',
              'Reduced Effectiveness',
              'Partial Function',
              'A/C Inoperable or Rear Fan Inoperable',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B46',
            item: 'Intercom (if installed)',
            check: 'Check intercom system for proper operation.',
            faults: [
              'Operational',
              'Intermittent',
              'One Position Inoperable',
              'System Inoperable',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B47',
            item: 'Windshield Wiper/Washer',
            check: 'Check windshield wiper/washer system for proper operation.',
            faults: [
              'Operational',
              'Washer Only Inoperable',
              'Wiper Smearing/Degraded',
              'Wiper Arms or Blades Missing',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B48',
            item: 'Parking Brake',
            check:
                'With parking brake applied, shift to D (drive) and run engine to 1,000 RPM. Vehicle should not move.',
            faults: [
              'Holds Firm',
              'Slips Slightly',
              'Questionable Hold',
              'Vehicle Moves with Brake Applied',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B49',
            item: 'Service Brakes',
            check:
                'With service brake applied and parking brake released, shift to D (drive) and run engine to 1,000 RPM. Vehicle should not move.',
            faults: [
              'Holds Firm',
              'Slips Slightly',
              'Questionable Hold',
              'Vehicle Moves with Brake Applied',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B50',
            item: 'Lights',
            check:
                'Inspect all service lights, marker lights, headlights, blackout lights, turn signals, hazard lights, and brake lights for proper function and damage.',
            faults: [
              'All Operational',
              '1 Light Out',
              'Multiple Lights Out',
              'No Service Lights/Severely Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-B51',
            item: 'Reverse Light',
            check:
                'With brakes applied, shift to R (reverse) and inspect reverse light for illumination.',
            faults: [
              'Illuminates',
              'Dim',
              'Intermittent',
              'Does Not Illuminate',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B52',
            item: 'Turret Gunner Restraint System — TGRS (M1278/M1281)',
            check:
                'Inspect TGRS harness, retractor belt, barrel nut, and emergency relief swivel. Check for proper operation.',
            faults: [
              'Serviceable',
              'Minor Wear/Adjustment Needed',
              'Retractor Issue or Barrel Nut Loose',
              'Frayed/Broken Straps or TGRS Not Present',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B53',
            item: 'Egress Hatch',
            check: 'Inspect that egress hatch operates properly.',
            faults: [
              'Operational',
              'Stiff/Difficult',
              'Partially Operable',
              'Does Not Operate Properly',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B54',
            item: 'Blast Mats',
            check: 'Inspect blast mats.',
            faults: [
              'Serviceable',
              'Minor Wear',
              'Rivets Loose',
              'Missing, Cracked, or Severely Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-B55',
            item: 'B-Kit Seat Blast Cushion Inserts',
            check: 'Inspect seat blast cushion inserts.',
            faults: [
              'Serviceable',
              'Minor Wear',
              'Rivets Loose',
              'Missing, Cracked, or Severely Damaged',
            ],
          ),
        ],
      ),
    ],
    PmcsPhase.during: [
      PmcsCategory(
        name: 'DURING OPERATIONS',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-D01',
            item: 'Air System',
            check:
                'Monitor air pressure gauges to ensure a reading between 110 and 130 psi. Listen for audible air leaks.',
            faults: [
              'Normal (110–130 PSI)',
              'Slightly Low Pressure',
              'Pressure Drop Detected',
              'Low Air Light Illuminated or Audible Leak',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-D02',
            item: 'Gauges',
            check:
                'Monitor oil pressure, tachometer, water temperature, transmission fluid temperature, fuel gauge, voltage, speedometer, and low oil level indicator for normal operation. Monitor DSDU for air restriction level.',
            faults: [
              'All Normal',
              'Gauge Reading Marginal',
              'Amber Warning Illuminated',
              'Red Warning Illuminated or Loss of Power',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-D03',
            item: 'Engine',
            check:
                'Monitor engine for excessive smoke, rough running, excessive vibration, unusual noises, or misfiring. Pay attention for unusual noises and exhaust odors in the cab.',
            faults: [
              'Running Normally',
              'Minor Vibration',
              'Excessive Smoke/Vibration',
              'Rough Running, Unusual Noise, or Misfiring',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-D04',
            item: 'Transmission',
            check:
                'Monitor and ensure transmission shifts smoothly through gears and does not slip.',
            faults: [
              'Shifts Smoothly',
              'Slight Hesitation',
              'Rough Shifting',
              'Slipping or Won\'t Shift Out of Gear',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-D05',
            item: 'Brakes',
            check:
                'Monitor brakes for pulling, binding, or grabbing. Engage exhaust brake to ensure proper operation.',
            faults: [
              'Normal',
              'Slight Pull',
              'Noticeable Pull/Binding',
              'Pulling or Grabbing',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-D06',
            item: 'Steering',
            check:
                'Monitor steering for difficulty turning, excessive free play, binding, and shimmying.',
            faults: [
              'Normal',
              'Slight Free Play',
              'Binding/Shimmy',
              'Excessive Free Play or Difficulty Turning',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-D07',
            item: 'Accelerator Pedal',
            check:
                'Monitor for sticking, constant throttle control, or binding pedal.',
            faults: [
              'Normal',
              'Slightly Stiff',
              'Sticky/Hesitant',
              'Sticking or Binding',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-D08',
            item: 'Powertrain',
            check:
                'Monitor engine, transmission, differentials, propeller shafts, halfshafts, transaxles, and wheels for unusual noise or vibration.',
            faults: [
              'No Issues',
              'Minor Vibration',
              'Unusual Noise Developing',
              'Unusual Noise or Vibration Detected',
            ],
          ),
        ],
      ),
    ],
    PmcsPhase.after: [
      PmcsCategory(
        name: 'DRIVER SIDE FRONT',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-A01',
            item: 'Wheel/Tire',
            check: 'Re-inspect for any new damage sustained during operation.',
            faults: [
              'Serviceable',
              'Minor New Damage',
              'Cut/Gouge/New Damage',
              'Ply/Belt Exposed or Audible Leak',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A02',
            item: 'Vehicle Checks (Steering/Brakes/Halfshafts)',
            check:
                'Inspect steering components for damage, looseness, leaks. Inspect brake hose protectors for abrasion. Inspect halfshaft boots and ball joint boots for leaks, rips, tears.',
            faults: [
              'Serviceable',
              'Minor Wear',
              'Abrasion/Boot Wear',
              'Boot Torn or Damage Prevents Operation',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A03',
            item: 'Wheel Deflector and Belly Armor',
            check:
                'Inspect area between belly armor and propeller shaft for debris. Inspect wheel deflector for missing components or damage.',
            faults: [
              'Serviceable',
              'Minor Damage',
              'Missing Components',
              'Debris Contacting Propeller Shaft',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-A04',
            item: 'Steering Shaft Boot',
            check: 'Inspect boot for tears and obvious damage.',
            faults: [
              'Serviceable',
              'Minor Wear',
              'Cracked',
              'Torn or Severely Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A05',
            item: 'Suspension Inspection',
            check: 'Inspect springs and shocks for leaks and obvious damage.',
            faults: [
              'Serviceable',
              'Minor Wear',
              'Seeping/Minor Damage',
              'Leak Present or Spring Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A06',
            item: 'Shock Absorber and Spring Caps',
            check:
                'Inspect shock absorber cap and spring cap for cracks, tears, or if missing.',
            faults: [
              'Serviceable',
              'Minor Crack/Wear',
              'Cracked/Torn',
              'Missing or Prevents Operation',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A07',
            item: 'Suspension Cross Plumbing Hoses',
            check:
                'Inspect hoses for blisters, tears, and exposed metal braids.',
            faults: [
              'Serviceable',
              'Minor Blister',
              'Tear Developing',
              'Metal Braids Exposed or Class III Leak',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A08',
            item: 'Jounce Bumper',
            check: 'Inspect jounce bumper for gouges, cracks, or if missing.',
            faults: [
              'Serviceable',
              'Minor Gouge',
              'Cracked',
              'Missing or Prevents Operation',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-A09',
            item: 'Splash Guard',
            check: 'Inspect splash guard for cracks and obvious damage.',
            faults: [
              'Serviceable',
              'Minor Crack',
              'Significant Crack',
              'Missing or Severely Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A10',
            item: 'Fluid Leaks',
            check:
                'Inspect driver side front for obvious damage and evidence of new leaks.',
            faults: [
              'No New Leaks',
              'Class I Seep',
              'Class II Drip',
              'Class III Brake/Fuel Leak Present',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'DRIVER SIDE',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-A11',
            item: 'Door Overlaps',
            check:
                'Inspect door overlaps for obvious damage and loose hardware.',
            faults: [
              'Serviceable',
              'Minor Cosmetic Issue',
              'Hardware Loose',
              'Missing, Cracked, or Damaged',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'DRIVER SIDE REAR',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-A12',
            item: 'Wheel/Tire',
            check: 'Re-inspect for any new damage sustained during operation.',
            faults: [
              'Serviceable',
              'Minor New Damage',
              'Cut/Gouge/New Damage',
              'Ply/Belt Exposed or Audible Leak',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A13',
            item: 'Wheel Deflector and Belly Armor',
            check:
                'Inspect area between belly armor and propeller shaft for debris. Inspect wheel deflector for missing components or damage.',
            faults: [
              'Serviceable',
              'Minor Damage',
              'Missing Components',
              'Debris Contacting Propeller Shaft',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A14',
            item: 'Suspension Cross Plumbing Hoses',
            check:
                'Inspect hoses for blisters, tears, and exposed metal braids.',
            faults: [
              'Serviceable',
              'Minor Blister',
              'Tear Developing',
              'Metal Braids Exposed or Class III Leak',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A15',
            item: 'Jounce Bumper',
            check: 'Inspect jounce bumper for gouges, cracks, or if missing.',
            faults: [
              'Serviceable',
              'Minor Gouge',
              'Cracked',
              'Missing or Prevents Operation',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-A16',
            item: 'Stowage Boxes',
            check:
                'Visually inspect stowage boxes for proper operation. Specific to M1278, M1280, M1281, M1279 variants.',
            faults: [
              'Operational',
              'Stiff/Difficult',
              'Latch Issue',
              'Inoperable',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A17',
            item: 'Fluid Leaks',
            check:
                'Inspect driver side rear for obvious damage and evidence of new leaks.',
            faults: [
              'No New Leaks',
              'Class I Seep',
              'Class II Drip',
              'Class III Brake/Fuel Leak Present',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'REAR OF VEHICLE',
        items: [
          PmcsCheckItem(
            id: 'JLTV-A18',
            item: 'Lights (Rear)',
            check:
                'Inspect rear composite lights and reverse light for secure mounting, cracks, and damage.',
            faults: [
              'All Operational',
              '1 Light Out',
              'Multiple Lights Out',
              'All Out/Severely Damaged',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-A19',
            item: 'Gladhands (Rear)',
            check:
                'Check rear gladhand couplers and grommets for leaks, damage, or missing covers.',
            faults: [
              'Serviceable',
              'Minor Wear',
              'Cover Missing',
              'Damaged or Leaking',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-A20',
            item: 'Rear Camera Lens (M1278/M1280/M1281)',
            check:
                'Inspect for new damage to camera lens glass. Applies to M1278, M1280, M1281 only.',
            faults: [
              'Clear/Serviceable',
              'Dirty (Cleanable)',
              'Scratched',
              'New Damage/Broken',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-A21',
            item: 'Rear Camera (M1279)',
            check:
                'Inspect for new damage to camera lens glass. Applies to M1279 only.',
            faults: [
              'Clear/Serviceable',
              'Dirty (Cleanable)',
              'Scratched',
              'New Damage/Broken',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A22',
            item: 'Pintle Hook',
            check:
                'Re-inspect for secure mounting, cracks, damage, and proper operation.',
            faults: [
              'Serviceable',
              'Minor Damage',
              'Latch Stiff',
              'Safety Latch Won\'t Engage or Pin Missing/Damaged',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'PASSENGER SIDE REAR',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-A23',
            item: 'Wheel/Tire',
            check: 'Re-inspect for any new damage sustained during operation.',
            faults: [
              'Serviceable',
              'Minor New Damage',
              'Cut/Gouge/New Damage',
              'Ply/Belt Exposed or Audible Leak',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A24',
            item: 'Wheel Deflector and Belly Armor',
            check:
                'Inspect area between belly armor and propeller shaft for debris. Inspect wheel deflector for missing components or damage.',
            faults: [
              'Serviceable',
              'Minor Damage',
              'Missing Components',
              'Debris Contacting Propeller Shaft',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-A25',
            item: 'Stowage Boxes',
            check:
                'Visually inspect stowage boxes for proper operation. Specific to M1278, M1280, M1281, M1279 variants.',
            faults: [
              'Operational',
              'Stiff/Difficult',
              'Latch Issue',
              'Inoperable',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A26',
            item: 'Fuel Cap and Strainer',
            check:
                'Check fuel cap for looseness, cracks, and damage. Inspect fuel strainer for debris.',
            faults: [
              'Serviceable',
              'Cap Loose',
              'Debris in Strainer',
              'Cap Missing or Damage Prevents Operation',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A27',
            item: 'Brake Reservoirs',
            check:
                'Inspect two service brake reservoirs and one park brake reservoir for damage and leaks. Ensure fluid is between FILL and LOW lines.',
            faults: [
              'Level OK (Between FILL/LOW)',
              'Fluid Low — Add',
              'Fluid Very Low',
              'Brake Fluid Leak Present',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A28',
            item: 'Suspension Cross Plumbing Hoses',
            check:
                'Inspect hoses for blisters, tears, and exposed metal braids.',
            faults: [
              'Serviceable',
              'Minor Blister',
              'Tear Developing',
              'Metal Braids Exposed or Class III Leak',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A29',
            item: 'Jounce Bumper',
            check: 'Inspect jounce bumper for gouges, cracks, or if missing.',
            faults: [
              'Serviceable',
              'Minor Gouge',
              'Cracked',
              'Missing or Prevents Operation',
            ],
          ),
          PmcsCheckItem(
            id: 'JLTV-CRIT-A30',
            item: 'Fluid Leaks',
            check:
                'Inspect passenger side rear for obvious damage and evidence of new leaks.',
            faults: [
              'No New Leaks',
              'Class I Seep',
              'Class II Drip',
              'Class III Brake/Fuel Leak Present',
            ],
          ),
        ],
      ),
      PmcsCategory(
        name: 'PASSENGER SIDE',
        items: [
          PmcsCheckItem(
            id: 'JLTV-CRIT-A31',
            item: 'Muffler',
            check:
                'Re-inspect muffler, clamps, and pipes for looseness, leaks, or damage.',
            faults: [
              'Serviceable',
              'Minor Damage',
              'Loose/Rattling',
              'Damage Impedes Operation',
            ],
          ),
        ],
      ),
    ],
  },
);
