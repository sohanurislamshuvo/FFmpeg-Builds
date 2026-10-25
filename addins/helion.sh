#!/bin/bash
# Helion Studio build: use with the 8.1 addin and an lgpl variant, e.g.
#   ./makeimage.sh win64 lgpl-shared 8.1 helion && ./build.sh win64 lgpl-shared 8.1 helion
# Pins the exact release/8.1 commit Helion tested (n8.1.3-24-g92611900bb) instead of the
# branch head, and adds "-helion" to the artifact name.
FFMPEG_COMMIT="92611900bb112123e9bf997fdcc2d78e4c4922fc"
