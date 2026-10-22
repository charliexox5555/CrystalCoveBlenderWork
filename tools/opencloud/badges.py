"""Creates and updates Glass Clash badges through Open Cloud (universe 10770493435, decision 118).

    zsh -i -c 'python3 tools/opencloud/badges.py list'            # badges on the experience + today's free quota
    zsh -i -c 'python3 tools/opencloud/badges.py create'          # every Config/Badges entry with Id = nil
    zsh -i -c 'python3 tools/opencloud/badges.py update <badgeId> [name=<text>] [description=<text>] [enabled=true|false]'

Names, descriptions and icons come from src/shared/Config/Badges.luau (icons: tools/ui/badge_art.py). `create` writes
each new id back into that file. It only ever creates FREE badges: it checks the free quota first and sends
expectedCost=0, which Roblox refuses (error 18) if the badge would cost Robux. Creating needs the key scope
legacy-universe.badge:manage-and-spend-robux; updating needs legacy-universe.badge:write. The key is read from
ROBLOX_ASSETS_KEY (only loaded by an interactive zsh) and is never printed.
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CONFIG = os.path.join(REPO, "src", "shared", "Config", "Badges.luau")
UNIVERSE = "10770493435"
CREATE = "https://apis.roblox.com/legacy-badges/v1/universes/" + UNIVERSE + "/badges"
UPDATE = "https://apis.roblox.com/legacy-badges/v1/badges/"
PUBLIC = "https://badges.roblox.com/v1/"
GROUP_FUNDS = "2"  # paymentSourceType: 1 = user, 2 = group (the experience belongs to group 11116787)


def request(method, url, key=None, body=None, content_type=None):
    headers = {"x-api-key": key} if key else {}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=120) as res:
            text = res.read().decode()
            return json.loads(text) if text.strip() else {}
    except urllib.error.HTTPError as err:
        print("HTTP", err.code, err.read().decode()[:400])
        sys.exit(1)


def config_badges():
    """[(key, id or None, name, description, icon)] in file order, read from the Luau config."""
    text = open(CONFIG).read()
    block = text[text.index("Badges.ByKey = {"):]
    out = []
    for m in re.finditer(r'\n\t(\w+) = \{\n\t\tId = (nil|\d+),\n\t\tName = "([^"]*)",\n\t\tDescription = "([^"]*)",\n'
                         r'\t\tIcon = "([^"]*)",', block):
        out.append((m.group(1), None if m.group(2) == "nil" else int(m.group(2)), m.group(3), m.group(4), m.group(5)))
    return out


def write_id(key, badge_id):
    text = open(CONFIG).read()
    pattern = "\n\t%s = {\n\t\tId = nil," % key
    assert text.count(pattern) == 1, key
    open(CONFIG, "w").write(text.replace(pattern, "\n\t%s = {\n\t\tId = %d," % (key, badge_id)))


def multipart(fields, icon):
    boundary = uuid.uuid4().hex
    parts = [f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode() for k, v in fields.items()]
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="files"; filename="{os.path.basename(icon)}"\r\n'
                 "Content-Type: image/png\r\n\r\n".encode() + open(icon, "rb").read() + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), "multipart/form-data; boundary=" + boundary


def quota():
    return int(request("GET", PUBLIC + "universes/" + UNIVERSE + "/free-badges-quota"))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        for badge in request("GET", PUBLIC + "universes/" + UNIVERSE + "/badges?limit=100&sortBy=DateCreated").get("data", []):
            print(badge["id"], "enabled" if badge.get("enabled") else "DISABLED", badge["name"])
        print("free badges left today:", quota())
        return
    key = os.environ.get("ROBLOX_ASSETS_KEY")
    if not key:
        print("ROBLOX_ASSETS_KEY is not set (run through zsh -i)")
        sys.exit(1)
    if cmd == "create":
        todo = [b for b in config_badges() if b[1] is None]
        left = quota()
        if len(todo) > left:
            print("Only %d free badges left today for %d to create; nothing created (extra ones cost Robux)." % (left, len(todo)))
            sys.exit(1)
        for badge_key, _, name, description, icon in todo:
            body, ctype = multipart({"name": name, "description": description, "paymentSourceType": GROUP_FUNDS,
                                     "expectedCost": "0"}, os.path.join(REPO, icon))
            result = request("POST", CREATE, key, body, ctype)
            badge_id = int(result["id"])
            write_id(badge_key, badge_id)
            print(json.dumps({"key": badge_key, "id": badge_id, "name": result.get("name"), "enabled": result.get("enabled")}))
    elif cmd == "update":
        badge_id, fields = sys.argv[2], {}
        for arg in sys.argv[3:]:
            name, _, value = arg.partition("=")
            fields[name] = (value == "true") if name == "enabled" else value
        request("PATCH", UPDATE + badge_id, key, json.dumps(fields).encode(), "application/json")
        print("updated", badge_id, json.dumps(fields))
    else:
        print(__doc__)


main()
