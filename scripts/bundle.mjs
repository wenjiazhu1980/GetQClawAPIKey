// Bundle ESM source files into CJS for pkg packaging.
import { build } from 'esbuild';
import { mkdirSync } from 'node:fs';

mkdirSync('dist', { recursive: true });

await build({
  entryPoints: ['scripts/cli.mjs'],
  bundle: true,
  platform: 'node',
  target: 'node18',
  format: 'cjs',
  outfile: 'dist/cli.cjs',
  banner: { js: '/* bundled by esbuild */' },
});

console.log('  scripts/cli.mjs -> dist/cli.cjs');
console.log('Bundle complete.');
