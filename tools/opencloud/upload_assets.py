"""Uploads Glass Clash art (FBX models, PNG images) to group 11116787 through Open Cloud.

    zsh -i -c 'python3 tools/opencloud/upload_assets.py --check'
    zsh -i -c 'python3 tools/opencloud/upload_assets.py <list.json> [key ...]'

The key is read from ROBLOX_ASSETS_KEY (only loaded by an interactive zsh) and is never printed.
<list.json> is {"Record": "<repo-relative json>", "Items": [{"Key", "Path", "Type": "Model"|"Decal"|"Animation", "Name"}]}.
Results (asset id, SHA256, moderation) go to the Record file; a file whose hash is unchanged is skipped.
--check tests whether the key can read assets (403 means the key needs Assets read/write in Creator Hub).
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GROUP = "11116787"
API = "https://apis.roblox.com/assets/v1"
MIME = {
    ".fbx": "model/fbx",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".ogg": "audio/ogg",
    ".mp3": "audio/mpeg",
    ".rbxm": "model/x-rbxm",  # Animation: a Studio-serialized KeyframeSequence
}


def request(method, url, key, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key, **(headers or {})})
    with urllib.request.urlopen(req, timeout=180) as res:
        return json.loads(res.read().decode())


def check(key):
    try:
        request("GET", API + "/assets/115123551485957", key)
        print("assets: OK")
        return True
    except urllib.error.HTTPError as err:
        print("assets: HTTP", err.code, "(403 = add Assets read/write to the key in Creator Hub > Open Cloud > API Keys)")
        return False


def upload(item, key):
    path = os.path.join(REPO, item["Path"])
    data = open(path, "rb").read()
    ext = os.path.splitext(path)[1].lower()
    meta = {
        "assetType": item.get("Type", "Model"),
        "displayName": item.get("Name", item["Key"])[:50],
        "description": item.get("Description", "Glass Clash original art."),
        "creationContext": {"creator": {"groupId": GROUP}},
    }
    boundary = uuid.uuid4().hex
    body = b"".join(
        [
            ("--%s\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n" % boundary).encode()
            + json.dumps(meta).encode()
            + b"\r\n",
            (
                "--%s\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n"
                % (boundary, os.path.basename(path), MIME.get(ext, "application/octet-stream"))
            ).encode()
            + data
            + b"\r\n",
            ("--%s--\r\n" % boundary).encode(),
        ]
    )
    op = request("POST", API + "/assets", key, body, {"Content-Type": "multipart/form-data; boundary=" + boundary})
    name = op.get("path") or ("operations/" + op["operationId"])
    for _ in range(120):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", API + "/" + name, key)
    response = op.get("response") or {}
    if not op.get("done") or not response.get("assetId"):
        raise RuntimeError(item["Key"] + " upload failed or pending: " + json.dumps(op.get("error") or op)[:300])
    return response["assetId"], hashlib.sha256(data).hexdigest(), response.get("moderationResult", {}).get("moderationState")


def main():
    key = os.environ.get("ROBLOX_ASSETS_KEY")
    if not key:
        sys.exit("ROBLOX_ASSETS_KEY is not set (run through zsh -i -c)")
    if sys.argv[1:2] == ["--check"]:
        sys.exit(0 if check(key) else 1)
    spec = json.load(open(sys.argv[1]))
    only = set(sys.argv[2:])
    failed = []
    record_path = os.path.join(REPO, spec["Record"])
    record = json.load(open(record_path)) if os.path.exists(record_path) else {"Group": GROUP, "Assets": {}}
    for item in spec["Items"]:
        if only and item["Key"] not in only:
            continue
        sha = hashlib.sha256(open(os.path.join(REPO, item["Path"]), "rb").read()).hexdigest()
        prev = record["Assets"].get(item["Key"])
        if prev and prev.get("Sha256") == sha:
            print(item["Key"], "unchanged", prev["AssetId"])
            continue
        asset = None
        for attempt in range(4):
            try:
                asset, sha, moderation = upload(item, key)
                break
            except (urllib.error.URLError, ConnectionError, TimeoutError, OSError) as err:
                # Slow or flaky connections drop large FBX uploads; back off and retry.
                wait = 15 * (attempt + 1)
                print(item["Key"], "retry", attempt + 1, "after", type(err).__name__, "- waiting", wait, "s", flush=True)
                time.sleep(wait)
        if asset is None:
            print(item["Key"], "FAILED after retries (run the same command again later)", flush=True)
            failed.append(item["Key"])
            continue
        record["Assets"][item["Key"]] = {
            "AssetId": asset,
            "Path": item["Path"],
            "Sha256": sha,
            "Moderation": moderation,
            "Uploaded": time.strftime("%Y-%m-%dT%H:%M:%S"),
        }
        print(item["Key"], asset, moderation, flush=True)
        os.makedirs(os.path.dirname(record_path), exist_ok=True)
        with open(record_path, "w") as fh:
            json.dump(record, fh, indent=1)
    if failed:
        sys.exit("failed: " + " ".join(failed))


if __name__ == "__main__":
    main()
