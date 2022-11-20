nim --gcc.exe:musl-gcc --gcc.linkerexe:musl-gcc --passL:-static -d:release --opt:size c wapp_simple_nim_stats.nim
strip -s ./wapp_simple_nim_stats
upx --best ./wapp_simple_nim_stats
gh release create `cat VERSION` wapp_simple_nim_stats