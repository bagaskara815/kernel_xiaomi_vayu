#!/usr/bin/env bash

# Codelinaro Tags
TAG="LA.UM.9.1.r1-16300-SMxxx0.QSSI14.0"

# Setup functions
upstream (){
        git fetch https://git.codelinaro.org/clo/la/platform/vendor/qcom-opensource/wlan/"$1" "$TAG"
        git merge -X subtree=drivers/staging/"$1" FETCH_HEAD --signoff --log=999
}

upstream2 (){
        git fetch https://git.codelinaro.org/clo/la/platform/vendor/qcom-opensource/data-kernel "$TAG"
        git merge -X subtree=techpack/data FETCH_HEAD --signoff --log=999
}

upstream3 (){
        git fetch https://git.codelinaro.org/clo/la/platform/vendor/opensource/audio-kernel "$TAG"
        git merge -X subtree=techpack/audio FETCH_HEAD --signoff --log=999
}

upstream4 (){
        git fetch https://git.codelinaro.org/clo/la/kernel/msm-4.14 "$TAG"
        git merge --signoff --log=999 FETCH_HEAD
}

# Go upstream
upstream qcacld-3.0 && \
upstream fw-api && \
upstream qca-wifi-host-cmn && \
upstream2 && upstream3 && upstream4
