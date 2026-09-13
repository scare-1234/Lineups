import { defineConfig } from 'vite';

/**
 * The preload runs in a sandboxed context, where relative `require` calls are not
 * available — so it is bundled into a single CommonJS file with electron left external.
 */
export default defineConfig({
  build: {
    outDir: 'dist/preload',
    emptyOutDir: true,
    minify: false,
    target: 'node20',
    lib: {
      entry: 'src/preload/index.ts',
      formats: ['cjs'],
      fileName: () => 'index.js',
    },
    rollupOptions: {
      external: ['electron'],
    },
  },
});
