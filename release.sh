nim c \
    --dynlibOverride:sqlite3 \
    --passL:"sqlite3.o -lm -pthread" \
    --passL:-static \
    -d:release --opt:size \
    wapp_simple_nim_stats.nim
# nim c \
#     --gcc.exe:musl-gcc \
#     --gcc.linkerexe:musl-gcc \
#     --passL:-static \
#     --dynlibOverride:sqlite3 --passL:"sqlite3.o -lm -pthread" \
#     -d:release --opt:size \
#     wapp_simple_nim_stats.nim
strip -s ./wapp_simple_nim_stats
upx --best ./wapp_simple_nim_stats
gh release create `cat VERSION` wapp_simple_nim_stats