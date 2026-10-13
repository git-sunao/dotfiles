#!/bin/sh

DP="$(which displayplacer)"

MAC="37D8832A-2D66-02CA-B9F7-8F30A301B230"
EXT="4E997AC1-F856-4522-87BD-F17EC9FBA366"

# 1. まず外部モニターを縦向きにする
$DP "id:$EXT degree:90"

# 2. macOS が回転後のモードを認識するまで待つ
sleep 3

# 3. 縦向き状態の正式な配置・解像度を適用
$DP \
"id:$MAC res:1512x982 hz:120 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0" \
"id:$EXT res:1080x1920 hz:60 color_depth:8 enabled:true scaling:on origin:(1512,-938) degree:90"
