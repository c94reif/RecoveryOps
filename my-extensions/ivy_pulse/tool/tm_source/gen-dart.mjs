import { PMCS_CHECKS } from './pmcs-checks.mjs';
import { JLTV_PMCS_CHECKS } from './pmcs-checks-jltv.mjs';
import * as ref from './reference-data.mjs';
import { writeFileSync } from 'node:fs';

const OUT = process.argv[2];
if (!OUT) throw new Error('usage: node gen-dart.mjs <lib/data/catalog dir>');

const PHASES = [['BEFORE', 'PmcsPhase.before'], ['DURING', 'PmcsPhase.during'], ['AFTER', 'PmcsPhase.after']];

/** Dart single-quoted string literal. */
function s(v) {
  return "'" + String(v)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\$/g, '\\$')
    .replace(/\r?\n/g, '\\n') + "'";
}

function header(desc) {
  return [
    '// GENERATED FILE — DO NOT EDIT BY HAND.',
    '//',
    `// ${desc}`,
    '// Regenerate with tool/generate_catalog.sh after editing the TM source data.',
    '',
  ].join('\n');
}

function emitItem(item, indent) {
  const p = ' '.repeat(indent);
  const faults = item.faults.map((f) => `${p}      ${s(f)},`).join('\n');
  return [
    `${p}PmcsCheckItem(`,
    `${p}  id: ${s(item.id)},`,
    `${p}  item: ${s(item.item)},`,
    `${p}  check: ${s(item.check)},`,
    `${p}  faults: [`,
    faults,
    `${p}  ],`,
    `${p}),`,
  ].join('\n');
}

function emitCatalog({ varName, vehicleEnum, source, desc, docs }) {
  const lines = [];
  lines.push(header(desc));
  lines.push("import 'package:ivy_pulse/domain/entities/pmcs_catalog.dart';");
  lines.push("import 'package:ivy_pulse/domain/entities/pmcs_category.dart';");
  lines.push("import 'package:ivy_pulse/domain/entities/pmcs_check_item.dart';");
  lines.push("import 'package:ivy_pulse/domain/entities/pmcs_phase.dart';");
  lines.push("import 'package:ivy_pulse/domain/entities/vehicle_type.dart';");
  lines.push('');
  for (const line of docs) lines.push(`/// ${line}`);
  lines.push(`const PmcsCatalog ${varName} = PmcsCatalog(`);
  lines.push(`  vehicleType: ${vehicleEnum},`);
  lines.push('  phases: {');
  for (const [key, dartPhase] of PHASES) {
    const cats = source[key] ?? [];
    lines.push(`    ${dartPhase}: [`);
    for (const cat of cats) {
      lines.push(`      PmcsCategory(`);
      lines.push(`        name: ${s(cat.category)},`);
      lines.push(`        items: [`);
      for (const item of cat.items) lines.push(emitItem(item, 10));
      lines.push(`        ],`);
      lines.push(`      ),`);
    }
    lines.push('    ],');
  }
  lines.push('  },');
  lines.push(');');
  lines.push('');
  return lines.join('\n');
}

const strykerCount = PHASES.reduce((a, [k]) => a + PMCS_CHECKS[k].reduce((x, c) => x + c.items.length, 0), 0);
const jltvCount = PHASES.reduce((a, [k]) => a + JLTV_PMCS_CHECKS[k].reduce((x, c) => x + c.items.length, 0), 0);

writeFileSync(`${OUT}/stryker_pmcs_catalog.g.dart`, emitCatalog({
  varName: 'strykerPmcsCatalog',
  vehicleEnum: 'VehicleType.stryker',
  source: PMCS_CHECKS,
  desc: 'Stryker family PMCS checks transcribed from TM 9-2355-311-10.',
  docs: [
    'Stryker PMCS catalog — ' + strykerCount + ' TM checks across before, during,',
    'and after operations.',
  ],
}));

writeFileSync(`${OUT}/jltv_pmcs_catalog.g.dart`, emitCatalog({
  varName: 'jltvPmcsCatalog',
  vehicleEnum: 'VehicleType.jltv',
  source: JLTV_PMCS_CHECKS,
  desc: 'JLTV PMCS checks transcribed from TM 9-2320-400-10 PMCS tables.',
  docs: [
    'JLTV PMCS catalog — ' + jltvCount + ' TM checks across before, during, and',
    'after operations.',
    '',
    'Item ids carrying the `CRIT` marker have a "Not Mission Capable If"',
    'condition in the TM and are graded as critical systems by the classifier.',
  ],
}));

// ── Reference data ────────────────────────────────────────────────────────
const r = [];
r.push(header('Unit, parts, and dispatch reference data used by the PMCS flow.'));
r.push("import 'package:ivy_pulse/domain/entities/fault_severity.dart';");
r.push("import 'package:ivy_pulse/domain/entities/reference/common_part.dart';");
r.push("import 'package:ivy_pulse/domain/entities/reference/mission.dart';");
r.push("import 'package:ivy_pulse/domain/entities/reference/priority_designator.dart';");
r.push('');
r.push('/// Actions a maintainer can record against a corrected fault.');
r.push('const List<String> correctiveActions = [');
for (const a of ref.CORRECTIVE_ACTIONS) r.push(`  ${s(a)},`);
r.push('];');
r.push('');
r.push('/// Enlisted, warrant, and officer ranks, in order of precedence.');
r.push('const List<String> ranks = [');
for (const a of ref.RANKS) r.push(`  ${s(a)},`);
r.push('];');
r.push('');
r.push('/// Dispatch profiles and how many days each is normally good for.');
r.push('const List<Mission> missions = [');
for (const m of ref.MISSIONS) {
  r.push('  Mission(');
  r.push(`    type: ${s(m.type)},`);
  r.push(`    days: ${m.days},`);
  r.push(`    description: ${s(m.desc)},`);
  r.push('  ),');
}
r.push('];');
r.push('');
r.push('/// Frequently demanded parts, for one-tap ordering against a fault.');
r.push('const List<CommonPart> commonParts = [');
for (const p of ref.COMMON_PARTS) {
  r.push(`  CommonPart(nsn: ${s(p.nsn)}, name: ${s(p.name)}),`);
}
r.push('];');
r.push('');
r.push('/// Requisition priority designators, most urgent first.');
r.push('const List<PriorityDesignator> priorityDesignators = [');
for (const p of ref.PRIORITY_DESIGNATORS) {
  r.push(`  PriorityDesignator(code: ${s(p.code)}, label: ${s(p.label)}),`);
}
r.push('];');
r.push('');
r.push('/// Fault status symbols an operator or maintainer can assign.');
r.push('const List<FaultSeverity> severityOptions = [');
for (const sev of ref.SEVERITY_OPTIONS) {
  const dart = { RED_X: 'FaultSeverity.redX', CIRCLE_X: 'FaultSeverity.circleX', DASH: 'FaultSeverity.dash' }[sev];
  r.push(`  ${dart},`);
}
r.push('];');
r.push('');
// Bumper numbers and units are deliberately NOT generated: they are typed on
// the setup and profile screens. A preset roster is wrong the moment a crew
// takes a vehicle from another company.
writeFileSync(`${OUT}/pmcs_reference_data.g.dart`, r.join('\n'));

console.log(`stryker=${strykerCount} jltv=${jltvCount} wrote 3 files to ${OUT}`);
