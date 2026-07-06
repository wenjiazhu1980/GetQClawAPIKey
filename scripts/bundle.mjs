// Bundle ESM source files into CJS for pkg packaging.
import { build } from 'esbuild';
import { mkdirSync } from 'node:fs';

const entries = [
  { in: 'scripts/get-key.mjs', out: 'dist/get-key.cjs' },
  { in: 'scripts/models.mjs', out: 'dist/models.cjs' },
  { in: 'scripts/balance.mjs', out: 'dist/balance.cjs' },
];

mkdirSync('dist', { recursive: true });

for (const { in: input, out: output } of entries) {
  await build({
    entryPoints: [input],
    bundle: true,
    platform: 'node',
    target: 'node18',
    format: 'cjs',
    outfile: output,
    banner: { js: '/* bundled by esbuild */' },
  });
  console.log(`  ${input} -> ${output}`);
}

console.log('Bundle complete.');
