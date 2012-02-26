%{

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include "SCDoc.h"

//#define YYERROR_VERBOSE

//#define YYSTYPE char *

/*
TODO:

use a union for flex token types? or do we only need strings?
no, we need a tree already here. just a simple node with type, string and children.
then we traverse this tree to create an internal representation of the document tree,
or straight to sclang objects? or at least compress prose into PROSE nodes?

would it be possibe to make newline separated paragraphs part of the grammar?
that is, have a rule that ends with EOL EOL or EOL $end
the idea was that docbody consists of a list of paragraphs, and a paragraph consists
of a list of body elements. But, the bodyelements should be able to contain paragraphs too!
(for example, multiple paragraphs inside a section, or inside a note::, etc..
perhaps better to just match EOL2 as a paragraph separator?

"optws words2" strips heading whitespace.
is it possible to make a similar rule that strips trailing whitespace?
if not, get rid of words2 and just use a function to strip ws before putting it into the syntax tree.

could we make classmethods:: etc usable only if the doc started with class:: ?
or should we deprecate class:: and just use title::?
*/

extern int yyparse();
extern int yylex();
//int yylex ( YYSTYPE * lvalp, YYLTYPE * llocp);
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

char *strmerge(char *a, char *b) {
    char *s = (char *)malloc(strlen(a)+strlen(b)+1);
    strcpy(s,a);
    strcat(s,b);
    return s;
}

// merge strings and free the old ones
char *strmergefree(char *a, char *b) {
    char *s = strmerge(a,b);
    free(a);
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
Node * node_add_text(Node *n, char *text) {
    if(n->text) {
        char *str = strmergefree(n->text,text);
        n->text = str;
    } else {
        n->text = text;
    }
    return n;
}

Node * node_make(const char *id, char *text, Node *child) {
    Node *n = node_create(id);
    node_add_text(n, text);
    node_add_child(n, child);
    return n;
}

void node_dump(Node *n, int level) {
    int i = level;
    while(i--) printf("  ");
    printf("%s",n->id);
    if(n->text) printf(" \"%s\"",n->text);
//    printf(" (%d)\n",n->n_childs);
    printf("\n");
    for(i = 0; i < n->n_childs; i++) {
        node_dump(n->children[i], level+1);
    }
}

%}
%locations
%error-verbose
%union {
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
// symbols
%token TAGSYM BARS HASHES
// text and whitespace
%token <str> TEXT WHITESPACES
%token EOL EMPTYLINES

%type <id> headtag sectiontag singletag listtag modaltag rangetag tabletag
%type <str> words2 anyword words anywordnl wordsnl
%type <node> arg optreturns optdiscussion body bodyelem 
%type <node> optsubsections optsubsubsections methodbody  
%type <node> dochead headline optsections sections section
%type <node> subsections subsection subsubsection subsubsections
%type <node> optbody optargs args listbody tablebody optcells tablecells

%start document

%%

document: dochead optsections
    {
        Node *n = node_create("ROOT");
        node_add_child(n, $1);
        node_add_child(n, $2);
        node_dump(n,0);
    }
;

optsections: sections
           | { $$ = NULL; }
;

dochead: dochead headline { $$ = node_add_child($1,$2); }
       | headline { $$ = node_make("HEADER",NULL,$1); }
;

headline: headtag words eol
    {
        $$ = node_make($1,striptrailingws($2),NULL);
    }
;

optws:
     | WHITESPACES { free($1); }
;

words2: optws TEXT { $$ = $2; }
      | optws TEXT words
      {
          $$ = strmergefree($2, $3);
      }
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

sections: sections section { $$ = node_add_child($1,$2); }
        | section { $$ = node_make("BODY",NULL,$1); }
;

section: SECTION words2 eol optsubsections
    {
        $$ = node_make("SECTION",$2,$4);
    }
       | sectiontag eol optsubsections
    {
        $$ = node_make($1, NULL, $3);
    }
;

optsubsections: subsections
              | { $$ = NULL; }
;

subsections: subsections subsection { $$ = node_add_child($1,$2); }
           | subsection { $$ = node_make(NULL,NULL,$1); }
           | subsubsections { $$ = node_make(NULL,NULL,$1); }
;

subsection: SUBSECTION words2 eol optsubsubsections
    {
        $$ = node_make("SUBSECTION", $2, $4);
    }
;

optsubsubsections: subsubsections
                 | { $$ = NULL; }
;

subsubsections: subsubsections subsubsection { $$ = node_add_child($1,$2); }
              | subsubsection { $$ = node_make(NULL,NULL,$1); }
              | body { $$ = node_make(NULL,NULL,$1); }
; 

subsubsection: METHOD words2 eol methodbody
    {
        $$ = node_make("METHOD",$2,$4);
    }
;

methodbody: optbody optargs optreturns optdiscussion
    {
        $$ = node_create(NULL); //METHODBODY
        node_add_child($$, $1);
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
    | arg { $$ = node_make(NULL,NULL,$1); }
;

arg: ARGUMENT words2 eol body
    {
        $$ = node_make("ARGUMENT", $2, $4);
    }
;

optreturns: RETURNS body { $$ = node_make("RETURNS",NULL,$2); }
          | { $$ = NULL; }
;

optdiscussion: DISCUSSION body { $$ = node_make("DISCUSSION",NULL,$2); }
             | { $$ = NULL; }
;

body: body bodyelem { $$ = node_add_child($1,$2); }
    | bodyelem { $$ = node_make(NULL,NULL,$1); }
    ;

bodyelem: rangetag body TAGSYM { $$ = node_make($1,NULL,$2); }
        | listtag eatws listbody TAGSYM { $$ = node_make($1,NULL,$3); }
        | tabletag eatws tablebody TAGSYM { $$ = node_make($1,NULL,$3); }
        | modaltag wordsnl TAGSYM { $$ = node_make($1,$2,NULL); }
        | singletag words2 eol { $$ = node_make($1,$2,NULL); }
        | anywordnl { $$ = node_make("TEXT",$1,NULL); }
        ;

eatws: eatws anyws
     | anyws
     ;

listbody: listbody HASHES body { $$ = node_add_child($1, node_make("HASHES",NULL,$3)); }
        | HASHES body { $$ = node_make(NULL,NULL, node_make("HASHES",NULL,$2)); }
        ;

tablebody: tablebody HASHES body optcells  { $$ = node_add_child($1, node_add_child(node_make("HASHES",NULL,$3),$4)); }
        | HASHES body optcells { $$ = node_make(NULL,NULL, node_add_child(node_make("HASHES",NULL,$3),$3)); }
        ;

optcells: tablecells
        | { $$ = NULL; }
        ;

tablecells: tablecells BARS body { $$ = node_add_child($1, node_make("BARS",NULL,$3)); }
         | BARS body { $$ = node_make(NULL,NULL, node_make("BARS",NULL,$2)); }
         ;

singletag: CLASSTREE { $$ = "CLASSTREE"; }
         | COPYMETHOD { $$ = "COPYMETHOD"; }
         | KEYWORD { $$ = "KEYWORD"; }
         | PRIVATE { $$ = "PRIVATE"; }
         ;

modaltag: CODE { $$ = "CODE"; }
        | LINK { $$ = "LINK"; }
        | IMAGE { $$ = "IMAGE"; }
        | TELETYPE { $$ = "TELETYPE"; }
        | MATH { $$ = "MATH"; }
        | STRONG { $$ = "STRONG"; }
        | SOFT { $$ = "SOFT"; }
        | ANCHOR { $$ = "ANCHOR"; }
        | EMPHASIS { $$ = "EMPHASIS"; }
        ;

listtag: LIST { $$ = "LIST"; }
       | TREE { $$ = "TREE"; }
       | NUMBEREDLIST { $$ = "NUMBEREDLIST"; }
       ;
       
tabletag: DEFINITIONLIST { $$ = "DEFINITIONLIST"; }
       | TABLE { $$ = "TABLE"; }
       ;

rangetag: FOOTNOTE { $$ = "FOOTNOTE"; }
        | WARNING { $$ = "WARNING"; }
        | NOTE { $$ = "NOTE"; }
        ;

anyws: WHITESPACES { free($1); }
     | eol
     ;

anyword: TEXT
       | WHITESPACES
       ;

words: words anyword { $$ = strmergefree($1,$2); }
     | anyword
     ;

eol: EOL
   | EMPTYLINES
   ;

anywordnl: anyword
         | eol { $$ = strdup("\n"); }
         ;

wordsnl: wordsnl anywordnl { $$ = strmergefree($1,$2); }
       | anywordnl
       ;

