#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "SCDoc.h"

int main(int argc, char **argv)
{
    if(argc>1) {
        Node *n;
        if(argc>2 && strcmp(argv[1],"--partial")==0)
            n = scdoc_parse_file(argv[2], 1);
        else
            n = scdoc_parse_file(argv[1], 0);
        if(n)
            node_dump(n);
        else
            return 1;
    } else {
        fprintf(stderr, "Usage: %s inputfile.schelp\n",argv[0]);
    }
    return 0;
}
