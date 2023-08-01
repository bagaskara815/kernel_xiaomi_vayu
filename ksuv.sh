#!/bin/bash
set -x
sed -i "s/ifeq (.*)/ifeq (,,)/g;s/ifndef KSU_EXPECTED_SIZE/KSU_GIT_VERSION ?= 69\nexport KSU_GIT_VERSION\n\$(eval KSU_VERSION=\$(shell expr 10000 + $\(KSU_GIT_VERSION) + 200))\nccflags-y += -DKSU_VERSION=\$(KSU_VERSION)\n\nifndef KSU_EXPECTED_SIZE/g" drivers/kernelsu/Makefile
export KSU_GIT_VERSION=$(curl -s https://github.com/tiann/KernelSU | grep d-sm-inline -A1 | grep -oE ">[,0-9]+<" | grep -oE "[,0-9]+" | tr -d ',')
