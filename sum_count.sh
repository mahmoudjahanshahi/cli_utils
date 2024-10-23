#!/bin/bash
   
awk -F\; '
    BEGIN {
        OFS = ";"
        ll = ""
        n = 0
    }
    {
        l = ""
        for (i = 1; i < NF; i++) {
            l = l $i OFS
        }
        if (l != ll) {
            print ll n
            ll = l
            n = 0  
        }
        n += $NF
    }
    END {
        print ll n
    }
' |
tail -n +2
