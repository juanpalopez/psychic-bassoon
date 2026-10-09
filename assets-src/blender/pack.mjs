// Meshopt-compress GLBs WITHOUT quantization: the game bakes node
// transforms into the vertex data (glb.ts), which would clamp normalized
// int16 positions, so attributes stay float and only the buffers are packed.
import {NodeIO} from '@gltf-transform/core';
import {EXTMeshoptCompression, ALL_EXTENSIONS} from '@gltf-transform/extensions';
import {dedup, prune, weld, reorder} from '@gltf-transform/functions';
import {MeshoptEncoder, MeshoptDecoder} from 'meshoptimizer';
import {readdirSync} from 'node:fs';
await MeshoptEncoder.ready; await MeshoptDecoder.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({
  'meshopt.encoder': MeshoptEncoder, 'meshopt.decoder': MeshoptDecoder});
const [src, out] = process.argv.slice(2);
for (const f of readdirSync(src).filter(f => f.endsWith('.glb'))) {
  const doc = await io.read(`${src}/${f}`);
  await doc.transform(dedup(), weld(), reorder({encoder: MeshoptEncoder}), prune());
  doc.createExtension(EXTMeshoptCompression).setRequired(true)
    .setEncoderOptions({method: EXTMeshoptCompression.EncoderMethod.QUANTIZE});
  await io.write(`${out}/${f}`, doc);
  // round-trip check: decode and compare vertex data with the source
  const a = (await io.read(`${src}/${f}`)).getRoot().listMeshes()[0].listPrimitives()[0];
  const b = (await io.read(`${out}/${f}`)).getRoot().listMeshes()[0].listPrimitives()[0];
  const box = p => { const pos = p.getAttribute('POSITION'); return [pos.getMin([]), pos.getMax([]), pos.getComponentType()]; };
  const tris = p => (p.getIndices()?.getCount() ?? p.getAttribute('POSITION').getCount()) / 3;
  console.log(f, JSON.stringify(box(a)) === JSON.stringify(box(b)) ? 'bounds ok' : 'BOUNDS DIFFER', tris(a), tris(b),
    b.getAttribute('POSITION').getComponentType(), Object.keys(b.listSemantics ? {} : {}).length, b.listSemantics().join(','));
}
