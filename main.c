#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "SCDoc.h"

int main(int argc, char **argv)
{
    if(argc>1) {
        Node *n;
        if(argc>2 && strcmp(argv[1],"--partial")==0)
            n = scdoc_parse_file(argv[2], SCDOC_PARSE_PARTIAL);
        else
        if(argc>2 && strcmp(argv[1],"--metadata")==0)
            n = scdoc_parse_file(argv[2], SCDOC_PARSE_METADATA);
        else
            n = scdoc_parse_file(argv[1], SCDOC_PARSE_FULL);
        if(n) {
            node_dump(n);
            node_free_tree(n);
        } else
            return 1;
    } else {
        fprintf(stderr, "Usage: %s inputfile.schelp\n",argv[0]);
    }
    return 0;
}
