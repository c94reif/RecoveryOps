export function dartString(value) {
  return "'" + String(value)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\$/g, '\\$')
    .replace(/\r?\n/g, '\\n') + "'";
}

export const catalogFileName = ({ id }) =>
  `${id.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`)}_pmcs_catalog.g.dart`;

export function validateCatalogs(catalogs) {
  if (!Array.isArray(catalogs) || catalogs.length === 0) {
    throw new Error('Register at least one vehicle checklist');
  }
  const ids = new Set();
  const wireNames = new Set();
  const files = new Set();
  const reserved = new Set([
    'values', 'name', 'index', 'wireName', 'displayName', 'family', 'variant',
    'technicalManual', 'fromWireName', 'tryFromWireName', 'hashCode', 'runtimeType',
    'toString', 'noSuchMethod',
    'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default',
    'do', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'for', 'if',
    'in', 'is', 'new', 'null', 'rethrow', 'return', 'super', 'switch', 'this',
    'throw', 'true', 'try', 'var', 'void', 'while', 'with',
  ]);
  for (const catalog of catalogs) {
    if (!catalog || typeof catalog !== 'object' || Array.isArray(catalog)) {
      throw new Error('Each vehicle entry must be an object');
    }
    if (typeof catalog.id !== 'string' || !/^[a-z][a-zA-Z0-9]*$/.test(catalog.id) || reserved.has(catalog.id)) {
      throw new Error(`Invalid Dart vehicle id: ${catalog.id}`);
    }
    if (!/^[A-Z][A-Z0-9_]*$/.test(catalog.wireName)) {
      throw new Error(`Invalid vehicle wireName: ${catalog.wireName}`);
    }
    const file = catalogFileName(catalog);
    if (ids.has(catalog.id) || wireNames.has(catalog.wireName) || files.has(file)) {
      throw new Error(`Duplicate vehicle id, wireName or filename: ${catalog.id}`);
    }
    ids.add(catalog.id);
    wireNames.add(catalog.wireName);
    files.add(file);
    for (const field of ['displayName', 'family', 'variant', 'technicalManual']) {
      if (typeof catalog[field] !== 'string' || !catalog[field].trim() || /[\r\n]/.test(catalog[field])) {
        throw new Error(`${catalog.id}: ${field} must be nonempty, single-line text`);
      }
    }
    const source = catalog.source;
    if (!source || typeof source !== 'object' || Array.isArray(source)) {
      throw new Error(`${catalog.id}: a PMCS checklist is required`);
    }
    const itemIds = new Set();
    for (const [phase, categories] of Object.entries(source)) {
      if (!['BEFORE', 'DURING', 'AFTER'].includes(phase) || !Array.isArray(categories)) {
        throw new Error(`${catalog.id}: invalid PMCS phase ${phase}`);
      }
      for (const category of categories) {
        if (typeof category?.category !== 'string' || !category.category.trim() ||
            !Array.isArray(category.items) || !category.items.length) {
          throw new Error(`${catalog.id}: each category needs a name and checks`);
        }
        for (const item of category.items) {
          if (['id', 'item', 'check'].some((field) => typeof item?.[field] !== 'string' || !item[field].trim())) {
            throw new Error(`${catalog.id}: each check needs an id, label and instruction`);
          }
          if (itemIds.has(item.id)) throw new Error(`${catalog.id}: duplicate check ${item.id}`);
          itemIds.add(item.id);
          if (!Array.isArray(item.faults) || item.faults.length < 2 ||
              item.faults.some((fault) => typeof fault !== 'string' || !fault.trim())) {
            throw new Error(`${catalog.id}/${item.id}: provide a serviceable answer and fault answers`);
          }
        }
      }
    }
    if (!itemIds.size) throw new Error(`${catalog.id}: the PMCS checklist is empty`);
  }
}

const generatedHeader = '// GENERATED FILE — DO NOT EDIT BY HAND.\n' +
  '// Source: tool/tm_source/catalog-manifest.mjs\n' +
  '// Regenerate with ./tool/generate_catalog.sh.\n\n';

export function emitVehicleTypes(catalogs) {
  const fields = ['wireName', 'displayName', 'family', 'variant', 'technicalManual'];
  return generatedHeader + 'enum VehicleType {\n' + catalogs.map((catalog, index) =>
    `  ${catalog.id}(\n` + fields.map((field) => `    ${field}: ${dartString(catalog[field])},`).join('\n') +
    `\n  )${index === catalogs.length - 1 ? ';' : ','}`
  ).join('\n') + '\n\n' + fields.map((field) => `  final String ${field};`).join('\n') +
    '\n\n  const VehicleType({\n' + fields.map((field) => `    required this.${field},`).join('\n') +
    '\n  });\n\n' +
    '  static VehicleType fromWireName(String value) =>\n' +
    "      tryFromWireName(value) ?? (throw ArgumentError('Unknown vehicle type: $value'));\n\n" +
    '  static VehicleType? tryFromWireName(String? value) {\n' +
    '    for (final type in values) {\n' +
    '      if (type.wireName == value) return type;\n' +
    '    }\n    return null;\n  }\n}\n';
}

export function emitRegistry(catalogs) {
  return generatedHeader +
    "import 'package:circle_x/domain/entities/pmcs_catalog.dart';\n" +
    "import 'package:circle_x/domain/entities/vehicle_type.dart';\n" +
    catalogs.map((catalog) => `import '${catalogFileName(catalog)}';`).join('\n') +
    '\n\nconst Map<VehicleType, PmcsCatalog> registeredPmcsCatalogs = {\n' +
    catalogs.map(({ id }) => `  VehicleType.${id}: ${id}PmcsCatalog,`).join('\n') +
    '\n};\n';
}
