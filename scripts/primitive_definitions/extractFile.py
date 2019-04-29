#!/usr/bin/python
# -*- coding: utf-8 -*-

import os

def extractPDefs(fname, d):
    with open(fname) as fin:
        lcnt = 0
        echo = 0
        for line in fin:
            lcnt = lcnt+1;
            if lcnt%1000000 == 0:
                print "Line %sM" % (lcnt/1000000)
            if (echo == 1):
                print >>fout, line,
            if (line.startswith("\t(primitive_def")):
                echo = 1
                s = line.split(' ')[1]
                fout = open("%s/%s.def" % (d, s), "w")
                print "Processing def: %s" % s
                print >>fout, line,
            if (line.startswith("\t)")):
                echo = 0
        fin.close()
        fout.close()

