fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios metadata_validate

```sh
[bundle exec] fastlane ios metadata_validate
```

Validate fastlane/metadata character limits

### ios metadata_download

```sh
[bundle exec] fastlane ios metadata_download
```

Download current App Store metadata into fastlane/metadata (review before commit)

### ios metadata_upload

```sh
[bundle exec] fastlane ios metadata_upload
```

Upload App Store metadata only (no IPA, no screenshots)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
