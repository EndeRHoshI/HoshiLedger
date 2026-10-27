"""Version-gated Android publishing. No build or publish work is done by detect."""

import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile

import yaml


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.hoshi.ledger"
REPOSITORY = "EndeRHoshI/HoshiLedger"
SIGNER_SHA256 = "da34691a6f4fe67967e283c0fa03102981584d365188521045e3e16174f40822"
KEY_FILE = Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir())) / "hoshi-release.keystore"


def run(*args, check=True):
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
    if check and result.returncode:
        raise RuntimeError(f"Command failed: {args[0]}\n{result.stderr.strip()}")
    return result


def version(text):
    value = str(yaml.safe_load(text)["version"])
    match = re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\+(0|[1-9]\d*)", value)
    if not match:
        raise ValueError("Use major.minor.patch+revision in pubspec.yaml")
    parts = tuple(map(int, match.groups()))
    if any(value > maximum for value, maximum in zip(parts, (20, 99, 999, 999))):
        raise ValueError("Version component out of range: 20.99.999+999 maximum")
    major, minor, patch, revision = parts
    code = major * 100_000_000 + minor * 1_000_000 + patch * 1000 + revision
    if code <= 0:
        raise ValueError("Android versionCode must be positive")
    name = ".".join(map(str, parts))
    return {"source": value, "parts": parts, "version": name, "versionCode": code, "tag": f"v{name}"}


def current_version():
    return version((ROOT / "pubspec.yaml").read_text())


def detect():
    current = current_version()
    before = os.environ["BEFORE_SHA"]
    if not re.fullmatch(r"[0-9a-f]{40}", before) or set(before) == {"0"}:
        raise ValueError("A previous main commit is required for version comparison")
    previous = version(run("git", "show", f"{before}:pubspec.yaml").stdout)
    changed = current["source"] != previous["source"]
    if changed and current["parts"] <= previous["parts"]:
        raise ValueError("Release version must increase")
    outputs = {
        "changed": str(changed).lower(),
        "version": current["version"],
        "tag": current["tag"],
    }
    if os.environ.get("GITHUB_OUTPUT"):
        with Path(os.environ["GITHUB_OUTPUT"]).open("a") as output:
            for key, value in outputs.items():
                output.write(f"{key}={value}\n")
    print(json.dumps(outputs))


def signing():
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("Signing restoration is restricted to GitHub Actions")
    names = ("ANDROID_KEYSTORE_BASE64", "ANDROID_STORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD")
    if any(not os.environ.get(name) for name in names):
        raise ValueError("Configure all four Android signing secrets before publishing")
    KEY_FILE.write_bytes(base64.b64decode(os.environ[names[0]], validate=True))
    KEY_FILE.chmod(0o600)
    properties = {
        "storeFile": str(KEY_FILE),
        "storePassword": os.environ[names[1]],
        "keyAlias": os.environ[names[2]],
        "keyPassword": os.environ[names[3]],
    }
    def escape(value):
        data = value.encode("utf-16-be")
        return "".join(f"\\u{int.from_bytes(data[index:index + 2], 'big'):04x}" for index in range(0, len(data), 2))
    path = ROOT / "android/key.properties"
    path.write_text("".join(f"{key}={escape(value)}\n" for key, value in properties.items()))
    path.chmod(0o600)


def prepare():
    current = current_version()
    source = ROOT / "build/app/outputs/apk/release/app-release.apk"
    metadata = json.loads((source.parent / "output-metadata.json").read_text())
    elements = metadata["elements"]
    if metadata["applicationId"] != PACKAGE or len(elements) != 1:
        raise ValueError("Unexpected APK package or split APK output")
    if elements[0]["versionName"] != current["version"] or elements[0]["versionCode"] != current["versionCode"]:
        raise ValueError("APK version does not match pubspec.yaml")
    tools = Path(os.environ["ANDROID_HOME"]) / "build-tools"
    candidates = sorted(
        (path for path in tools.glob("*/apksigner") if re.fullmatch(r"\d+\.\d+\.\d+", path.parent.name)),
        key=lambda path: tuple(map(int, path.parent.name.split("."))),
    )
    if not candidates:
        raise ValueError("No stable Android build-tools apksigner found")
    certificate = run(str(candidates[-1]), "verify", "--print-certs", str(source)).stdout
    fingerprints = re.findall(
        r"^(?:Signer(?: #\d+)?(?: \([^\r\n]*\))?|V[1-4](?:\.\d+)? Signer:)"
        r" certificate SHA-256 digest:[ \t]*([0-9a-fA-F]{64})[ \t]*$",
        certificate, re.M,
    )
    if not fingerprints:
        raise ValueError(f"Cannot read APK signing certificate from apksigner output:\n{certificate.strip()}")
    fingerprints = {fingerprint.lower() for fingerprint in fingerprints}
    print(f"APK signing certificate SHA-256: {', '.join(sorted(fingerprints))}", flush=True)
    if fingerprints != {SIGNER_SHA256}:
        raise ValueError(f"APK signature differs from the installed v1.0.1 signing key ({SIGNER_SHA256})")
    with zipfile.ZipFile(source) as apk:
        if any(name.lower().endswith(".csv") for name in apk.namelist()):
            raise ValueError("APK must not contain migration CSV files")
    output = ROOT / "release"
    output.mkdir(exist_ok=True)
    filename = f"HoshiLedger-{current['tag']}.apk"
    target = output / filename
    shutil.copyfile(source, target)
    with target.open("rb") as package:
        digest = hashlib.file_digest(package, "sha256").hexdigest()
    (output / f"{filename}.sha256").write_text(f"{digest}  {filename}\n")
    sha = run("git", "rev-parse", "HEAD").stdout.strip()
    previous = run("git", "describe", "--tags", "--abbrev=0", f"{sha}^", check=False)
    revision_range = f"{previous.stdout.strip()}..{sha}" if previous.returncode == 0 else sha
    subjects = run("git", "log", "-50", "--format=%s", revision_range).stdout.splitlines()
    notes = "\n".join(f"- {subject}" for subject in subjects)
    (output / "latest.json").write_text(json.dumps({
        "schemaVersion": 1,
        "packageName": PACKAGE,
        "version": current["version"],
        "versionCode": current["versionCode"],
        "apkUrl": f"https://github.com/{REPOSITORY}/releases/download/{current['tag']}/{filename}",
        "sha256": digest,
        "size": target.stat().st_size,
        "notes": notes,
        "commitSha": sha,
    }, ensure_ascii=False, indent=2) + "\n")


def api(path, method="GET", payload=None, missing_ok=False, paginate=False):
    args = ["gh", "api", path, "--method", method]
    if paginate:
        args.extend(["--paginate", "--slurp"])
    with tempfile.TemporaryDirectory() as directory:
        if payload is not None:
            body = Path(directory) / "body.json"
            body.write_text(json.dumps(payload))
            args.extend(["--input", str(body)])
        result = run(*args, check=False)
    if result.returncode:
        if missing_ok and "HTTP 404" in result.stderr:
            return None
        raise RuntimeError(f"GitHub API request failed: {result.stderr.strip()}")
    return json.loads(result.stdout) if result.stdout.strip() else None


def wait_for_publish_turn():
    # GitHub concurrency replaces pending runs. Wait here so every version keeps its release job.
    number = int(os.environ["GITHUB_RUN_NUMBER"])
    deadline = time.monotonic() + 30 * 60
    while True:
        earlier = []
        for status in ("queued", "in_progress"):
            pages = api(
                f"repos/{REPOSITORY}/actions/workflows/android-release.yml/runs?branch=main&status={status}&per_page=100",
                paginate=True,
            )
            earlier.extend(run for page in pages for run in page["workflow_runs"]
                           if run["run_number"] < number)
        if not earlier:
            return
        if time.monotonic() >= deadline:
            raise TimeoutError("Earlier release runs are still active; rerun this job after they finish")
        print(f"Waiting for earlier release run {min(run['run_number'] for run in earlier)}", flush=True)
        time.sleep(15)


def publish():
    if os.environ.get("GITHUB_REPOSITORY") != REPOSITORY or os.environ.get("GITHUB_REF") != "refs/heads/main":
        raise ValueError("Publishing is restricted to the source repository main branch")
    if api(f"repos/{REPOSITORY}")["private"]:
        raise ValueError("Public Releases are required for the in-app updater")
    wait_for_publish_turn()
    current = current_version()
    sha = run("git", "rev-parse", "HEAD").stdout.strip()
    if sha != os.environ.get("GITHUB_SHA"):
        raise ValueError("Checkout does not match the triggering commit")
    tag = current["tag"]
    existing = run("git", "rev-parse", "--verify", f"refs/tags/{tag}^{{commit}}", check=False)
    if existing.returncode == 0 and existing.stdout.strip() != sha:
        raise ValueError("Tag already points to a different commit")
    if existing.returncode != 0:
        run("git", "config", "user.name", "github-actions[bot]")
        run("git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
        run("git", "tag", "-a", tag, sha, "-m", f"Release {current['version']}")
    run("git", "push", "origin", f"refs/tags/{tag}")
    release = api(f"repos/{REPOSITORY}/releases/tags/{tag}", missing_ok=True)
    output = ROOT / "release"
    files = sorted(output.glob("*"))
    required = {path.name for path in files}
    if release is not None and not release["draft"]:
        if not required.issubset({asset["name"] for asset in release["assets"]}):
            raise ValueError("Published Release is missing assets; refusing to replace published files")
        print(f"{tag} is already published")
        return
    notes = json.loads((output / "latest.json").read_text())["notes"]
    if release is None:
        release = api(f"repos/{REPOSITORY}/releases", "POST", {
            "tag_name": tag, "target_commitish": sha,
            "name": tag, "body": notes, "draft": True,
        })
    run("gh", "release", "upload", tag, "--repo", REPOSITORY, "--clobber", *map(str, files))
    latest = api(f"repos/{REPOSITORY}/releases/latest", missing_ok=True)
    latest_parts = tuple(map(int, latest["tag_name"].lstrip("v").split("."))) if latest else ()
    api(f"repos/{REPOSITORY}/releases/{release['id']}", "PATCH", {
        "draft": False, "make_latest": "true" if current["parts"] > latest_parts else "false",
    })
    print(f"Published {tag}")


def cleanup():
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("Signing cleanup is restricted to GitHub Actions")
    KEY_FILE.unlink(missing_ok=True)
    (ROOT / "android/key.properties").unlink(missing_ok=True)


if __name__ == "__main__":
    commands = {"detect": detect, "signing": signing, "prepare": prepare, "publish": publish, "cleanup": cleanup}
    try:
        commands[sys.argv[1]]()
    except Exception as error:
        print(f"Release stopped: {error}", file=sys.stderr)
        sys.exit(1)
