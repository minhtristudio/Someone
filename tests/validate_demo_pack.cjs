#!/usr/bin/env node
/* Compare all extracted keyframes/poses and character joints with the place.
 * Install the pinned development tools noted in tools/build_demo_roleplay_pack.cjs
 * plus rbx-reader@1.5.10, then: node tests/validate_demo_pack.cjs
 * Optional: DEMO_MESHES_ZIP=/path/to/Meshes.zip checks every referenced mesh.
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const childProcess = require('node:child_process');
const { parseBuffer } = require('rbx-reader');
const root = path.resolve(__dirname, '..');
const script = fs.readFileSync(path.join(root, '29acde6377368455288b7247f8622f2d.txt'), 'utf8');
const encoded = script.match(/local MODEL_BASE64 = \[=\[\n([\s\S]*?)\n\]=\]/);
if (!encoded) throw new Error('Embedded model marker missing');
const source = Object.values(parseBuffer(fs.readFileSync(path.join(root, '_GameFileDEMO.rbxl.txt'))).instances);
const packed = Object.values(parseBuffer(Buffer.from(encoded[1].replace(/\s/g, ''), 'base64')).instances);
const base = 'ServerScriptService.MainScript.Trasnfer_Services.ReplicatedStorage.';
function find(all, full) {
  const instance = all.find(i => i.getFullName() === full);
  if (!instance) throw new Error('Missing instance: ' + full);
  return instance;
}
function descendants(instance) {
  const out = [], stack = [instance];
  while (stack.length) { const current = stack.pop(); out.push(current); stack.push(...current.Children); }
  return out;
}
function val(instance, property) { return instance.Properties[property]?.value; }
function close(a, b, description) {
  if (typeof a === 'number' && typeof b === 'number') {
    if (Math.abs(a - b) <= 1e-6) return;
  } else if (Array.isArray(a) && Array.isArray(b) && a.length === b.length) {
    for (let i = 0; i < a.length; i++) close(a[i], b[i], description + '[' + i + ']');
    return;
  } else if (a === b) return;
  throw new Error(`${description}: ${JSON.stringify(a)} != ${JSON.stringify(b)}`);
}
function sequences(parent) {
  const prefix = parent.getFullName() + '.';
  return descendants(parent).filter(x => x.ClassName === 'KeyframeSequence').map(seq => {
    const poses = [];
    function walk(node, time, posePath) {
      for (const pose of node.Children) if (pose.ClassName === 'Pose') {
        const next = posePath + '/' + pose.Name;
        poses.push({ time, path: next, cf: val(pose, 'CFrame'), weight: val(pose, 'Weight'),
          style: val(pose, 'EasingStyle'), direction: val(pose, 'EasingDirection') });
        walk(pose, time, next);
      }
    }
    for (const key of seq.Children.filter(x => x.ClassName === 'Keyframe')) walk(key, val(key, 'Time'), '');
    poses.sort((a, b) => a.time - b.time || a.path.localeCompare(b.path));
    return [seq.getFullName().slice(prefix.length), { loop: val(seq, 'Loop'), poses }];
  });
}
let totalSequences = 0, totalPoses = 0;
for (const [from, to] of [['Animations.Scenes', 'Scenes'], ['Animations.Characters.Player', 'Solo.Player'], ['Animations.Characters.Human', 'Solo.Human']]) {
  const a = new Map(sequences(find(source, base + from)));
  const b = new Map(sequences(find(packed, 'DemoRoleplay.' + to)));
  close(a.size, b.size, from + ' count');
  for (const [name, left] of a) {
    const right = b.get(name);
    if (!right) throw new Error(`Missing sequence ${from}.${name}`);
    close(left.loop, right.loop, name + ' loop');
    close(left.poses.length, right.poses.length, name + ' pose count');
    left.poses.forEach((pose, index) => {
      for (const key of ['time', 'path', 'cf', 'weight', 'style', 'direction']) close(pose[key], right.poses[index][key], name + ' ' + pose.path + ' ' + key);
    });
    totalSequences++; totalPoses += left.poses.length;
  }
}
function motorMap(parent) {
  const prefix = parent.getFullName() + '.';
  const relative = instance => instance ? instance.getFullName().slice(prefix.length) : null;
  return new Map(descendants(parent).filter(x => x.ClassName === 'Motor6D').map(m => [relative(m), {
    p0: relative(val(m, 'Part0')), p1: relative(val(m, 'Part1')), c0: val(m, 'C0'), c1: val(m, 'C1'),
  }]));
}
const left = motorMap(find(source, base + 'Characters'));
const right = motorMap(find(packed, 'DemoRoleplay.Characters'));
close(left.size, right.size, 'character Motor6D count');
for (const [name, joint] of left) {
  const other = right.get(name);
  if (!other) throw new Error('Missing Motor6D ' + name);
  for (const key of ['p0', 'p1', 'c0', 'c1']) close(joint[key], other[key], name + ' ' + key);
}
// Compare body/prop geometry and bone offsets as multisets: many demo siblings
// deliberately share a Name. Float quantization only suppresses writer roundoff.
function normal(value) {
  if (typeof value === 'number') return Math.abs(value) < 1e-6 ? 0 : Math.round(value * 100000) / 100000;
  if (Array.isArray(value)) return value.map(normal);
  return value;
}
function visualMap(parent) {
  const prefix = parent.getFullName() + '.';
  const properties = {
    Part: ['size', 'CFrame', 'Color3uint8', 'Material', 'Transparency', 'Reflectance'],
    MeshPart: ['size', 'InitialSize', 'CFrame', 'Color3uint8', 'Material', 'Transparency', 'Reflectance', 'MeshId', 'TextureID', 'DoubleSided', 'HasSkinnedMesh'],
    Bone: ['CFrame'],
    Decal: ['Texture', 'Transparency'],
    Texture: ['Texture', 'Transparency'],
  };
  const groups = new Map();
  for (const obj of descendants(parent)) {
    const fields = properties[obj.ClassName];
    if (!fields) continue;
    const name = obj.getFullName().slice(prefix.length) + ':' + obj.ClassName;
    const entry = JSON.stringify(fields.map(field => normal(val(obj, field))));
    if (!groups.has(name)) groups.set(name, []);
    groups.get(name).push(entry);
  }
  for (const entries of groups.values()) entries.sort();
  return groups;
}
let visuals = 0;
const visualRoots = [['Characters', 'Characters']];
for (const scene of find(source, base + 'Animations.Scenes').Children) {
  if (scene.Children.some(child => child.Name === 'Rig')) visualRoots.push(['Animations.Scenes.' + scene.Name + '.Rig', 'Scenes.' + scene.Name + '.Rig']);
}
for (const [from, to] of visualRoots) {
  const original = visualMap(find(source, base + from));
  const rebuilt = visualMap(find(packed, 'DemoRoleplay.' + to));
  close(original.size, rebuilt.size, from + ' visual group count');
  for (const [name, entries] of original) {
    const out = rebuilt.get(name);
    if (!out || JSON.stringify(entries) !== JSON.stringify(out)) throw new Error(`Visual properties changed: ${from}.${name}`);
    visuals += entries.length;
  }
}
console.log(`Compared ${totalSequences} sequences / ${totalPoses} poses, ${left.size} character joints and ${visuals} body/scene visuals.`);
if (process.env.DEMO_MESHES_ZIP) {
  const zip = process.env.DEMO_MESHES_ZIP;
  const py = 'import sys,json,zipfile\nwith zipfile.ZipFile(sys.argv[1]) as z: print(json.dumps(z.namelist()))\n';
  const entries = JSON.parse(childProcess.execFileSync('python3', ['-c', py, zip], { encoding: 'utf8' }));
  const paths = new Set(entries.map(x => x.toLowerCase().replace(/^meshes\//, '')));
  const needed = new Set();
  for (const obj of packed) {
    const mesh = val(obj, 'MeshId');
    if (typeof mesh === 'string' && /^rbxasset:\/\/meshes\//i.test(mesh)) needed.add(mesh.replace(/^rbxasset:\/\/meshes\//i, '').toLowerCase());
  }
  const missing = [...needed].filter(x => !paths.has(x));
  if (missing.length) throw new Error('Missing mesh paths: ' + missing.join(', '));
  console.log(`Found all ${needed.size} referenced local meshes in ${path.basename(zip)}.`);
}
