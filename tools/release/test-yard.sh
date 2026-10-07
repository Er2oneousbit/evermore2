#!/bin/sh
# Starts the tech demo in the test yard (F2 cycles day, golden hour, night).
cd "$(dirname "$0")" && exec ./Evermore2.x86_64 -- --yard "$@"
