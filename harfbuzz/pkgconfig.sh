#!/bin/bash
# set -x

pkg_name=${@: -1}

case $1 in
 --version)
   echo "0.29.2" 
 ;;
 --cflags)
   case $pkg_name in
     *)
     echo ""
     ;;
   esac
 ;;
 --modversion)
    case $pkg_name in
      freetype2)
      echo "26.5.20"
      ;;
      *)
      echo "1.0"
    esac
 ;;
 --libs)
   case $pkg_name in
     freetype2)
     echo "-lfreetype"
     ;;
     *)
     echo ""
     ;;
   esac
 ;;

esac

