#!/bin/bash -xe

infile="${WORKSPACE:-.}/stable_iso_build_url.txt"
outfile="${WORKSPACE:-.}/stable_iso_magnet_link.txt"

rm -f ${outfile}
curl -fsS -o ${outfile} $(cat ${infile})artifact/magnet_link.txt
cat ${outfile}
