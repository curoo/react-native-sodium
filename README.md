# react-native-sodium (Expend maintenance fork)

This repo is a fork of a fork of a fork of a fork.

- Upstream status: old and effectively unmaintained
- This fork exists only to keep the Expend app working on modern React Native / Expo

The upstream forks are outdated and no longer maintained.

This fork is maintained by us as we require this library for our login flow for the Expend mobile app. We only touch it when necessary to fix compatibility issues as we update our app.

## Latest patch

Updates to satisfy Android's 16 KB page-size [requirements](https://developer.android.com/guide/practices/page-sizes).

## Usage in the app

```json
"react-native-sodium": "https://github.com/curoo/react-native-sodium.git#head=fix/android-16kb-page-size"
```

## Rebuilding precompiled libs

```bash
npm run rebuild arm x86
tar -czf precompiled.tgz libsodium
```
