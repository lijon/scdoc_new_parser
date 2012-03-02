%{

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "SCDoc.h"

int scdocparse();
int scdoclex();

//YY_BUFFER_STATE scdoc_scan_string(const char *str);

extern int scdoclineno;
extern char *scdoctext;
extern int scdoc_start_token;

static const char * method_type = NULL;

static Node * topnode;

void scdocerror(const char *str)
{
    char *text = strdup(scdoctext);
    char *eol = strchr(text, '\n');
    if(eol) *eol = '\0';
    fprintf(stderr, "In %s:\n  %s\n  At line %d: %s\n\n",scdoc_current_file,str,scdoclineno,text);
    free(text);
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

%type <id> headtag sectiontag listtag rangetag inlinetag blocktag
%type <str> anyword words anywordnl wordsnl anywordurl words2 nocommawords
%type <node> arg optreturns optdiscussion body bodyelem 
%type <node> optsubsections optsubsubsections methodbody  
%type <node> dochead headline optsections sections section
%type <node> subsections subsection subsubsection subsubsections
%type <node> optbody optargs args listbody tablebody tablecells tablerow
%type <node> prose proseelem blockA blockB commalist
%type <node> deflistbody deflistrow defterms

%token START_FULL START_PARTIAL

%start document

%%

document: START_FULL dochead optsections
    {
        Node *n = node_create("DOCUMENT");
        node_add_child(n, $2);
        node_add_child(n, $3);
        topnode = n;
    }
       | START_PARTIAL sections
    {
        Node *n = node_make_take_children("BODY",NULL,$2);
        topnode = n;
    }
;

dochead: dochead headline { $$ = node_add_child($1,$2); }
       | headline { $$ = node_make("HEADER",NULL,$1); }
;

headline: headtag words2 eol { $$ = node_make($1,$2,NULL); }
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
        | TABLE tablebody TAGSYM { $$ = node_make_take_children("TABLE",NULL,$2); }
        | DEFINITIONLIST deflistbody TAGSYM { $$ = node_make_take_children("DEFINITIONLIST",NULL,$2); }
        | blocktag wordsnl TAGSYM { $$ = node_make($1,$2,NULL); }
        | CLASSTREE words eol { $$ = node_make("CLASSTREE",$2,NULL); }
        | KEYWORD commalist eol { $$ = node_make_take_children("KEYWORD",NULL,$2); }
        | EMPTYLINES { $$ = NULL; }
        | IMAGE words2 TAGSYM { $$ = node_make("IMAGE",$2,NULL); }
        ;

prose: prose proseelem { $$ = node_add_child($1, $2); }
     | proseelem { $$ = node_make("PROSE",NULL,$1); }
     ;

proseelem: anyword { $$ = node_make("TEXT",$1,NULL); } // one TEXT for each word
         | URL { $$ = node_make("LINK",$1,NULL); }
         | inlinetag words TAGSYM { $$ = node_make($1,$2,NULL); }
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

defterms: defterms HASHES body { $$ = node_add_child($1,node_make_take_children("TERM",NULL,$3)); }
        | HASHES body { $$ = node_make("(TERMS)",NULL,node_make_take_children("TERM",NULL,$2)); }
;

deflistrow: defterms BARS optbody
    {
        $$ = node_make_take_children("DEFLISTITEM", NULL, $1);
        node_add_child($$, node_make_take_children("DEFINITION", NULL, $3));
    }
;

deflistbody: deflistbody deflistrow { $$ = node_add_child($1,$2); }
           | deflistrow { $$ = node_make("(DEFLISTBODY)",NULL,$1); }
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

Node * scdoc_parse_run(int partial) {
    scdoc_start_token = partial? START_PARTIAL : START_FULL;
    topnode = NULL;
    method_type = "METHOD";
    if(scdocparse()!=0) {
        return NULL;
    }
    return topnode;
}



