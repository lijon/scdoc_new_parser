#!/bin/sh
flex SCDoc.l && bison --defines -v SCDoc.y && g++ -o parser *.c -ll

