import { PMCS_CHECKS } from './pmcs-checks.mjs';
import { JLTV_PMCS_CHECKS } from './pmcs-checks-jltv.mjs';

// Register each vehicle/variant and checklist here, then run
// ./tool/generate_catalog.sh. Keep ids and wireNames stable for saved reports.
// Existing TM labels came with the imported checklists and still need source
// verification. See README.md's TM source audit before updating their editions.
export const vehicleCatalogs = [
  {
    id: 'stryker',
    wireName: 'STRYKER',
    displayName: 'Stryker',
    family: 'Stryker',
    variant: 'Family PMCS',
    technicalManual: 'TM 9-2355-311-10',
    source: PMCS_CHECKS,
  },
  {
    id: 'jltv',
    wireName: 'JLTV',
    displayName: 'JLTV',
    family: 'JLTV',
    variant: 'Family PMCS',
    technicalManual: 'TM 9-2320-400-10',
    source: JLTV_PMCS_CHECKS,
  },
];
