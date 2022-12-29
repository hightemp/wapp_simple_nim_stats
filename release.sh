nim c -r wapp_simple_nim_stats.nim

# nim \
#     --gcc.exe:musl-gcc \
#     --gcc.linkerexe:musl-gcc \
#     --passL:-static \
#     -d:release \
#     --opt:size \
#     c wapp_simple_nim_stats.nim

rm -rf /home/hightemp/.cache/nim

# nim c \
#     --gcc.exe:musl-gcc \
#     --gcc.linkerexe:musl-gcc \
#     --passL:-static \
#     -o:sqlite3.so \
#     -d:release --opt:size \
#     wapp_simple_nim_stats.nim

#     --passL:"sqlite3.o -pthread" \

if [ "$?" != "0" ]; then
    echo "====================================================="
    echo "ERROR"
    echo
    exit 1
fi

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