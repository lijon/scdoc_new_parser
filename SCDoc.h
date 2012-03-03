#ifndef SCDOC_H
#define SCDOC_H

typedef struct Node {
    const char * id;
    int n_childs;
    char *text;
    struct Node **children;
} Node;

char *strmerge(char *a, char *b);

Node * node_make_take_children(const char *id, char *text, Node *src);
Node * node_make(const char *id, char *text, Node *child);
Node * node_add_child(Node *n, Node *child);
Node * node_create(const char *id);
void node_free_tree(Node *n);

Node * scdoc_parse_file(char *fn, int partial);
void node_dump(Node *n);

extern char * scdoc_current_file;

#endif
