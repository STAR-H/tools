#!/usr/bin/env bash
set -e
cat bin.tar.gz.part.* > bin.tar.gz
echo "merge done"

