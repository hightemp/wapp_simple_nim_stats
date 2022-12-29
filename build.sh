#!/bin/bash

nim c \
    --dynlibOverride:sqlite3 \
    --passL:"sqlite3.o -lm -pthread" \
    --passL:-static \
    --spellSuggest \
    -d:release \
    --opt:size \
    wapp_simple_nim_stats.nim