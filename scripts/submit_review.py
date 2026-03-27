#!/usr/bin/env python3
"""
Submit IIIF AR update to App Store review via App Store Connect API.

Usage:
    export ASC_KEY_ID="KD98P2SUZB"
    export ASC_ISSUER_ID="5726bd9c-7a3e-4ab8-b094-b5be612b291c"
    python3 scripts/submit_review.py

Steps:
    1. Get APP_ID from bundle ID
    2. Wait for build processing
    3. Create new version (1.0.1) if needed
    4. Assign build to version
    5. Set encryption compliance
    6. Set whatsNew
    7. Submit for review
"""

import json
import jwt
import os
import sys
import time
import urllib.request
import urllib.error

# --- Config ---
BUNDLE_ID = "com.nakamura196.iifar"
VERSION_STRING = "1.1.0"
BUILD_NUMBER = "2"

KEY_ID = os.environ.get("ASC_KEY_ID", "KD98P2SUZB")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "5726bd9c-7a3e-4ab8-b094-b5be612b291c")
KEY_PATH = os.path.expanduser(f"~/.private_keys/AuthKey_{KEY_ID}.p8")

WHATS_NEW = {
    "ja": "- Googleアカウント・Appleアカウントでログインし、自分のIIIFコレクションをAR表示できるようになりました\n- 画像コレクション管理ツール「Pocket」との連携\n- メタデータ表示（所蔵、製作年、法量、帰属、ライセンス）\n- 実寸情報（physicalScale）の表示に対応\n- アプリの安定性とパフォーマンスを改善",
    "en-US": "- Sign in with Google or Apple to view your own IIIF collections in AR\n- Integration with Pocket image collection management tool\n- Display metadata (institution, date, dimensions, attribution, license)\n- Support for physical dimensions (physicalScale)\n- Improved app stability and performance",
}

# --- JWT ---
def generate_token():
    with open(KEY_PATH, "r") as f:
        private_key = f.read()
    now = int(time.time())
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": KEY_ID})

# --- API helper ---
def api_request(method, path, data=None):
    token = generate_token()
    url = f"https://api.appstoreconnect.apple.com/v1/{path}"
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(
        url, data=body, method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    try:
        resp = urllib.request.urlopen(req)
        if resp.status == 204:
            return None
        return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        print(f"Error {e.code}: {error_body}")
        raise

# --- Main ---
def main():
    # 1. Get APP_ID
    print("=== Step 1: Get App ID ===")
    result = api_request("GET", f"apps?filter[bundleId]={BUNDLE_ID}")
    APP_ID = result["data"][0]["id"]
    print(f"App ID: {APP_ID}")

    # 2. Check build processing
    print("\n=== Step 2: Check build processing ===")
    for attempt in range(30):
        result = api_request("GET",
            f"builds?filter[app]={APP_ID}&filter[version]={BUILD_NUMBER}"
            f"&filter[preReleaseVersion.version]={VERSION_STRING}"
            f"&sort=-uploadedDate&limit=1")
        if not result["data"]:
            if attempt == 0:
                print(f"Build not found yet, waiting...")
            time.sleep(30)
            continue
        build = result["data"][0]
        state = build["attributes"]["processingState"]
        print(f"Build state: {state}")
        if state == "VALID":
            BUILD_ID = build["id"]
            print(f"Build ID: {BUILD_ID}")
            break
        elif state == "FAILED":
            print("Build processing failed!")
            sys.exit(1)
        print("Waiting 30s for processing...")
        time.sleep(30)
    else:
        print("Timeout waiting for build processing")
        sys.exit(1)

    # 3. Get or create version
    print("\n=== Step 3: Get or create version ===")
    result = api_request("GET",
        f"apps/{APP_ID}/appStoreVersions"
        f"?filter[versionString]={VERSION_STRING}&filter[platform]=IOS")
    if result["data"]:
        version = result["data"][0]
        VERSION_ID = version["id"]
        print(f"Existing version: {VERSION_ID} ({version['attributes']['appStoreState']})")
    else:
        print(f"Creating version {VERSION_STRING}...")
        result = api_request("POST", "appStoreVersions", {
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "versionString": VERSION_STRING,
                    "platform": "IOS",
                },
                "relationships": {
                    "app": {
                        "data": {"type": "apps", "id": APP_ID}
                    }
                },
            }
        })
        VERSION_ID = result["data"]["id"]
        print(f"Created version: {VERSION_ID}")

    # 4. Assign build to version
    print("\n=== Step 4: Assign build ===")
    api_request("PATCH",
        f"appStoreVersions/{VERSION_ID}/relationships/build", {
        "data": {"type": "builds", "id": BUILD_ID}
    })
    print("Build assigned to version")

    # 5. Encryption compliance
    print("\n=== Step 5: Set encryption compliance ===")
    try:
        api_request("PATCH", f"builds/{BUILD_ID}", {
            "data": {
                "type": "builds",
                "id": BUILD_ID,
                "attributes": {"usesNonExemptEncryption": False},
            }
        })
        print("Encryption compliance set")
    except urllib.error.HTTPError as e:
        if e.code == 409:
            print("Already set (409), skipping")
        else:
            raise

    # 6. Set whatsNew
    print("\n=== Step 6: Set whatsNew ===")
    result = api_request("GET",
        f"appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations")
    for loc in result["data"]:
        locale = loc["attributes"]["locale"]
        loc_id = loc["id"]
        if locale in WHATS_NEW:
            api_request("PATCH", f"appStoreVersionLocalizations/{loc_id}", {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": loc_id,
                    "attributes": {"whatsNew": WHATS_NEW[locale]},
                }
            })
            print(f"whatsNew set for {locale}")

    # 7. Submit for review
    print("\n=== Step 7: Submit for review ===")
    result = api_request("POST", "reviewSubmissions", {
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {
                "app": {"data": {"type": "apps", "id": APP_ID}}
            },
        }
    })
    SUBMISSION_ID = result["data"]["id"]
    print(f"Submission created: {SUBMISSION_ID}")

    api_request("POST", "reviewSubmissionItems", {
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {
                    "data": {"type": "reviewSubmissions", "id": SUBMISSION_ID}
                },
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": VERSION_ID}
                },
            },
        }
    })
    print("Version added to submission")

    result = api_request("PATCH", f"reviewSubmissions/{SUBMISSION_ID}", {
        "data": {
            "type": "reviewSubmissions",
            "id": SUBMISSION_ID,
            "attributes": {"submitted": True},
        }
    })
    state = result["data"]["attributes"]["state"]
    print(f"\nSubmitted! State: {state}")


if __name__ == "__main__":
    main()
