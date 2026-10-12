#!/usr/bin/env python3
"""Fail publication if the feed does not reference the final signed package."""
import base64
import plistlib
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

def validate(feed, app, archive):
    with (app / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    ns = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
    items = ET.parse(feed).findall("./channel/item")
    versions = [item.findtext(ns + "version", "") for item in items]
    current = info["CFBundleVersion"]
    if not versions or versions[0] != current or len(set(versions)) != len(versions):
        raise ValueError("Expected one current update first, followed by distinct older updates")
    try:
        numeric = [tuple(int(part) for part in version.split(".")) for version in versions]
    except ValueError as error:
        raise ValueError("Update build versions must be numeric") from error
    if any(version >= numeric[0] for version in numeric[1:]):
        raise ValueError("Additional feed entries must be older compatibility releases")
    item = items[0]
    enclosure = item.find("enclosure")
    expected = f'https://github.com/xiaotwu/Muses-Polyhymnia/releases/download/v{info["CFBundleShortVersionString"]}/{archive.name}'
    if (enclosure is None or enclosure.get("url") != expected
            or enclosure.get("length") != str(archive.stat().st_size)
            or item.findtext(ns + "shortVersionString") != info["CFBundleShortVersionString"]
            or item.findtext(ns + "minimumSystemVersion") != info["LSMinimumSystemVersion"]
            or len(base64.b64decode(enclosure.get(ns + "edSignature", ""), validate=True)) != 64
            or not info.get("SUPublicEDKey")
            or not info.get("SURequireSignedFeed")):
        raise ValueError("Feed does not match the signed application and archive")


if __name__ == "__main__":
    try:
        validate(*map(Path, sys.argv[1:]))
    except ValueError as error:
        raise SystemExit(str(error))
