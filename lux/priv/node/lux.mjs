import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { writeFile, readFile, unlink } from 'fs/promises';
import { ensureDependencyInstalled } from "nypm";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function validatePackageName(packageName) {
  if (typeof packageName !== 'string' || packageName.trim().length === 0) {
    return { success: false, error: "ERR_INVALID_PACKAGE_NAME", message: "Package name must be a non-empty string" };
  }
  return null;
}

async function readPackageFiles() {
  const packageJsonPath = join(__dirname, 'package.json');
  const packageLockPath = join(__dirname, 'package-lock.json');
  const [packageJson, packageLock] = await Promise.all([
    readFile(packageJsonPath, 'utf8'),
    readFile(packageLockPath, 'utf8').catch(() => null),
  ]);
  return { packageJson, packageLock, packageLockPath };
}

async function restorePackageFiles(original, options) {
  if (options.update_lock_file) return;
  const { packageJson, packageLock, packageLockPath } = original;
  if (packageLock === null) {
    await unlink(packageLockPath).catch(() => {});
  } else {
    await writeFile(packageLockPath, packageLock, 'utf8');
  }
}

export const importPackage = async (packageName, options = {}) => {
  const validationError = validatePackageName(packageName);
  if (validationError) return validationError;

  const original = await readPackageFiles();

  try {
    await ensureDependencyInstalled(packageName, {
      cwd: __dirname,
      silent: true
    });
    await import(packageName);
    return { success: true };
  } catch (error) {
    return { success: false, error: error.code || "ERR_UNKNOWN", message: error.message };
  } finally {
    await restorePackageFiles(original, options);
  }
};
