"""Install selected files from an official Godot export-template archive.

The official archive contains templates for every platform. This helper uses HTTP
range requests so CI and local builds only download the selected platform files.
"""

from __future__ import annotations

import argparse
import io
import os
import shutil
import sys
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path


READ_AHEAD_BYTES = 4 * 1024 * 1024
WINDOWS_TEMPLATE_FILES = (
    "windows_debug_x86_64.exe",
    "windows_debug_x86_64_console.exe",
    "windows_release_x86_64.exe",
    "windows_release_x86_64_console.exe",
)
PLATFORM_TEMPLATE_FILES = {
    "windows": WINDOWS_TEMPLATE_FILES,
    "macos": ("macos.zip",),
    "linux": ("linux_debug.x86_64", "linux_release.x86_64"),
}


class HTTPRangeReader(io.RawIOBase):
    def __init__(self, url: str) -> None:
        self.url = url
        request = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(request, timeout=60) as response:
            self.length = int(response.headers["Content-Length"])
            self.url = response.geturl()
        self.position = 0
        self.cache_start = 0
        self.cache = b""

    def readable(self) -> bool:
        return True

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.position

    def seek(self, offset: int, whence: int = io.SEEK_SET) -> int:
        if whence == io.SEEK_SET:
            position = offset
        elif whence == io.SEEK_CUR:
            position = self.position + offset
        elif whence == io.SEEK_END:
            position = self.length + offset
        else:
            raise ValueError(f"Unsupported seek mode: {whence}")
        if position < 0:
            raise ValueError("Cannot seek before the start of the remote file")
        self.position = min(position, self.length)
        return self.position

    def read(self, size: int = -1) -> bytes:
        if self.position >= self.length:
            return b""
        if size is None or size < 0:
            size = self.length - self.position
        size = min(size, self.length - self.position)

        cache_end = self.cache_start + len(self.cache)
        if self.cache_start <= self.position and self.position + size <= cache_end:
            offset = self.position - self.cache_start
            data = self.cache[offset : offset + size]
            self.position += len(data)
            return data

        fetch_size = max(size, READ_AHEAD_BYTES)
        fetch_end = min(self.position + fetch_size, self.length) - 1
        request = urllib.request.Request(
            self.url,
            headers={"Range": f"bytes={self.position}-{fetch_end}"},
        )
        for attempt in range(5):
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    if response.status != 206:
                        raise RuntimeError("The download server did not honor HTTP range requests")
                    downloaded = response.read()
                break
            except (OSError, urllib.error.URLError):
                if attempt == 4:
                    raise
                time.sleep(2**attempt)
        self.cache_start = self.position
        self.cache = downloaded
        data = self.cache[:size]
        self.position += len(data)
        return data


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="4.7.1.stable")
    parser.add_argument("--platform", choices=sorted(PLATFORM_TEMPLATE_FILES), required=True)
    return parser.parse_args()


def template_root() -> Path:
    if sys.platform == "win32":
        app_data = os.environ.get("APPDATA")
        if not app_data:
            raise RuntimeError("APPDATA is not defined")
        return Path(app_data) / "Godot" / "export_templates"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Godot" / "export_templates"
    xdg_data_home = os.environ.get("XDG_DATA_HOME")
    data_home = Path(xdg_data_home) if xdg_data_home else Path.home() / ".local" / "share"
    return data_home / "godot" / "export_templates"


def main() -> None:
    args = parse_args()
    version = args.version
    release_tag = version.replace(".stable", "-stable")
    archive_version = version.replace(".stable", "-stable")
    url = (
        "https://github.com/godotengine/godot-builds/releases/download/"
        f"{release_tag}/Godot_v{archive_version}_export_templates.tpz"
    )
    destination = template_root() / version
    destination.mkdir(parents=True, exist_ok=True)

    print(f"Reading official Godot template archive for {version} ({args.platform})...")
    remote = HTTPRangeReader(url)
    with zipfile.ZipFile(remote) as archive:
        entries = {Path(info.filename).name: info for info in archive.infolist()}
        for filename in PLATFORM_TEMPLATE_FILES[args.platform]:
            archive_info = entries.get(filename)
            if archive_info is None:
                raise RuntimeError(f"Template is missing from the official archive: {filename}")
            target = destination / filename
            if target.exists() and target.stat().st_size == archive_info.file_size:
                print(f"Already installed: {filename}")
                continue
            print(f"Installing {filename}...")
            temporary_target = target.with_suffix(target.suffix + ".part")
            with archive.open(archive_info) as source, temporary_target.open("wb") as output:
                shutil.copyfileobj(source, output, length=1024 * 1024)
            temporary_target.replace(target)

    (destination / "version.txt").write_text(version, encoding="ascii")
    print(f"{args.platform} export templates installed in {destination}")


if __name__ == "__main__":
    main()
