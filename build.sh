#!/bin/sh
flex SCDoc.l && bison --defines -v SCDoc.y && g++ -g -o parser *.c -ll

