#!/bin/bash

# 获取当前目录名作为 zip 文件名
DIR_NAME="$(basename "$(pwd)")"

rm -f "../${DIR_NAME}.zip"

zip -r "../${DIR_NAME}.zip" .

mv "../${DIR_NAME}.zip" .

echo "打包完成：../${DIR_NAME}.zip"
