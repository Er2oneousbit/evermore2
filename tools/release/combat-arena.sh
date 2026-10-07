#!/bin/sh
# Starts the tech demo in the combat arena (giant rats). Add --hard for Hard.
cd "$(dirname "$0")" && exec ./Evermore2.x86_64 -- --arena "$@"
