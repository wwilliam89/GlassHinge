#!/bin/sh
# Xcode Cloud post-clone hook for GlassHinge.
# No third-party dependencies — nothing to install. This hook exists so the
# workflow log shows an explicit, intentional no-op instead of silence.
set -e
echo "GlassHinge: no dependencies to fetch. Build is pure SwiftUI/AppKit + IOKit."
