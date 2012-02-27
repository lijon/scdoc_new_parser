#!/bin/sh
flex -P scdoc SCDoc.l && bison -p scdoc --defines SCDoc.y && g++ -g -o parser lex.scdoc.c SCDoc.tab.c -ll

