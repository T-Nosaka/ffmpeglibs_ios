#!/bin/bash

source ./scrach.sh

#Rebuild
rm -rf makegenerate

#ABI simulator
make_ios arm64 "iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk" "iOSSim" "-miphonesimulator-version-min=11.0"

