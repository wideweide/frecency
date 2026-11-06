#!/bin/bash
# 参数 1: 当前光标目录或文件
# 参数 2: 标签

PATH_TO_ADD="$1"
TAG_NAME="$2"


# 目录与文件书签统一写入 file 库
SELF=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SELF")
frecency_bin="$SCRIPT_DIR/frecency"

if [ -d "$PATH_TO_ADD" ]; then
    $frecency_bin file add "$PATH_TO_ADD" "$TAG_NAME" >/dev/null 2>&1
    # vifm中路径最后添加/,否则将跳转至父级文件夹并定位到当前目录
    [[ "$PATH_TO_ADD" != */ ]] && PATH_TO_ADD="$PATH_TO_ADD/"
else
    $frecency_bin file add "$PATH_TO_ADD" "$TAG_NAME" >/dev/null 2>&1
fi


vifm --remote -c "bmark! $PATH_TO_ADD $TAG_NAME"
