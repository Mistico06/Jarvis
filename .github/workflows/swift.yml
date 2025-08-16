name: Build iOS App

on:
  push:
    branches: [ "main" ]
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-latest

    steps:
      - name: Checkout repo with submodules
        uses: actions/checkout@v3
        with:
          submodules: recursive

      - name: Set up Xcode 16
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '16.2'

      - name: List available schemes
        working-directory: Jarvis
        run: xcodebuild -list

      - name: Build iOS package
        working-directory: Jarvis
        run: |
          xcodebuild clean build \
            -scheme Jarvis \
            -destination "generic/platform=iOS" \
            IPHONEOS_DEPLOYMENT_TARGET=16.0 \
            CODE_SIGN_STYLE=Automatic \
            -allowProvisioningUpdates
