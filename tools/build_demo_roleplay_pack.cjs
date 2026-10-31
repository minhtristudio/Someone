#!/usr/bin/env node
/*
 * Rebuild/check the script-free model embedded in 29acde6377368455288b7247f8622f2d.txt.
 * Development dependencies (installed outside the repository or in ignored node_modules):
 *   npm install --no-save --ignore-scripts rbxm-parser@1.1.4 lz4js@0.2.0
 *   node tools/build_demo_roleplay_pack.cjs --check
 *   node tools/build_demo_roleplay_pack.cjs --update
 *
 * The original place uses LZ4/Zstandard chunks. The parser's bundled native LZ4
 * is not portable across OSes, so supply the equivalent pure-JS block codec.
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const sourcePath = path.join(root, '_GameFileDEMO.rbxl.txt');
const scriptPath = path.join(root, '29acde6377368455288b7247f8622f2d.txt');
const source = fs.readFileSync(sourcePath);
const sourceHash = crypto.createHash('sha256').update(source).digest('hex');

const lz4js = require('lz4js');
const parserEntry = require.resolve('rbxm-parser');
const lz4Path = require.resolve('lz4', { paths: [path.dirname(parserEntry)] });
require.cache[lz4Path] = {
  id: lz4Path, filename: lz4Path, loaded: true,
  exports: {
    decodeBlock(src, dst) { return lz4js.decompressBlock(src, dst, 0, src.length, 0); },
    encodeBound(size) { return lz4js.compressBound(size); },
    encodeBlock(src, dst) {
      const length = lz4js.compressBlock(src, dst, 0, src.length, new Uint32Array(1 << 16));
      if (length) return length;
      // Incompressible block: encode as an LZ4 literal block, not a zero-length chunk.
      let n = src.length, i = 0;
      dst[i++] = Math.min(n, 15) << 4;
      if (n >= 15) {
        n -= 15;
        while (n >= 255) { dst[i++] = 255; n -= 255; }
        dst[i++] = n;
      }
      dst.set(src, i);
      return i + src.length;
    },
  },
};
const { RobloxFile, Folder, DataType } = require('rbxm-parser');
const place = RobloxFile.ReadFromBuffer(source);
if (!place) throw new Error('Cannot read _GameFileDEMO.rbxl.txt');
const base = 'ServerScriptService.MainScript.Trasnfer_Services.ReplicatedStorage.';
function find(dotted) {
  let current = { Children: place.Roots };
  for (const part of dotted.split('.')) {
    current = current.Children.find(child => child.Name === part);
    if (!current) throw new Error(`Missing ${dotted}: ${part}`);
  }
  return current;
}
const scenes = find(base + 'Animations.Scenes');
const characters = find(base + 'Characters');
const player = find(base + 'Animations.Characters.Player');
const human = find(base + 'Animations.Characters.Human');
for (const scene of scenes.Children) {
  for (const child of [...scene.Children]) {
    // Scene scripts and unrelated face/effect assets are not executable here.
    if (child.Name !== 'Rig' && child.Name !== 'Animations') child.RemoveParent();
  }
}
const model = new RobloxFile();
const folder = new Folder(); folder.Name = 'DemoRoleplay'; model.AddRoot(folder);
scenes.Parent = folder; characters.Parent = folder;
const solos = new Folder(); solos.Name = 'Solo'; solos.Parent = folder;
player.Parent = solos; human.Parent = solos;
const all = model.GetAllDescendants();
for (const instance of all) {
  if (instance.IsA('LuaSourceContainer')) throw new Error('Unexpected executable source in model');
  // Cache/collision blobs aren't needed: preview and scene parts are non-colliding.
  instance.Props.delete('ModelMeshData');
  instance.Props.delete('PhysicalConfigData');
  for (const [name, prop] of instance.Props) {
    if (prop.type === DataType.SharedString) throw new Error(`Unexpected shared-string property ${instance.ClassName}.${name}`);
  }
}
const binary = model.WriteToBuffer();
const roundTrip = RobloxFile.ReadFromBuffer(binary);
if (!roundTrip || roundTrip.Roots[0]?.Name !== 'DemoRoleplay' || roundTrip.GetAllDescendants().length !== all.length) {
  throw new Error('Generated model did not round-trip');
}
const crcTable = Array.from({ length: 256 }, (_, value) => {
  for (let n = 0; n < 8; n++) value = (value & 1) ? (0xEDB88320 ^ (value >>> 1)) : (value >>> 1);
  return value >>> 0;
});
let crc = 0xFFFFFFFF;
for (const b of binary) crc = crcTable[(crc ^ b) & 255] ^ (crc >>> 8);
crc = (crc ^ 0xFFFFFFFF) >>> 0;
const hash = crypto.createHash('sha256').update(binary).digest('hex');
const base64 = binary.toString('base64');
let text = fs.readFileSync(scriptPath, 'utf8');
const marker = /local MODEL_BASE64 = \[=\[\n([\s\S]*?)\n\]=\]/;
const found = text.match(marker);
if (!found) throw new Error('Embedded model marker is missing');
const options = new Set(process.argv.slice(2));
if (options.has('--update')) {
  const lines = base64.match(/.{1,4000}/g).join('\n');
  text = text.replace(marker, () => `local MODEL_BASE64 = [=[\n${lines}\n]=]`);
  text = text.replace(/packName = "DemoRoleplay-[a-f0-9]+\.rbxm"/, `packName = "DemoRoleplay-${hash.slice(0, 8)}.rbxm"`);
  text = text.replace(/packSize = \d+/, `packSize = ${binary.length}`);
  text = text.replace(/packCRC = 0x[0-9A-F]+/, `packCRC = 0x${crc.toString(16).toUpperCase().padStart(8, '0')}`);
  text = text.replace(/source SHA-256 [a-f0-9]{64}/, `source SHA-256 ${sourceHash}`);
  fs.writeFileSync(scriptPath, text);
  console.log('Updated embedded demo model in target script.');
} else {
  if (found[1].replace(/\s/g, '') !== base64) throw new Error('Embedded model differs; run with --update');
  if (!text.includes(`packSize = ${binary.length}`) || !text.includes(`packName = "DemoRoleplay-${hash.slice(0, 8)}.rbxm"`) ||
      !text.includes(`packCRC = 0x${crc.toString(16).toUpperCase().padStart(8, '0')}`) || !text.includes(`source SHA-256 ${sourceHash}`)) {
    throw new Error('Embedded model metadata does not match');
  }
  console.log('Embedded demo model matches the source place.');
}
console.log(`Source SHA-256 ${sourceHash}; model SHA-256 ${hash}; ${binary.length} bytes; ${all.length} instances.`);
