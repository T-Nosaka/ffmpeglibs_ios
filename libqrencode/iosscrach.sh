#!/bin/bash

source ./scrach.sh

#Rebuild
rm -rf makegenerate

#ABI iphone
make_ios arm64 "iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk" "iOS" "-miphoneos-version-min=11.0"

