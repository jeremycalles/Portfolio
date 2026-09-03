Screenshots for App Store Connect live in `assets/screenshots/` (iOS + macOS).

`metadata_upload` skips screenshots on purpose. Upload them in App Store Connect, or:

```sh
APP_VERSION=1.0.6 bundle exec fastlane deliver --skip_binary_upload --force
```

after placing sized PNGs under `fastlane/screenshots/<locale>/`.
