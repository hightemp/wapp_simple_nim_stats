nim c \
    --dynlibOverride:sqlite3 \
    --passL:"sqlite3.o -lm -pthread" \
    --passL:-static \
    --spellSuggest \
    -d:release --opt:size \
    wapp_simple_nim_stats.nim

if [ "$?" != "0" ]; then
    echo "====================================================="
    echo "ERROR"
    echo
    exit 1
fi

# nim c \
#     --gcc.exe:musl-gcc \
#     --gcc.linkerexe:musl-gcc \
#     --passL:-static \
#     --dynlibOverride:sqlite3 --passL:"sqlite3.o -lm -pthread" \
#     -d:release --opt:size \
#     wapp_simple_nim_stats.nim
strip -s ./wapp_simple_nim_stats

if [ "$?" != "0" ]; then
    echo "====================================================="
    echo "ERROR"
    echo
    exit 1
fi

upx --best ./wapp_simple_nim_stats

if [ "$?" != "0" ]; then
    echo "====================================================="
    echo "ERROR"
    echo
    exit 1
fi

git add .
git commit -am "`date` update"
git push

if [ "$?" != "0" ]; then
    echo "====================================================="
    echo "ERROR"
    echo
    exit 1
fi

timestamp=$(date +%s)
VERSION=$(echo `cat VERSION`.$timestamp)

gh release create $VERSION -t $VERSION -n "" wapp_simple_nim_stats