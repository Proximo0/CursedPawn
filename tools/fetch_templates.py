#!/usr/bin/env python3
"""Fetch only the named Godot export templates, without downloading the whole 1.28 GB .tpz.

The .tpz is a zip on GitHub releases, which serves HTTP range requests, so zipfile can read its central directory and
just the members we ask for (web_nothreads_release.zip is 9 MB). Standard library only.

Usage: python3 tools/fetch_templates.py <version> <dest_dir> <glob> [<glob> ...]
  e.g. python3 tools/fetch_templates.py 4.7.2 ~/.local/share/godot/export_templates/4.7.2.stable 'web_nothreads_*'
Globs match file names inside the tpz's templates/ folder; version.txt is always fetched.
Quiet: prints errors, then one "TEMPLATES fetched=<n> mb=<x>" line. Exit 1 on failure or when a glob matches nothing.
"""
import fnmatch
import io
import os
import sys
import urllib.request
import zipfile

URL = "https://github.com/godotengine/godot/releases/download/{v}-stable/Godot_v{v}-stable_export_templates.tpz"


class RangeFile(io.RawIOBase):
    """A read-only, seekable file over HTTP range requests."""

    def __init__(self, url: str) -> None:
        head = urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=60)
        self.url = head.url  # after GitHub's redirect to the release asset host
        self.size = int(head.headers["Content-Length"])
        self.pos = 0
        self.fetched = 0

    def readable(self) -> bool:
        return True

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.pos

    def seek(self, offset: int, whence: int = 0) -> int:
        self.pos = offset if whence == 0 else (self.pos + offset if whence == 1 else self.size + offset)
        return self.pos

    def read(self, n: int = -1) -> bytes:
        if n < 0:
            n = self.size - self.pos
        if n <= 0 or self.pos >= self.size:
            return b""
        end = min(self.pos + n, self.size) - 1
        req = urllib.request.Request(self.url, headers={"Range": "bytes=%d-%d" % (self.pos, end)})
        for attempt in range(4):
            try:
                data = urllib.request.urlopen(req, timeout=120).read()
                break
            except OSError:
                if attempt == 3:
                    raise
        self.pos += len(data)
        self.fetched += len(data)
        return data


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__.strip().splitlines()[3], file=sys.stderr)
        return 1
    version, dest, globs = sys.argv[1], os.path.expanduser(sys.argv[2]), sys.argv[3:]
    try:
        src = RangeFile(URL.format(v=version))
        tpz = zipfile.ZipFile(src)
        names = [i.filename[len("templates/"):] for i in tpz.infolist() if i.filename.startswith("templates/")]
        want = {"version.txt"}
        for g in globs:
            hits = fnmatch.filter(names, g)
            if not hits:
                print("fetch_templates: no template matches %s" % g, file=sys.stderr)
                return 1
            want.update(hits)
        os.makedirs(dest, exist_ok=True)
        for name in sorted(want):
            tmp = os.path.join(dest, name + ".part")
            with open(tmp, "wb") as out:
                out.write(tpz.read("templates/" + name))
            os.replace(tmp, os.path.join(dest, name))
    except (OSError, zipfile.BadZipFile, KeyError) as e:
        print("fetch_templates: %s" % e, file=sys.stderr)
        return 1
    print("TEMPLATES fetched=%d mb=%.1f" % (len(want), src.fetched / 1048576))
    return 0


if __name__ == "__main__":
    sys.exit(main())
