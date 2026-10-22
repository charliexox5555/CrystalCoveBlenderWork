"""Lists, creates and updates Glass Clash developer products through Open Cloud (universe 10770493435).

    zsh -i -c 'python3 tools/opencloud/products.py list'
    zsh -i -c 'python3 tools/opencloud/products.py create "<name>" <price> "<description>" [icon.png]'
    zsh -i -c 'python3 tools/opencloud/products.py update <productId> [price=<n>] [name=<text>] [description=<text>] [icon=<png>]'

The key is read from ROBLOX_ASSETS_KEY (only loaded by an interactive zsh) and is never printed. Regional pricing
stays off (decision 80: the card price is what the player pays). A price change here must also go into config
(Config/DailyStore, Config/MarbleShop or Config/Offers), see docs/design/MONETIZATION.md.
"""
import json
import os
import sys
import urllib.error
import urllib.request
import uuid

UNIVERSE = "10770493435"
API = "https://apis.roblox.com/developer-products/v2/universes/" + UNIVERSE + "/developer-products"


def request(method, url, key, fields=None, files=None):
    body, headers = None, {"x-api-key": key}
    if fields is not None or files:
        boundary = uuid.uuid4().hex
        parts = []
        for name, value in (fields or {}).items():
            parts.append(
                f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
            )
        for name, path in (files or {}).items():
            data = open(path, "rb").read()
            parts.append(
                f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{os.path.basename(path)}"\r\n'
                "Content-Type: image/png\r\n\r\n".encode()
                + data
                + b"\r\n"
            )
        parts.append(f"--{boundary}--\r\n".encode())
        body = b"".join(parts)
        headers["Content-Type"] = "multipart/form-data; boundary=" + boundary
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=120) as res:
            text = res.read().decode()
            return json.loads(text) if text.strip() else {}
    except urllib.error.HTTPError as err:
        print("HTTP", err.code, err.read().decode()[:400])
        sys.exit(1)


def listing(key):
    out, token = [], ""
    while True:
        page = request("GET", API + "/creator?pageSize=50" + ("&pageToken=" + token if token else ""), key)
        out += page.get("developerProducts", [])
        token = page.get("nextPageToken") or ""
        if not token:
            return out


def main():
    key = os.environ.get("ROBLOX_ASSETS_KEY")
    if not key:
        print("ROBLOX_ASSETS_KEY is not set (run through zsh -i)")
        sys.exit(1)
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        for product in listing(key):
            price = (product.get("priceInformation") or {}).get("defaultPriceInRobux")
            print(product.get("productId"), price, product.get("isForSale"), product.get("name"))
    elif cmd == "create":
        name, price, description = sys.argv[2], sys.argv[3], sys.argv[4]
        fields = {
            "name": name,
            "description": description,
            "price": price,
            "isForSale": "true",
            "isRegionalPricingEnabled": "false",
        }
        files = {"imageFile": sys.argv[5]} if len(sys.argv) > 5 else None
        result = request("POST", API, key, fields, files)
        print(json.dumps({"productId": result.get("productId"), "name": result.get("name")}))
    elif cmd == "update":
        product, fields, files = sys.argv[2], {}, {}
        for arg in sys.argv[3:]:
            name, _, value = arg.partition("=")
            if name == "icon":
                files["imageFile"] = value
            else:
                fields[name] = value
        request("PATCH", API + "/" + product, key, fields, files)
        print("updated", product, json.dumps(fields))
    else:
        print(__doc__)


main()
