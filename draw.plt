#!/usr/bin/env gnuplot

reset
set terminal svg size 1180,780
set termoption noenhanced
set output 'plot.svg'

unset border
set bmargin 0
set tmargin 0
set lmargin 0
set rmargin 3

set key top left
set tics scale 0
unset ytics
unset xtics

set y2tics 0,60
set yrange [0:780]
set y2tics rotate by 90 offset -1,-1.4
set style line 12 lt 1 lc rgb 'gray'
set grid noxtics y2tics ls 12

set style data histogram
set style histogram clustered gap 1
set style fill solid 1 noborder
set boxwidth 1

p 'eatmydata.dat' u 2 title 'eatmydata' lc rgb '#c9e8eb', \
'' u 0:2:(sprintf("%.2f", $2)) w labels rotate by 90 offset -1.6,-0.1 right font "Sans,10" notitle, \
'unsafeio.dat' u 2 title 'unsafeio' lc rgb '#eec6c6', \
'' u 0:2:(sprintf("%.2f", $2)) w labels rotate by 90 offset 0.05,-0.1 right font "Sans,10" notitle, \
'normal.dat' u 2 title 'normal' lc rgb '#c9ebc9', \
'' u 0:2:(sprintf("%.2f", $2)) w labels rotate by 90 offset 1.7,-0.1 right font "Sans,10" notitle, \
'' u 0:(270):1 w labels rotate by 90 left font "Sans,14" notitle
