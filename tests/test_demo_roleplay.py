"""Offline checks for the embedded demo Roleplay model and its actual Luau backend.

Run: LUAU=/path/to/luau python3 -m unittest discover -s tests -v
Optionally set DEMO_MESHES_ZIP=/path/to/Meshes.zip to test all real archive entries.
The Luau binary is optional; byte/metadata checks still run without it. Roblox-specific
engine loading, rendering and network behavior cannot be verified by these mocks.
"""
import base64
import hashlib
import io
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import unittest
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "29acde6377368455288b7247f8622f2d.txt"
SOURCE = ROOT / "_GameFileDEMO.rbxl.txt"
LUAU = os.environ.get("LUAU") or shutil.which("luau")
TEXT = SCRIPT.read_text(encoding="utf-8")


def lua_bytes(data):
    return '"' + ''.join('\\%03d' % byte for byte in data) + '"'


def fixture(entries, compression=zipfile.ZIP_STORED):
    out = io.BytesIO()
    with zipfile.ZipFile(out, "w", compression=compression) as archive:
        for name, contents in entries:
            archive.writestr(name, contents)
    return out.getvalue()


def run_luau(code):
    if not LUAU:
        raise unittest.SkipTest("set LUAU to a Luau CLI to run backend mocks")
    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp) / "test.luau"
        path.write_text(code, encoding="utf-8")
        result = subprocess.run([LUAU, str(path)], text=True, capture_output=True, timeout=120)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        return result.stdout


def zip_reader():
    start = TEXT.index("local DemoZip = (function()", TEXT.index("-- BEGIN DEMO ZIP READER"))
    end = TEXT.index("-- END DEMO ZIP READER", start)
    return TEXT[start:end]


class DemoRoleplayTests(unittest.TestCase):
    def test_embedded_model_metadata(self):
        block = re.search(r'local MODEL_BASE64 = \[=\[\n([\s\S]*?)\n\]=\]', TEXT)
        self.assertIsNotNone(block)
        model = base64.b64decode(re.sub(r'\s', '', block.group(1)), validate=True)
        self.assertTrue(model.startswith(b'<roblox!'))
        expected_size = int(re.search(r'packSize = (\d+)', TEXT).group(1))
        expected_crc = int(re.search(r'packCRC = 0x([A-F0-9]+)', TEXT).group(1), 16)
        self.assertEqual(len(model), expected_size)
        self.assertEqual(zlib.crc32(model), expected_crc)
        model_hash = hashlib.sha256(model).hexdigest()
        self.assertIn('packName = "DemoRoleplay-' + model_hash[:8] + '.rbxm"', TEXT)
        source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
        self.assertIn('source SHA-256 ' + source_hash, TEXT)
        self.assertNotIn('emotepack.rbxm', TEXT)
        self.assertNotIn('extra.rbxm', TEXT)

    def test_zip_reader_stored_deflate_and_safety(self):
        stored = fixture([('Meshes/one.mesh', b'abc')])
        compressed = fixture([('one.mesh', b'hello!' * 10000)], zipfile.ZIP_DEFLATED)
        traversal = fixture([('../escape', b'bad')])
        duplicate = fixture([('Meshes/x', b'a'), ('meshes/X', b'b')])
        crc_bad = bytearray(stored)
        name_len, extra_len = struct.unpack_from('<HH', crc_bad, 26)
        crc_bad[30 + name_len + extra_len] ^= 1
        symlink_info = zipfile.ZipInfo('Meshes/link')
        symlink_info.create_system = 3
        symlink_info.external_attr = 0o120777 << 16
        symlink_out = io.BytesIO()
        with zipfile.ZipFile(symlink_out, 'w') as archive:
            archive.writestr(symlink_info, 'target')
        values = '\n'.join(f'local {name} = {lua_bytes(value)}' for name, value in [
            ('stored', stored), ('deflated', compressed), ('traversal', traversal),
            ('duplicate', duplicate), ('crc_bad', crc_bad), ('symlink', symlink_out.getvalue())])
        checks = '''
local a=DemoZip.inspect(stored,"Meshes");assert(#a==1 and a[1].path=="Meshes/one.mesh");assert(DemoZip.extract(stored,a[1])=="abc")
local b=DemoZip.inspect(deflated,"Meshes");assert(#DemoZip.extract(deflated,b[1])==60000)
assert(not pcall(DemoZip.inspect,traversal,"Meshes"));assert(not pcall(DemoZip.inspect,duplicate,"Meshes"));assert(not pcall(DemoZip.inspect,symlink,"Meshes"))
local c=DemoZip.inspect(crc_bad,"Meshes");assert(not pcall(DemoZip.extract,crc_bad,c[1]));assert(not DemoZip.safeName("Meshes/../bad"));assert(not DemoZip.safeName("Meshes\\\\bad"))
print("ZIP stored, deflate, CRC and safety checks passed")
'''
        self.assertIn('checks passed', run_luau(zip_reader() + '\n' + values + checks))

    def test_backend_with_mocked_roblox(self):
        start = TEXT.index('-- [06_demo_roleplay.lua]')
        end = TEXT.index('\nend)()\n\t\tSystem.tailVariables', start)
        backend = TEXT[start:end]
        backend = re.sub(r'local MODEL_BASE64 = \[=\[\n[\s\S]*?\n\]=\]',
                         'local MODEL_BASE64 = "ZGF0YQ=="', backend)
        # Small, known bytes let the fixture exercise actual cache verification/recovery.
        backend = backend.replace('packSize = 1000815', 'packSize = 4', 1)
        backend = backend.replace('packCRC = 0xA300BDCB', 'packCRC = 0xADF3F363', 1)
        mock = (ROOT / 'tests/demo_roleplay_mock.luau').read_text(encoding='utf-8')
        archive = fixture([('Meshes/OX_test.mesh', b'data')])
        mock = mock.replace('__MESH_ZIP__', lua_bytes(archive), 1)
        core_start = TEXT.index('-- Demo Roleplay: shared timing and pose interpolation helpers.')
        core_end = TEXT.index('-- [06_demo_roleplay.lua]', core_start)
        core = TEXT[core_start:core_end] + '\nRP.now = function() return now end\n'
        mock = mock.replace('-- INSERT ACTUAL DEMO BACKEND HERE', core + backend, 1)
        self.assertIn('cleanup passed', run_luau(mock))

    @unittest.skipUnless(os.environ.get('DEMO_MESHES_ZIP'), 'set DEMO_MESHES_ZIP for the real archive')
    def test_real_meshes_zip(self):
        archive = Path(os.environ['DEMO_MESHES_ZIP']).read_bytes()
        encoded = base64.b64encode(archive).decode()
        # A buffer-based decoder avoids a 15MB Lua table of single-byte strings.
        decoder = '''
local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" local lut={} for i=1,#chars do lut[string.byte(chars,i)]=i-1 end
local buf=buffer.create(math.floor(#b64*3/4)) local out=0
for i=1,#b64,4 do local a,b,c,d=b64:byte(i,i+3) a,b=lut[a],lut[b];c,d=lut[c],lut[d] local v=a*262144+b*4096+(c or 0)*64+(d or 0);buffer.writeu8(buf,out,math.floor(v/65536)%256);out+=1;if c then buffer.writeu8(buf,out,math.floor(v/256)%256);out+=1 end;if d then buffer.writeu8(buf,out,v%256);out+=1 end end
local bytes=buffer.readstring(buf,0,out);local entries=DemoZip.inspect(bytes,"Meshes");assert(#entries>0);local total=0
for _,entry in ipairs(entries) do local body=DemoZip.extract(bytes,entry);total+=#body end
print("real ZIP verified",#entries,total)
'''
        self.assertIn('real ZIP verified', run_luau(zip_reader() + '\nlocal b64=[=[' + encoded + ']=]\n' + decoder))


if __name__ == '__main__':
    unittest.main()
