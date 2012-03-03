#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "SCDoc.h"

Node * scdoc_parse_run(int partial);
void scdocrestart (FILE *input_file);
int scdoclex_destroy(void);

char * scdoc_current_file = NULL;

static int node_dump_level_done[32] = {0,};

// merge a+b and free b
char *strmerge(char *a, char *b) {
    if(a==NULL) return b;
    if(b==NULL) return a;
    char *s = (char *)realloc(a,strlen(a)+strlen(b)+1);
    strcat(s,b);
    free(b);
    return s;
}

static char *striptrailingws(char *s) {
    char *s2 = strchr(s,0);
    while(--s2 > s && isspace(*s2)) {
        *s2 = 0;
    }
    return s;
}

/*Node * scdoc_parse_string(char *str, int partial) {
    YY_BUFFER_STATE x = scdoc_scan_string(str);
    Node *n = scdoc_parse_run(partial);
    yy_delete_buffer(x);
    return n;
}*/

Node * node_create(const char *id) {
    Node *n = (Node *)malloc(sizeof(Node));
    n->id = id;
    n->text = NULL;
    n->n_childs = 0;
    n->children = NULL;
    return n;
}

// takes ownership of child
Node * node_add_child(Node *n, Node *child) {
    if(child) {
        n->children = (Node **)realloc(n->children, (n->n_childs+1) * sizeof(Node*));
        n->children[n->n_childs] = child;
        n->n_childs++;
    }
    return n;
}

// takes ownership of text
/*Node * node_add_text(Node *n, char *text) {
    if(n->text) {
        char *str = strmergefree(n->text,text);
        n->text = str;
        printf("NODE: Adding text '%s'\n",text);
    } else {
        n->text = text;
    }
    return n;
}*/

// moves the childs from src node to n
Node * node_move_children(Node *n, Node *src) {
    if(src) {
        free(n->children);
        n->children = src->children;
        n->n_childs = src->n_childs;
//        src->children = NULL;
//        src->n_childs = 0;
        free(src->text);
        free(src);
    }
}

Node * node_make(const char *id, char *text, Node *child) {
    Node *n = node_create(id);
    n->text = text;
    node_add_child(n, child);
    return n;
}

Node * node_make_take_children(const char *id, char *text, Node *src) {
    Node *n = node_make(id, text, NULL);
    node_move_children(n, src);
    return n;
}

void node_free_tree(Node *n) {
    int i;
//    printf("freeing %s\n",n->id);
    free(n->text);
    for(i=0;i<n->n_childs;i++) {
        node_free_tree(n->children[i]);
    }
    free(n->children);
    free(n);
}

void node_fixup_tree(Node *n) {
    int i;
    if(n->text) {
        n->text = striptrailingws(n->text);
    }
    if(n->n_childs) {
        Node *last = n->children[n->n_childs-1];
        if(last->id=="NL") {
            free(last); // NL has no text or children
            n->n_childs--;
        }
        last = NULL;
        for(i = 0; i < n->n_childs; i++) {
            Node *child = n->children[i];
            if((child->id=="TEXT" || child->id=="NL") && last && last->id=="TEXT") {
                if(child->id=="NL") {
                    last->text = (char*)realloc(last->text,strlen(last->text)+2);
                    strcat(last->text," ");
                } else {
                    last->text = strmerge(last->text,child->text);
                }
                free(child); // we took childs text and it has no children
                n->children[i] = NULL;
            } else {
                node_fixup_tree(child);
                last = child;
            }
        }
        int j = 0;
        for(i = 0; i < n->n_childs; i++) {
            if(n->children[i]) {
               n->children[j++] = n->children[i];
            }
        }
        n->n_childs = j;
    }
}

static void _node_dump(Node *n, int level, int last) {
    int i;
    for(i=0;i<level;i++) {
        if(node_dump_level_done[i])
            printf("    ");
        else
            printf("|   ");
    }
    if(last) {
        printf("`-- ");
        node_dump_level_done[level] = 1;
    } else {
        printf("|-- ");
    }
    printf("%s",n->id);
    if(n->text) printf(" \"%s\"",n->text);
    printf("\n");
    for(i = 0; i < n->n_childs; i++) {
        _node_dump(n->children[i], level+1, i==n->n_childs-1);
    }
    node_dump_level_done[level] = 0;
}

void node_dump(Node *n) {
    _node_dump(n,0,1);
}

Node * scdoc_parse_file(char *fn, int partial) {
    FILE *fp;
    Node *n;

    fp = fopen(fn,"r");
    if(!fp) {
        fprintf(stderr, "scdoc_parse_file: could not open '%s'\n",fn);
        return NULL;
    }
    scdoc_current_file = fn;
    scdocrestart(fp);
    n = scdoc_parse_run(partial);
    if(n) {
        node_fixup_tree(n);
    }
    fclose(fp);
    scdoclex_destroy();
    scdoc_current_file = NULL;
    return n;
}

