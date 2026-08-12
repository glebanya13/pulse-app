#!/bin/sh
# Widget tests assert against MockRepository fixture content (see
# golden_path_test.dart), so USE_MOCK_DATA must be forced on here — the
# compile-time default is false so a plain device build hits the real API.
cd "$(dirname "$0")/.."
flutter test --dart-define=USE_MOCK_DATA=true "$@"
