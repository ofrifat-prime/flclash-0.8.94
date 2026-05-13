#!/bin/bash
set -e

# Download Go
if [ ! -d "go" ]; then
    echo "Downloading Go..."
    wget -q https://go.dev/dl/go1.22.2.linux-amd64.tar.gz
    tar xf go1.22.2.linux-amd64.tar.gz
    rm go1.22.2.linux-amd64.tar.gz
fi

# Download Flutter
if [ ! -d "flutter" ]; then
    echo "Downloading Flutter..."
    wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.6-stable.tar.xz
    tar xf flutter_linux_3.19.6-stable.tar.xz
    rm flutter_linux_3.19.6-stable.tar.xz
fi

export PATH="$(pwd)/go/bin:$(pwd)/flutter/bin:$HOME/.pub-cache/bin:$(pwd):$PATH"

# Run setup
echo "Running flutter doctor..."
export PUB_HOSTED_URL=https://pub.flutter-io.cn
flutter doctor -v

echo "Running setup..."
dart setup.dart linux --arch amd64
