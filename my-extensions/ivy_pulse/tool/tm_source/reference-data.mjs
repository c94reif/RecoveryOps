
export const CORRECTIVE_ACTIONS = [
  "Repaired On-Site",
  "Adjusted / Tightened",
  "Replaced Component",
  "Topped Off Fluid",
  "Parts On Order",
  "Requires Higher Echelon",
  "Deadlined — NMC",
  "Deferred (Low Priority)",
  "No Action Required",
  "Operator Error — Retrained",
];

export const RANKS = [
  "PVT", "PV2", "PFC", "SPC", "CPL",
  "SGT", "SSG", "SFC", "MSG", "1SG", "SGM",
  "2LT", "1LT", "CPT", "MAJ", "LTC", "COL", "BG", "MG",
  "WO1", "CW2", "CW3", "CW4", "CW5",
];

export const MISSIONS = [
  { type: "Convoy", days: 3, desc: "Logistics movement, 1-3 days" },
  { type: "Training Exercise", days: 14, desc: "Field training, up to 14 days" },
  { type: "Combat Patrol", days: 7, desc: "Patrol operations, up to 7 days" },
  { type: "Admin / Motor Pool", days: 1, desc: "Garrison admin movement, 1 day" },
  { type: "Gunnery", days: 7, desc: "Range / gunnery qualification, up to 7 days" },
  { type: "JRTC / NTC Rotation", days: 30, desc: "CTC rotation, up to 30 days" },
];

export const COMMON_PARTS = [
  { nsn: "2530-01-562-1743", name: "Tire, Pneumatic (Stryker)" },
  { nsn: "2530-01-529-2264", name: "Runflat Insert" },
  { nsn: "4710-01-534-7583", name: "Radiator Hose, Upper" },
  { nsn: "4710-01-534-7584", name: "Radiator Hose, Lower" },
  { nsn: "2940-01-533-8105", name: "Air Filter Element" },
  { nsn: "6140-01-485-1472", name: "Battery, 6T" },
  { nsn: "3040-01-534-2789", name: "Drive Belt, Serpentine" },
  { nsn: "4210-01-530-5411", name: "Fire Extinguisher, 5lb" },
  { nsn: "6220-01-534-1156", name: "Headlight Assembly, BO" },
  { nsn: "6220-01-534-1157", name: "Tail Light Assembly" },
  { nsn: "2520-01-534-6742", name: "Brake Pad Set" },
  { nsn: "2520-01-534-6743", name: "Brake Fluid, DOT 5" },
  { nsn: "9150-01-197-7688", name: "Engine Oil, 15W-40" },
  { nsn: "9150-01-534-7712", name: "Coolant, ELC" },
  { nsn: "9150-01-534-7713", name: "Transmission Fluid" },
  { nsn: "5340-01-534-8901", name: "Antenna, AS-3900" },
  { nsn: "5820-01-534-8902", name: "Handset, H-250" },
  { nsn: "2510-01-534-6744", name: "CTIS Airline Kit" },
  { nsn: "5330-01-534-7777", name: "Seal Kit, Ramp Hydraulic" },
  { nsn: "9150-01-053-6607", name: "CLP (Weapon Lubricant)" },
];

export const PRIORITY_DESIGNATORS = [
  { code: "02", label: "NMCS (Not Mission Capable Supply)", color: "destructive" },
  { code: "03", label: "PMCS Priority", color: "warning" },
  { code: "06", label: "Initial Issue", color: "maintainer" },
  { code: "09", label: "Routine", color: "muted-foreground" },
];

export const SEVERITY_OPTIONS = ["RED_X", "CIRCLE_X", "DASH"];

export const BUMPER_NUMBERS = [
  "A-11", "A-12", "A-13", "A-14",
  "A-21", "A-22", "A-23", "A-24",
  "B-11", "B-12", "B-13", "B-14",
  "B-21", "B-22", "B-23", "B-24",
  "C-11", "C-12", "C-13", "C-14",
  "HQ-1", "HQ-2", "HQ-3", "HQ-4",
];

export const UNITS = [
  "A Co, 1-23 IN", "B Co, 1-23 IN", "C Co, 1-23 IN", "HHC, 1-23 IN",
  "A Co, 2-1 IN", "B Co, 2-1 IN", "C Co, 2-1 IN", "HHC, 2-1 IN",
];
