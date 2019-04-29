#!/usr/bin/python
# -*- coding: utf-8 -*-

import os, sys
from extractFile import extractPDefs

if len(sys.argv) != 3:
    print "Usage: extractAll.py fileExtension"
    print len(sys.argv)
else:
    for fname in os.listdir("."):
        if fname.endswith(sys.argv[1]):
            print "Processing: %s" % fname
            extractPDefs(fname, sys.argv[2]);

