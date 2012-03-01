#!/bin/sh
flex -P scdoc SCDoc.l &&
bison -p scdoc --defines SCDoc.y &&
g++ -g -O3 -o parser lex.scdoc.c SCDoc.tab.c SCDoc.c main.c -ll

