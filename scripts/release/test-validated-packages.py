#!/usr/bin/env python3
"""Small Linux regression: real Debian archives, no package installation."""
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("bundle", HERE / "verify-package-bundle.py")
bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)


def rejects(callback):
    try:
        callback()
    except ValueError:
        return
    raise AssertionError("invalid input was accepted")


with tempfile.TemporaryDirectory(prefix="a50-package-check-") as directory:
    root = Path(directory)
    payload = root / "payload/DEBIAN"
    payload.mkdir(parents=True)
    control = "Package: a50-check\nVersion: 1.0\nArchitecture: arm64\nMaintainer: Test <test@example.invalid>\nDescription: Offline verifier regression\n"
    (payload / "control").write_text(control)
    archives = root / "bundle"
    archives.mkdir()
    archive = archives / "a50-check_1.0_arm64.deb"
    subprocess.run(["dpkg-deb", "--build", "--root-owner-group", str(payload.parent), str(archive)], check=True, stdout=subprocess.DEVNULL)
    original = archive.read_bytes()
    digest = hashlib.sha256(original).hexdigest()
    lock = root / "packages.lock"
    row = f"a50-check\t1.0\tarm64\t{digest}\ttest\n"
    lock.write_text(row)
    cohort = bundle.load_lock(lock)
    bundle.verify_bundle(cohort, archives)
    archive.rename(archives / "missing.deb")
    rejects(lambda: bundle.verify_bundle(cohort, archives))
    (archives / "missing.deb").rename(archive)
    archive.write_bytes(original + b"corrupt")
    rejects(lambda: bundle.verify_bundle(cohort, archives))
    archive.write_bytes(original)
    extra = archives / "unexpected.deb"
    extra.write_bytes(original)
    rejects(lambda: bundle.verify_bundle(cohort, archives))
    extra.unlink()
    wrong_version = ("a50-check", "2.0", "arm64", digest, "test")
    archive.rename(archives / bundle.filename(wrong_version))
    rejects(lambda: bundle.verify_bundle([wrong_version], archives))
    lock.write_text(row * 2)
    rejects(lambda: bundle.load_lock(lock))
    lock.write_text(row.replace("a50-check\t", "../escape\t"))
    rejects(lambda: bundle.load_lock(lock))
    status = root / "rootfs/var/lib/dpkg"
    status.mkdir(parents=True)
    installed = control.replace("Version:", "Status: install ok installed\nVersion:") + "\n"
    (status / "status").write_text(installed)
    bundle.verify_installed(cohort, root / "rootfs")
    (status / "status").write_text(installed.replace("Version: 1.0", "Version: 0.9"))
    rejects(lambda: bundle.verify_installed(cohort, root / "rootfs"))
print("PASS: archive identity, corruption, missing/extra packages, metadata, duplicate/path input and installed-version regression")
