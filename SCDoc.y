%{

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include "SCDoc.h"

int scdocparse();
int scdoclex();
void scdocrestart (FILE *input_file  );
//YY_BUFFER_STATE scdoc_scan_string(const char *str);

extern int scdoclineno;
extern char *scdoctext;
extern int scdoc_start_token;

static const char * method_type = NULL;

static Node * topnode;

void scdocerror(const char *str)
{
    fprintf(stderr, "%s.\n    At line %d: '%s'\n",str,scdoclineno,scdoctext);
}

// merge a+b and free b
char *strmerge(char *a, char *b) {
    if(a==NULL) return b;
    if(b==NULL) return a;
    char *s = (char *)realloc(a,strlen(a)+strlen(b)+1);
    strcat(s,b);
    free(b);
    return s;
}

char *striptrailingws(char *s) {
    char *s2 = strchr(s,0);
    while(--s2 > s && isspace(*s2)) {
        *s2 = 0;
    }
    return s;
}

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

void node_fixup_tree(Node *n) {
    int i;
    if(n->n_childs) {
        Node *last = n->children[n->n_childs-1];
        if(last->id=="NL") {
            free(last);
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
                free(child);
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

static int node_dump_level_done[32] = {0,};
void node_dump(Node *n, int level, int last) {
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
        node_dump(n->children[i], level+1, i==n->n_childs-1);
    }
    node_dump_level_done[level] = 0;
}

%}
%locations
%error-verbose
%union {
    int i;
    const char *id;
    char *str;
    Node *node;
}
// single line header tags that take text
%token CLASS TITLE SUMMARY RELATED CATEGORIES REDIRECT
// single line body tags that take text
%token CLASSTREE COPYMETHOD KEYWORD PRIVATE
// single line structural tags that take text, with children
%token SECTION SUBSECTION METHOD ARGUMENT
// single line structural tags with no text, with children
%token DESCRIPTION CLASSMETHODS INSTANCEMETHODS EXAMPLES RETURNS DISCUSSION
// nestable range tags with no text, with children
%token LIST TREE NUMBEREDLIST DEFINITIONLIST TABLE FOOTNOTE NOTE WARNING
// modal range tags that take multi-line text
%token CODE LINK ANCHOR SOFT IMAGE TELETYPE MATH STRONG EMPHASIS
%token CODEBLOCK TELETYPEBLOCK MATHBLOCK
// symbols
%token TAGSYM BARS HASHES
// text and whitespace
%token <str> TEXT URL COMMA
%token NEWLINE EMPTYLINES

%type <id> headtag sectiontag listtag rangetag tabletag inlinetag blocktag
%type <str> anyword words anywordnl wordsnl anywordurl words2 nocommawords
%type <node> arg optreturns optdiscussion body bodyelem 
%type <node> optsubsections optsubsubsections methodbody  
%type <node> dochead headline optsections sections section
%type <node> subsections subsection subsubsection subsubsections
%type <node> optbody optargs args listbody tablebody tablecells tablerow
%type <node> prose proseelem blockA blockB commalist

%token START_FULL START_PARTIAL

%start document

%%

document: START_FULL dochead optsections
    {
        Node *n = node_create("DOCUMENT");
        node_add_child(n, $2);
        node_add_child(n, $3);
        node_fixup_tree(n);
        topnode = n;
    }
       | START_PARTIAL sections
    {
        Node *n = node_make_take_children("BODY",NULL,$2);
        node_fixup_tree(n);
        node_dump(n,0,1);
    }
;

dochead: dochead headline { $$ = node_add_child($1,$2); }
       | headline { $$ = node_make("HEADER",NULL,$1); }
;

headline: headtag words2 eol { $$ = node_make($1,striptrailingws($2),NULL); }
        | CATEGORIES commalist eol { $$ = node_make_take_children("CATEGORIES",NULL,$2); }
        | RELATED commalist eol { $$ = node_make_take_children("RELATED",NULL,$2); }
;

headtag: CLASS { $$ = "CLASS"; }
       | TITLE { $$ = "TITLE"; }
       | SUMMARY { $$ = "SUMMARY"; }
       | REDIRECT { $$ = "REDIRECT"; }
;

sectiontag: CLASSMETHODS { $$ = "CLASSMETHODS"; method_type = "CMETHOD"; }
          | INSTANCEMETHODS { $$ = "INSTANCEMETHODS"; method_type = "IMETHOD"; }
          | DESCRIPTION { $$ = "DESCRIPTION"; method_type = "METHOD"; }
          | EXAMPLES { $$ = "EXAMPLES"; method_type = "METHOD"; }
;

optsections: sections
           | { $$ = NULL; }
;

sections: sections section { $$ = node_add_child($1,$2); }
        | section { $$ = node_make("BODY",NULL,$1); }
        | subsubsections { $$ = node_make_take_children("BODY",NULL,$1); } /* allow text before first section */
;

section: SECTION { method_type = "METHOD"; } words2 eol optsubsections { $$ = node_make_take_children("SECTION",$3,$5); }
       | sectiontag optsubsections { $$ = node_make_take_children($1, NULL,$2); }
;

optsubsections: subsections
              | { $$ = NULL; }
;

subsections: subsections subsection { $$ = node_add_child($1,$2); }
           | subsection { $$ = node_make("(SUBSECTIONS)",NULL,$1); }
           | subsubsections
;

subsection: SUBSECTION words2 eol optsubsubsections { $$ = node_make_take_children("SUBSECTION", $2, $4); }
;

optsubsubsections: subsubsections
                 | { $$ = NULL; }
;

subsubsections: subsubsections subsubsection { $$ = node_add_child($1,$2); }
              | subsubsection { $$ = node_make("(SUBSUBSECTIONS)",NULL,$1); }
              | body { $$ = node_make_take_children("(SUBSUBSECTIONS)",NULL,$1); }
; 

subsubsection: METHOD words eol methodbody { $$ = node_make_take_children(method_type,$2,$4); }
             | COPYMETHOD words eol { $$ = node_make("COPYMETHOD",$2,NULL); }
             | PRIVATE commalist eol { $$ = node_make_take_children("PRIVATE",NULL,$2); }
;

methodbody: optbody optargs optreturns optdiscussion
    {
        $$ = node_make_take_children("(METHODBODY)",NULL,$1);
        node_add_child($$, $2);
        node_add_child($$, $3);
        node_add_child($$, $4);
    }
;

optbody: body
       | { $$ = NULL; }
;

optargs: args
       | { $$ = NULL; }
;

args: args arg { $$ = node_add_child($1,$2); }
    | arg { $$ = node_make("ARGUMENTS",NULL,$1); }
;

arg: ARGUMENT words eol optbody { $$ = node_make_take_children("ARGUMENT", $2, $4); }
   | ARGUMENT eol body { $$ = node_make_take_children("ARGUMENT", NULL, $3); }
;

optreturns: RETURNS body { $$ = node_make_take_children("RETURNS",NULL,$2); }
          | { $$ = NULL; }
;

optdiscussion: DISCUSSION body { $$ = node_make_take_children("DISCUSSION",NULL,$2); }
             | { $$ = NULL; }
;

/*
body contains a list of bodyelem's (A) and prose (B) such that
the list can start and end with either A or B, and A can repeat while B can not
*/

body: blockA
    | blockB
    ;

blockA: blockB bodyelem { $$ = node_add_child($1,$2); }
      | blockA bodyelem { $$ = node_add_child($1,$2); }
      | bodyelem { $$ = node_make("(SECTIONBODY)",NULL,$1); }
      ;

blockB: blockA prose { $$ = node_add_child($1,$2); }
      | prose { $$ = node_make("(SECTIONBODY)",NULL,$1); }
      ;

bodyelem: rangetag body TAGSYM { $$ = node_make_take_children($1,NULL,$2); }
        | listtag listbody TAGSYM { $$ = node_make_take_children($1,NULL,$2); }
        | tabletag tablebody TAGSYM { $$ = node_make_take_children($1,NULL,$2); }
        | blocktag wordsnl TAGSYM { $$ = node_make($1,$2,NULL); }
        | CLASSTREE words eol { $$ = node_make("CLASSTREE",$2,NULL); }
        | EMPTYLINES { $$ = NULL; }
        | IMAGE words2 TAGSYM { $$ = node_make("IMAGE",$2,NULL); }
        ;

prose: prose proseelem { $$ = node_add_child($1, $2); }
     | proseelem { $$ = node_make("PROSE",NULL,$1); }
     ;

proseelem: anyword { $$ = node_make("TEXT",$1,NULL); } // one TEXT for each word
         | URL { $$ = node_make("LINK",$1,NULL); }
         | inlinetag words TAGSYM { $$ = node_make($1,$2,NULL); }
         | KEYWORD commalist eol { $$ = node_make_take_children("KEYWORD",NULL,$2); }
         | FOOTNOTE body TAGSYM { $$ = node_make_take_children("FOOTNOTE",NULL,$2); }
         | NEWLINE { $$ = node_create("NL"); }
         ;

inlinetag: LINK { $$ = "LINK"; }
         | STRONG { $$ = "STRONG"; }
         | SOFT { $$ = "SOFT"; }
         | EMPHASIS { $$ = "EMPHASIS"; }
         | CODE { $$ = "CODE"; }
         | TELETYPE { $$ = "TELETYPE"; }
         | MATH { $$ = "MATH"; }
         | ANCHOR { $$ = "ANCHOR"; }
;

blocktag: CODEBLOCK { $$ = "CODEBLOCK"; }
        | TELETYPEBLOCK { $$ = "TELETYPEBLOCK"; }
        | MATHBLOCK { $$ = "MATHBLOCK"; }
;

listtag: LIST { $$ = "LIST"; }
       | TREE { $$ = "TREE"; }
       | NUMBEREDLIST { $$ = "NUMBEREDLIST"; }
;
       
tabletag: DEFINITIONLIST { $$ = "DEFINITIONLIST"; }
        | TABLE { $$ = "TABLE"; }
;

rangetag: WARNING { $$ = "WARNING"; }
        | NOTE { $$ = "NOTE"; }
;

listbody: listbody HASHES body { $$ = node_add_child($1, node_make_take_children("ITEM",NULL,$3)); }
        | HASHES body { $$ = node_make("(LISTBODY)",NULL, node_make_take_children("ITEM",NULL,$2)); }
;

tablerow: HASHES tablecells { $$ = node_make_take_children("TABROW",NULL,$2); }
;

tablebody: tablebody tablerow { $$ = node_add_child($1,$2); }
         | tablerow { $$ = node_make("(TABLEBODY)",NULL,$1); }
;

tablecells: tablecells BARS optbody { $$ = node_add_child($1, node_make_take_children("TABCOL",NULL,$3)); }
          | optbody { $$ = node_make("(TABLECELLS)",NULL, node_make_take_children("TABCOL",NULL,$1)); }
;

anywordurl: anyword
          | URL
;

anyword: TEXT
       | COMMA
;

words: words anyword { $$ = strmerge($1,$2); }
     | anyword
;

words2: words2 anywordurl { $$ = strmerge($1,$2); }
      | anywordurl
;

eol: NEWLINE
   | EMPTYLINES
;

anywordnl: anyword
         | eol { $$ = strdup("\n"); }
;

wordsnl: wordsnl anywordnl { $$ = strmerge($1,$2); }
       | anywordnl
;

nocommawords: nocommawords TEXT { $$ = strmerge($1,$2); }
            | nocommawords URL  { $$ = strmerge($1,$2); }
            | TEXT
            | URL
;

commalist: commalist COMMA nocommawords { free($2); $$ = node_add_child($1,node_make("STRING",$3,NULL)); }
         | nocommawords { $$ = node_make("(COMMALIST)",NULL,node_make("STRING",$1,NULL)); }
;

%%

static Node * scdoc_parse_run(int partial) {
    scdoc_start_token = partial? START_PARTIAL : START_FULL;
    topnode = NULL;
    method_type = "METHOD";
    if(scdocparse()!=0) {
        return NULL;
    }
    return topnode;
}

Node * scdoc_parse_file(char *fn, int partial) {
    FILE *fp;
    Node *n;
    
    fp = fopen(fn,"r");
    if(!fp) {
        fprintf(stderr, "scdoc_parse_file: could not open '%s'\n",fn);
        return NULL;
    }
    scdocrestart(fp);
    n = scdoc_parse_run(partial);
    if(!n) {
        fprintf(stderr, "%s: parse error\n",fn);
    }
    fclose(fp);
    return n;
}

/*Node * scdoc_parse_string(char *str, int partial) {
    YY_BUFFER_STATE x = scdoc_scan_string(str);
    Node *n = scdoc_parse_run(partial);
    yy_delete_buffer(x);
    return n;
}*/

int main(int argc, char **argv)
{
    if(argc>1) {
        Node *n;
        if(argc>2 && strcmp(argv[1],"--partial")==0)
            n = scdoc_parse_file(argv[2], 1);
        else
            n = scdoc_parse_file(argv[1], 0);
        if(n)
            node_dump(n,0,1);
        else
            return 1;
    } else {
        fprintf(stderr, "Usage: %s inputfile.schelp\n",argv[0]);
    }
    return 0;
}

