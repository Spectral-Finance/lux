import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

const luxPath = new URL('../../priv/node/lux.mjs', import.meta.url);

describe('lux.mjs', () => {
  describe('importPackage', () => {
    it('should be an async function', async () => {
      const mod = await import(luxPath);
      assert.equal(typeof mod.importPackage, 'function');
    });

    it('should return error for empty package names', async () => {
      const { importPackage } = await import(luxPath);
      const result = await importPackage('');
      assert.equal(result.success, false);
      assert.equal(result.error, 'ERR_INVALID_PACKAGE_NAME');
    });

    it('should return error for whitespace-only package names', async () => {
      const { importPackage } = await import(luxPath);
      const result = await importPackage('   ');
      assert.equal(result.success, false);
      assert.equal(result.error, 'ERR_INVALID_PACKAGE_NAME');
    });

    it('should return error for non-string package names', async () => {
      const { importPackage } = await import(luxPath);
      const result = await importPackage(null);
      assert.equal(result.success, false);
      assert.equal(result.error, 'ERR_INVALID_PACKAGE_NAME');
    });

    it('should return error for non-existent packages', async () => {
      const { importPackage } = await import(luxPath);
      const result = await importPackage('nonexistent-package-xyz-12345', {
        update_lock_file: false
      });
      assert.equal(result.success, false);
      assert.ok(result.error);
    });
  });
});
