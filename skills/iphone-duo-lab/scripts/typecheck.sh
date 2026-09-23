#!/bin/bash
# iOS 27.1 シミュレータ SDK で Swift ファイルを型チェックします。
# Xcode 27.1 Beta の SourceKit は Duo 系 API を「見つからない」と誤表示するため、その切り分けに使います。
# 使い方: typecheck.sh <file.swift> [file.swift...]
set -uo pipefail
source "$(dirname "$0")/_sdk.sh"

[ $# -ge 1 ] || { sed -n '2,4p' "$0"; exit 1; }

SDK="$DEV/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
SWIFTC="$DEV/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"

"$SWIFTC" -typecheck -parse-as-library -sdk "$SDK" -target arm64-apple-ios27.1-simulator "$@"
rc=$?
[ $rc -eq 0 ] && echo "OK: 型チェックを通過しました（SDK: ${SDK}）"
exit $rc
