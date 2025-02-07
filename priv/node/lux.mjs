import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { writeFile, readFile } from 'fs/promises';
import { ensureDependencyInstalled } from "nypm";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export const importPackage = async (packageName, options = {}) => {
  const packageJson = await readFile(join(__dirname, 'package.json'), 'utf8');
  const packageLock = await readFile(join(__dirname, 'package-lock.json'), 'utf8');

  try {
    await ensureDependencyInstalled(packageName, {
      cwd: __dirname,
      silent: true
    });
    await import(packageName);
    return {success: true};
  } catch (error) {
    return {success: false, error: error.code};
  } finally {
    if (!options.update_lock_file) {
      await writeFile(join(__dirname, 'package.json'), packageJson, 'utf8');
      await writeFile(join(__dirname, 'package-lock.json'), packageLock, 'utf8');
    }
  }
};