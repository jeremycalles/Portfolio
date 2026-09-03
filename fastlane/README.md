# fastlane — App Store listing copy only

Xcode Cloud archives and uploads the **binary**. These lanes never build an IPA.

## Local setup

```sh
./scripts/setup_fastlane.sh
```

Create `~/.appstoreconnect/portfolio-api-key.json` (never commit this):

```json
{
  "key_id": "XXXXXXXXXX",
  "issuer_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "key_filepath": "/Users/YOU/.appstoreconnect/AuthKey_XXXXXXXXXX.p8",
  "duration": 1200,
  "in_house": false
}
```

```sh
export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.appstoreconnect/portfolio-api-key.json"
bundle exec fastlane metadata_validate
APP_VERSION=1.0.6 bundle exec fastlane metadata_upload
```

## Lanes

| Lane | What it does |
|------|----------------|
| `metadata_validate` | Character limits + no spaces after commas in keywords |
| `metadata_download` | Pull current App Store Connect copy into `fastlane/metadata/` |
| `metadata_upload` | Push listing copy (no IPA, no screenshots) |

Edit `fastlane/metadata/<locale>/*.txt`. Screenshots stay in `assets/screenshots/` and are uploaded in App Store Connect (or `deliver` with screenshots enabled).

## Xcode Cloud

`ci_scripts/ci_post_clone.sh` installs Bundler. `ci_scripts/ci_pre_xcodebuild.sh` runs `metadata_upload` when `UPLOAD_APP_STORE_METADATA=1`.

Workflow environment (secret except the last):

- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_CONTENT` (contents of the `.p8`)
- `UPLOAD_APP_STORE_METADATA` = `1` (iOS archive workflow only)
