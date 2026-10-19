"""Uploads the Flyers v3 FBX files to Roblox through Open Cloud (group 11116787) as Model assets.

    zsh -i -c 'python3 tools/blender/upload_flyers_v3.py [ids]'

Reads the key from ROBLOX_ASSETS_KEY (never printed or logged). Writes the resulting asset ids and the
FBX SHA256 to assets/blender/round_cosmetics/flyers_v3/roblox_assets.json. An id whose FBX hash is
unchanged since its last upload is skipped.
"""
import hashlib
import json
import os
import sys
import time
import urllib.request
import uuid

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(REPO, "assets", "blender", "round_cosmetics", "flyers_v3")
GROUP = "11116787"
IDS = ["skyboard", "cloud_cushion", "rocket_skiff", "prism_ray"]
API = "https://apis.roblox.com/assets/v1"


def request(method, url, key, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key, **(headers or {})})
    with urllib.request.urlopen(req, timeout=120) as res:
        return json.loads(res.read().decode())


def upload(gid, key):
    path = os.path.join(OUT, gid, gid + ".fbx")
    data = open(path, "rb").read()
    meta = {
        "assetType": "Model",
        "displayName": "GlassClash Flyer v3 " + gid,
        "description": "Glass Clash flyer v3 (original art).",
        "creationContext": {"creator": {"groupId": GROUP}},
    }
    boundary = uuid.uuid4().hex
    parts = [
        ("--%s\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n" % boundary).encode()
        + json.dumps(meta).encode() + b"\r\n",
        ("--%s\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"%s.fbx\"\r\nContent-Type: model/fbx\r\n\r\n" % (boundary, gid)).encode()
        + data + b"\r\n",
        ("--%s--\r\n" % boundary).encode(),
    ]
    op = request("POST", API + "/assets", key, b"".join(parts), {"Content-Type": "multipart/form-data; boundary=" + boundary})
    name = op.get("path") or ("operations/" + op["operationId"])
    for _ in range(90):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", API + "/" + name, key)
    if not op.get("done"):
        raise RuntimeError(gid + " upload still pending: " + name)
    response = op.get("response") or {}
    asset = response.get("assetId")
    if not asset:
        raise RuntimeError(gid + " upload failed: " + json.dumps(op.get("error") or op)[:400])
    return asset, hashlib.sha256(data).hexdigest(), response.get("moderationResult", {}).get("moderationState")


def main():
    key = os.environ.get("ROBLOX_ASSETS_KEY")
    if not key:
        sys.exit("ROBLOX_ASSETS_KEY is not set (run through zsh -i -c)")
    ids = [a for a in sys.argv[1:] if a in IDS] or IDS
    record_path = os.path.join(OUT, "roblox_assets.json")
    record = json.load(open(record_path)) if os.path.exists(record_path) else {"Group": GROUP, "Assets": {}}
    for gid in ids:
        sha = hashlib.sha256(open(os.path.join(OUT, gid, gid + ".fbx"), "rb").read()).hexdigest()
        prev = record["Assets"].get(gid)
        if prev and prev.get("Sha256") == sha:
            print(gid, "unchanged", prev["AssetId"])
            continue
        asset, sha, moderation = upload(gid, key)
        record["Assets"][gid] = {"AssetId": asset, "Sha256": sha, "Moderation": moderation, "Uploaded": time.strftime("%Y-%m-%dT%H:%M:%S")}
        print(gid, asset, moderation)
        with open(record_path, "w") as fh:
            json.dump(record, fh, indent=1)


if __name__ == "__main__":
    main()
