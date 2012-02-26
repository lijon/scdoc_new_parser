#ifndef SCDOC_H
#define SCDOC_H

typedef struct Node {
    const char * id;
    int n_childs;
    char *text;
    struct Node **children;
} Node;

#endif
