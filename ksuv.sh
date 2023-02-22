#!/bin/bash
set -x
sed -i "s/ifeq (.*)/ifeq (,,)/g;s/ifndef EXPECTED_SIZE/KSU_GIT_VERSION ?= 69\nexport KSU_GIT_VERSION\nccflags-y += -DKSU_GIT_VERSION=\$(KSU_GIT_VERSION)\n\nifndef EXPECTED_SIZE/g" drivers/kernelsu/Makefile
export KSU_GIT_VERSION=$(curl -s https://github.com/tiann/KernelSU | grep d-sm-inline -A1 | grep -oE ">[,0-9]+<" | grep -oE "[,0-9]+" | tr -d ',')
