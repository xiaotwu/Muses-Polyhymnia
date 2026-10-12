import base64
import importlib.util
import plistlib
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("validate_update_feed", ROOT / "Scripts/validate-update-feed.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
NS = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


class UpdateFeedTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="muses-update-feed-")
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.app = self.work / "Muses.app"
        (self.app / "Contents").mkdir(parents=True)
        self.archive = self.work / "Muses-0.6.0.dmg"
        self.archive.write_bytes(b"current update")
        self.feed = self.work / "appcast.xml"
        self.info = {"CFBundleVersion": "20261012.1", "CFBundleShortVersionString": "0.6.0",
                     "LSMinimumSystemVersion": "26.0", "SUPublicEDKey": "test-public-key",
                     "SURequireSignedFeed": True}
        (self.app / "Contents/Info.plist").write_bytes(plistlib.dumps(self.info))
        self.tree = ET.fromstring('<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel/></rss>')
        self.channel = self.tree.find("channel")
        self.add_item("0.6.0", "20261012.1", "26.0", len(b"current update"))
        self.add_item("0.5.11", "20261001.5", "14.0", len(b"older update"))

    def add_item(self, version, build, minimum, length):
        item = ET.SubElement(self.channel, "item")
        for name, value in [("version", build), ("shortVersionString", version), ("minimumSystemVersion", minimum)]:
            ET.SubElement(item, NS + name).text = value
        ET.SubElement(item, "enclosure", {"url": f"https://github.com/xiaotwu/Muses-Polyhymnia/releases/download/v{version}/Muses-{version}.dmg",
                                         "length": str(length), NS + "edSignature": base64.b64encode(bytes(64)).decode()})

    def validate(self):
        self.feed.write_bytes(ET.tostring(self.tree))
        module.validate(self.feed, self.app, self.archive)

    def test_retains_older_system_release(self):
        self.validate()
        self.assertEqual(self.channel[1].findtext(NS + "minimumSystemVersion"), "14.0")

    def test_duplicate_current_build_is_rejected(self):
        self.add_item("0.6.0", "20261012.1", "26.0", len(b"current update"))
        with self.assertRaises(ValueError):
            self.validate()

    def test_old_release_cannot_be_first(self):
        older = self.channel[1]
        self.channel.remove(older)
        self.channel.insert(0, older)
        with self.assertRaises(ValueError):
            self.validate()

    def test_newer_retained_build_is_rejected(self):
        self.channel[1].find(NS + "version").text = "20261013.1"
        with self.assertRaises(ValueError):
            self.validate()

    def test_current_archive_and_system_metadata_must_match(self):
        enclosure = self.channel[0].find("enclosure")
        for field, value in [("length", "1"), ("url", enclosure.get("url").replace("0.6.0", "0.5.11"))]:
            original = enclosure.get(field)
            enclosure.set(field, value)
            with self.assertRaises(ValueError):
                self.validate()
            enclosure.set(field, original)
        self.channel[0].find(NS + "minimumSystemVersion").text = "14.0"
        with self.assertRaises(ValueError):
            self.validate()

    def test_crypto_selects_current_archive_and_rejects_tampering(self):
        fixture = self.work / "sign-fixture.swift"
        fixture.write_text(r'''
import Foundation
import CryptoKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 7, count: 32))
let current = Data("current update".utf8)
let old = Data("older update".utf8)
let currentSignature = try key.signature(for: current).base64EncodedString()
let oldSignature = try key.signature(for: old).base64EncodedString()
let text = """
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
<item><sparkle:version>20261012.1</sparkle:version><enclosure url="https://github.com/xiaotwu/Muses-Polyhymnia/releases/download/v0.6.0/Muses-0.6.0.dmg" sparkle:edSignature="\(currentSignature)"/></item>
<item><sparkle:version>20261001.5</sparkle:version><enclosure url="https://github.com/xiaotwu/Muses-Polyhymnia/releases/download/v0.5.11/Muses-0.5.11.dmg" sparkle:edSignature="\(oldSignature)"/></item>
</channel></rss>

"""
var data = Data(text.utf8)
let signature = try key.signature(for: data).base64EncodedString()
data.append(Data("<!-- sparkle-signatures:\nedSignature: \(signature)\nlength: \(data.count)\n-->\n".utf8))
try data.write(to: root.appendingPathComponent("appcast.xml"))
let info: [String: Any] = ["CFBundleShortVersionString": "0.6.0", "SUPublicEDKey": key.publicKey.rawRepresentation.base64EncodedString()]
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: root.appendingPathComponent("Muses.app/Contents/Info.plist"))
''')
        subprocess.run(["swift", str(fixture), str(self.work)], check=True, capture_output=True)
        command = ["swift", str(ROOT / "Scripts/verify-update-signatures.swift"), str(self.app), str(self.feed)]
        for args in [command, command + [str(self.archive)]]:
            result = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.archive.write_bytes(b"changed update")
        result = subprocess.run(command + [str(self.archive)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Archive signature", result.stderr)
        self.feed.write_bytes(self.feed.read_bytes().replace(b"20261001.5", b"20261001.4"))
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Feed signature", result.stderr)


if __name__ == "__main__":
    unittest.main()
