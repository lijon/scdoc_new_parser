%{

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include "SCDoc.h"

/*
TODO:

"optws words2" strips heading whitespace.
is it possible to make a similar rule that strips trailing whitespace?
if not, get rid of words2 and just use a function to strip ws before putting it into the syntax tree.

could we make classmethods:: etc usable only if the doc started with class:: ?
or should we deprecate class:: and just use title::?

merge TEXT nodes into single PROSE nodes

strip beginning and ending whitespace for node->text in all nodes?
no, not for TEXT when it's broken by another tag..
so for TEXT, only strip start after parbreak or section?

PROSE means insert <p>  (but maybe not in list items etc?)

replace node->children with a linked list (node->next and node->tail)?

Is there actually any need for WHITESPACES token? why not just treat it as TEXT?

*/

extern int yyparse();
extern int yylex();
extern int yylineno;
extern char *yytext;
void yyerror(const char *str)
{
    fprintf(stderr, "%s.\n    At line %d: '%s'\n",str,yylineno,yytext);
}

int yywrap()
{
    return 1;
}

int main()
{
    yyparse();
}

// merge a+b and free b
char *strmerge(char *a, char *b) {
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
%token <str> TEXT WHITESPACES
%token <i> EOL EMPTYLINES

%type <i> eol
%type <id> headtag sectiontag singletag listtag rangetag tabletag inlinetag blocktag
%type <str> words2 anyword words anywordnl wordsnl
%type <node> arg optreturns optdiscussion body bodyelem 
%type <node> optsubsections optsubsubsections methodbody  
%type <node> dochead headline optsections sections section
%type <node> subsections subsection subsubsection subsubsections
%type <node> optbody optargs args listbody tablebody tablecells tablerow
%type <node> prose proseelem blockA blockB

// %type <str> wordsnl2 anywordnl2

%start document

%%

document: dochead optsections
    {
        Node *n = node_create("DOCUMENT");
        node_add_child(n, $1);
        node_add_child(n, $2);
        node_dump(n,0,1);
    }
;

dochead: dochead headline { $$ = node_add_child($1,$2); }
       | headline { $$ = node_make("HEADER",NULL,$1); }
;

headline: headtag words2 eol { $$ = node_make($1,striptrailingws($2),NULL); }
;

optws:
     | WHITESPACES { free($1); }
;

words2: optws TEXT { $$ = $2; }
      | optws TEXT words { $$ = strmerge($2, $3); }
;

headtag: CLASS { $$ = "CLASS"; }
       | TITLE { $$ = "TITLE"; }
       | SUMMARY { $$ = "SUMMARY"; }
       | RELATED { $$ = "RELATED"; }
       | CATEGORIES { $$ = "CATEGORIES"; }
       | REDIRECT { $$ = "REDIRECT"; }
;

sectiontag: CLASSMETHODS { $$ = "CLASSMETHODS"; }
          | INSTANCEMETHODS { $$ = "INSTANCEMETHODS"; }
          | DESCRIPTION { $$ = "DESCRIPTION"; }
          | EXAMPLES { $$ = "EXAMPLES"; }
;

optsections: sections
           | { $$ = NULL; }
;

sections: sections section { $$ = node_add_child($1,$2); }
        | section { $$ = node_make("BODY",NULL,$1); }
        | subsections /* allow text before first section */
;

section: SECTION words2 eol optsubsections { $$ = node_make_take_children("SECTION",$2,$4); }
       | sectiontag eol optsubsections { $$ = node_make_take_children($1, NULL,$3); }
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

subsubsection: METHOD words2 eol methodbody { $$ = node_make_take_children("METHOD",$2,$4); }
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

arg: ARGUMENT words2 eol body { $$ = node_make_take_children("ARGUMENT", $2, $4); }
;

optreturns: RETURNS body { $$ = node_make_take_children("RETURNS",NULL,$2); }
          | { $$ = NULL; }
;

optdiscussion: DISCUSSION body { $$ = node_make_take_children("DISCUSSION",NULL,$2); }
             | { $$ = NULL; }
;

//body: body bodyelem { $$ = node_add_child($1,$2); }
//    | bodyelem { $$ = node_make("(SECTIONBODY)",NULL,$1); }
//    ;

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
        | listtag eatws listbody TAGSYM { $$ = node_make_take_children($1,NULL,$3); }
        | tabletag eatws tablebody TAGSYM { $$ = node_make_take_children($1,NULL,$3); }
        | blocktag wordsnl TAGSYM { $$ = node_make($1,$2,NULL); }
        | singletag words2 eol { $$ = node_make($1,$2,NULL); }
        | EMPTYLINES { $$ = NULL; }
        | IMAGE words TAGSYM { $$ = node_make("IMAGE",$2,NULL); }
        ;

prose: prose proseelem { $$ = node_add_child($1, $2); }
     | proseelem { $$ = node_make("PROSE",NULL,$1); }
     ;

proseelem: // words { $$ = node_make("TEXT",$1,NULL); } // 2 shift/reduce conflicts
           anyword { $$ = node_make("TEXT",$1,NULL); } // one TEXT for each word
         | inlinetag words TAGSYM { $$ = node_make($1,$2,NULL); }
         | FOOTNOTE body TAGSYM { $$ = node_make("FOOTNOTE",NULL,$2); }
         | EOL { $$ = node_create("NL"); }
         ;
/*
the 2 shift/reduce conflicts using 'words' above is due to prose list vs words list:
    prose(proseelem(words(word1, word2)))
vs
    prose(proseelem(words(word1)), proseelem(words(word2)))
we want the first one..

Probably solvable by using two alternating lists similar to blockA/blockB above?
*/

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

singletag: CLASSTREE { $$ = "CLASSTREE"; }
         | COPYMETHOD { $$ = "COPYMETHOD"; }
         | KEYWORD { $$ = "KEYWORD"; }
         | PRIVATE { $$ = "PRIVATE"; }
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

eatws: eatws anyws
     | anyws
;

listbody: listbody HASHES body { $$ = node_add_child($1, node_make_take_children("ITEM",NULL,$3)); }
        | HASHES body { $$ = node_make("(LISTBODY)",NULL, node_make_take_children("ITEM",NULL,$2)); }
;

tablerow: HASHES tablecells { $$ = node_make_take_children("TABROW",NULL,$2); }
;

tablebody: tablebody tablerow { $$ = node_add_child($1,$2); }
         | tablerow { $$ = node_make("(TABLEBODY)",NULL,$1); }
;

tablecells: tablecells BARS body { $$ = node_add_child($1, node_make_take_children("TABCOL",NULL,$3)); }
          | body { $$ = node_make("(TABLECELLS)",NULL, node_make_take_children("TABCOL",NULL,$1)); }
;



anyws: WHITESPACES { free($1); }
     | eol
;

anyword: TEXT
       | WHITESPACES
;

words: words anyword { $$ = strmerge($1,$2); }
     | anyword
;

eol: EOL { $$ = 0; }
   | EMPTYLINES { $$ = 1; }
;

anywordnl: anyword
         | eol { $$ = strdup("\n"); }
;

wordsnl: wordsnl anywordnl { $$ = strmerge($1,$2); }
       | anywordnl
;

