import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { vehicleCatalogs } from './catalog-manifest.mjs';
import { validateCatalogs } from './catalog-registry.mjs';

const generator = fileURLToPath(new URL('./gen-dart.mjs', import.meta.url));
const fixture = (id, family) => ({
  id, family, wireName: id.toUpperCase(), displayName: `${family} ${id}`,
  variant: id, technicalManual: `TM TEST-${id}`,
  source: { BEFORE: [{ category: 'Test category', items: [{
    id: `${id}-B01`, item: `${id} inspection`, check: 'Test instruction',
    faults: ['Serviceable', 'Test fault'],
  }] }] },
});

test('one manifest registers new families and sibling variants end to end', (t) => {
  const root = mkdtempSync(join(tmpdir(), 'circle-x-catalog-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const manifest = join(root, 'manifest.mjs');
  writeFileSync(manifest, `export const vehicleCatalogs = ${JSON.stringify([
    ...vehicleCatalogs, fixture('testCargo', 'Test trucks'), fixture('testAmbulance', 'Test trucks'),
  ])};`);
  execFileSync(process.execPath, [generator, root, manifest]);
  const types = readFileSync(join(root, 'domain/entities/vehicle_type.g.dart'), 'utf8');
  const registry = readFileSync(join(root, 'data/catalog/pmcs_catalog_registry.g.dart'), 'utf8');
  assert.match(types, /wireName: 'STRYKER'/);
  assert.match(types, /wireName: 'JLTV'/);
  assert.equal((types.match(/family: 'Test trucks'/g) ?? []).length, 2);
  for (const [id, file] of [['testCargo', 'test_cargo'], ['testAmbulance', 'test_ambulance']]) {
    assert.match(registry, new RegExp(`VehicleType\\.${id}: ${id}PmcsCatalog`));
    const catalog = readFileSync(join(root, `data/catalog/${file}_pmcs_catalog.g.dart`), 'utf8');
    assert.ok(catalog.includes(`id: '${id}-B01'`));
    assert.ok(catalog.includes(`vehicleType: VehicleType.${id}`));
  }
});

test('duplicate identifiers, incomplete metadata and empty checklists are rejected', () => {
  assert.throws(() => validateCatalogs([...vehicleCatalogs, vehicleCatalogs[0]]), /Duplicate/);
  assert.throws(() => validateCatalogs([fixture('class', 'Test')]), /Invalid Dart vehicle id/);
  assert.throws(() => validateCatalogs([{ ...fixture('test', 'Test'), id: undefined }]), /Invalid Dart vehicle id/);
  assert.throws(() => validateCatalogs([{ ...fixture('test', 'Test'), technicalManual: '' }]), /technicalManual/);
  assert.throws(() => validateCatalogs([{ ...fixture('test', 'Test'), source: {} }]), /empty/);
  const duplicate = fixture('test', 'Test');
  duplicate.source.BEFORE[0].items.push(duplicate.source.BEFORE[0].items[0]);
  assert.throws(() => validateCatalogs([duplicate]), /duplicate check/);
});

test('invalid manifests do not overwrite generated files', (t) => {
  const root = mkdtempSync(join(tmpdir(), 'circle-x-catalog-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const manifest = join(root, 'manifest.mjs');
  const existing = join(root, 'domain/entities/vehicle_type.g.dart');
  mkdirSync(join(root, 'domain/entities'), { recursive: true });
  writeFileSync(existing, 'previous generated version');
  writeFileSync(manifest, `export const vehicleCatalogs = ${JSON.stringify([
    fixture('valid', 'Test'), { ...fixture('invalid', 'Test'), source: {} },
  ])};`);
  assert.throws(() => execFileSync(process.execPath, [generator, root, manifest], { stdio: 'pipe' }),
    (error) => error.stderr.toString().includes('the PMCS checklist is empty'));
  assert.equal(readFileSync(existing, 'utf8'), 'previous generated version');
  assert.equal(existsSync(join(root, 'data/catalog')), false);
});
