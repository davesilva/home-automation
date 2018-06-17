#!/bin/sh

VERSION_NUMBER=$1

docker manifest create davesilva/snips:$VERSION_NUMBER \
       snipsdocker/platform:arm-$VERSION_NUMBER \
       snipsdocker/platform:x86-$VERSION_NUMBER

docker manifest annotate --arch arm --variant v5 --os linux \
       davesilva/snips:$VERSION_NUMBER \
       snipsdocker/platform:arm-$VERSION_NUMBER

docker manifest annotate --arch arm --variant v7 --os linux \
       davesilva/snips:$VERSION_NUMBER \
       snipsdocker/platform:arm-$VERSION_NUMBER

docker manifest annotate --arch 386 --os linux \
       davesilva/snips:$VERSION_NUMBER \
       snipsdocker/platform:x86-$VERSION_NUMBER

docker manifest annotate --arch amd64 --os linux \
       davesilva/snips:$VERSION_NUMBER \
       snipsdocker/platform:x86-$VERSION_NUMBER

docker manifest push --purge davesilva/snips:$VERSION_NUMBER
