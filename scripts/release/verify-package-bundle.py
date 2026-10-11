#!/usr/bin/env python3
"""Verify the tested package cohort before an offline image build."""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess


def load_lock(path):
    packages = []
    for line in path.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        name, version, arch, digest, origin = line.split("\t")
        if not re.fullmatch(r"[a-z0-9][a-z0-9+.-]*", name):
            raise ValueError("invalid package name")
        if not re.fullmatch(r"[a-zA-Z0-9.+:~_-]+", version):
            raise ValueError("invalid package version")
        if arch not in ("arm64", "all") or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("invalid architecture or checksum")
        packages.append((name, version, arch, digest, origin))
    if not packages or len({p[0] for p in packages}) != len(packages):
        raise ValueError("empty or duplicate package lock")
    return packages


def filename(package):
    name, version, arch, *_ = package
    return f"{name}_{version}_{arch}.deb"


def verify_bundle(packages, bundle):
    expected = {filename(p) for p in packages}
    found = {p.name for p in bundle.glob("*.deb")}
    if found != expected:
        raise ValueError(f"package set differs: missing={sorted(expected - found)}, extra={sorted(found - expected)}")
    for package in packages:
        path = bundle / filename(package)
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"not a regular archive: {path.name}")
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        if digest.hexdigest() != package[3]:
            raise ValueError(f"checksum differs: {path.name}")
        fields = subprocess.check_output(
            ["dpkg-deb", "--show", "--showformat=${Package}\t${Version}\t${Architecture}", str(path)],
            text=True,
        ).split("\t")
        if tuple(fields) != package[:3]:
            raise ValueError(f"package metadata differs: {path.name}")


def verify_installed(packages, root):
    for name, version, arch, *_ in packages:
        fields = subprocess.check_output(
            ["dpkg-query", f"--admindir={root / 'var/lib/dpkg'}", "--show",
             "--showformat=${Package}\t${Version}\t${Architecture}\t${Status}", name], text=True,
        ).split("\t")
        if fields != [name, version, arch, "install ok installed"]:
            raise ValueError(f"installed package differs: {name}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lock", type=Path, default=Path(__file__).with_name("validated-packages.lock"))
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--root", type=Path)
    args = parser.parse_args()
    if not args.bundle and not args.root:
        parser.error("provide --bundle and/or --root")
    try:
        packages = load_lock(args.lock)
        if args.bundle:
            verify_bundle(packages, args.bundle)
        if args.root:
            verify_installed(packages, args.root)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"E: {error}\n")
    print(f"I: verified {len(packages)} locked packages")


if __name__ == "__main__":
    main()
