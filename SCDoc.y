%{

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "SCDoc.h"

//#define YYLEX_PARAM &yylval, &yylloc

int scdocparse();

extern int scdoclineno;
extern char *scdoctext;
extern int scdoc_start_token;
extern FILE *scdocin;
//extern struct YYLTYPE scdoclloc;

//int scdoc_metadata_mode;

static const char * method_type = NULL;

static DocNode * topnode;

void scdocerror(const char *str);

%}
%locations
%error-verbose
%union {
    int i;
    const char *id;
    char *str;
    DocNode *doc_node;
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
%token <str> TEXT URL COMMA METHODNAME METHODARGS
%token NEWLINE EMPTYLINES
%token BAD_METHODNAME

%type <id> headtag sectiontag listtag rangetag inlinetag blocktag
%type <str> anyword words anywordnl wordsnl anywordurl words2 nocommawords
%type <doc_node> document arg optreturns optdiscussion body bodyelem
%type <doc_node> optsubsections optsubsubsections methodbody
%type <doc_node> dochead headline optsections sections section
%type <doc_node> subsections subsection subsubsection subsubsections
%type <doc_node> optbody optargs args listbody tablebody tablecells tablerow
%type <doc_node> prose proseelem blockA blockB commalist
%type <doc_node> deflistbody deflistrow defterms methnames optMETHODARGS

%token START_FULL START_PARTIAL START_METADATA

%start start

%destructor { printf("destructing DocNode %s\n",$$?$$->id:NULL); doc_node_free_tree($$); } <doc_node>
%destructor { printf("destructing String '%s'\n",$$); free($$); } <str>

%{
//int scdoclex (YYSTYPE * yylval_param, struct YYLTYPE * yylloc_param );
int scdoclex (void);
%}

%%

start: document { topnode = $1; }
     | document error { topnode = NULL; doc_node_free_tree($1); }
     ;

document: START_FULL dochead optsections
    {
        $$ = doc_node_create("DOCUMENT");
        doc_node_add_child($$, $2);
        doc_node_add_child($$, $3);
    }
       | START_PARTIAL sections
    {
        $$ = doc_node_make_take_children("BODY",NULL,$2);
    }
       | START_METADATA dochead optsections
    {
        $$ = doc_node_create("DOCUMENT");
        doc_node_add_child($$, $2);
        doc_node_add_child($$, $3);
    }
;

dochead: dochead headline { $$ = doc_node_add_child($1,$2); }
       | headline { $$ = doc_node_make("HEADER",NULL,$1); }
;

headline: headtag words2 eol { $$ = doc_node_make($1,$2,NULL); }
        | CATEGORIES commalist eol { $$ = doc_node_make_take_children("CATEGORIES",NULL,$2); }
        | RELATED commalist eol { $$ = doc_node_make_take_children("RELATED",NULL,$2); }
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

sections: sections section { $$ = doc_node_add_child($1,$2); }
        | section { $$ = doc_node_make("BODY",NULL,$1); }
        | subsubsections { $$ = doc_node_make_take_children("BODY",NULL,$1); } /* allow text before first section */
;

section: SECTION { method_type = "METHOD"; } words2 eol optsubsections { $$ = doc_node_make_take_children("SECTION",$3,$5); }
       | sectiontag optsubsections { $$ = doc_node_make_take_children($1, NULL,$2); }
;

optsubsections: subsections
              | { $$ = NULL; }
;

subsections: subsections subsection { $$ = doc_node_add_child($1,$2); }
           | subsection { $$ = doc_node_make("(SUBSECTIONS)",NULL,$1); }
           | subsubsections
;

subsection: SUBSECTION words2 eol optsubsubsections { $$ = doc_node_make_take_children("SUBSECTION", $2, $4); }
;

optsubsubsections: subsubsections
                 | { $$ = NULL; }
;

subsubsections: subsubsections subsubsection { $$ = doc_node_add_child($1,$2); }
              | subsubsection { $$ = doc_node_make("(SUBSUBSECTIONS)",NULL,$1); }
              | body { $$ = doc_node_make_take_children("(SUBSUBSECTIONS)",NULL,$1); }
; 

subsubsection: METHOD methnames optMETHODARGS eol methodbody
    {
        $2->id = "METHODNAMES";
        $$ = doc_node_make(method_type,NULL,$2);
        doc_node_add_child($$, $5);
        doc_node_add_child($2, $3);
    }
             | COPYMETHOD words eol { $$ = doc_node_make("COPYMETHOD",$2,NULL); }
             | PRIVATE commalist eol { $$ = doc_node_make_take_children("PRIVATE",NULL,$2); }
;

optMETHODARGS: { $$ = NULL; }
             | METHODARGS
    {
        $$ = doc_node_make("ARGSTRING",$1,NULL);
        if(method_type!="METHOD") {
            yyerror("METHOD argument string is not allowed inside CLASSMETHODS or INSTANCEMETHODS");
            YYERROR;
        }
    }
;

methnames: methnames COMMA METHODNAME { free($2); $2 = NULL; $$ = doc_node_add_child($1, doc_node_make("STRING",$3,NULL)); }
         | METHODNAME { $$ = doc_node_make("(METHODNAMES)",NULL,doc_node_make("STRING",$1,NULL)); }
;

methodbody: optbody optargs optreturns optdiscussion
    {
        $$ = doc_node_make_take_children("METHODBODY",NULL,$1);
        doc_node_add_child($$, $2);
        doc_node_add_child($$, $3);
        doc_node_add_child($$, $4);
    }
;

optbody: body
       | { $$ = NULL; }
;

optargs: args
       | { $$ = NULL; }
;

args: args arg { $$ = doc_node_add_child($1,$2); }
    | arg { $$ = doc_node_make("ARGUMENTS",NULL,$1); }
;

arg: ARGUMENT words eol optbody { $$ = doc_node_make_take_children("ARGUMENT", $2, $4); }
   | ARGUMENT eol body { $$ = doc_node_make_take_children("ARGUMENT", NULL, $3); }
;

optreturns: RETURNS body { $$ = doc_node_make_take_children("RETURNS",NULL,$2); }
          | { $$ = NULL; }
;

optdiscussion: DISCUSSION body { $$ = doc_node_make_take_children("DISCUSSION",NULL,$2); }
             | { $$ = NULL; }
;

/*
body contains a list of bodyelem's (A) and prose (B) such that
the list can start and end with either A or B, and A can repeat while B can not
*/

body: blockA
    | blockB
    ;

blockA: blockB bodyelem { $$ = doc_node_add_child($1,$2); }
      | blockA bodyelem { $$ = doc_node_add_child($1,$2); }
      | bodyelem { $$ = doc_node_make("(SECTIONBODY)",NULL,$1); }
      ;

blockB: blockA prose { $$ = doc_node_add_child($1,$2); }
      | prose { $$ = doc_node_make("(SECTIONBODY)",NULL,$1); }
      ;

bodyelem: rangetag body TAGSYM { $$ = doc_node_make_take_children($1,NULL,$2); }
        | listtag listbody TAGSYM { $$ = doc_node_make_take_children($1,NULL,$2); }
        | TABLE tablebody TAGSYM { $$ = doc_node_make_take_children("TABLE",NULL,$2); }
        | DEFINITIONLIST deflistbody TAGSYM { $$ = doc_node_make_take_children("DEFINITIONLIST",NULL,$2); }
        | blocktag wordsnl TAGSYM { $$ = doc_node_make($1,$2,NULL); }
        | CLASSTREE words eol { $$ = doc_node_make("CLASSTREE",$2,NULL); }
        | KEYWORD commalist eol { $$ = doc_node_make_take_children("KEYWORD",NULL,$2); }
        | EMPTYLINES { $$ = NULL; }
        | IMAGE words2 TAGSYM { $$ = doc_node_make("IMAGE",$2,NULL); }
        ;

prose: prose proseelem { $$ = doc_node_add_child($1, $2); }
     | proseelem { $$ = doc_node_make("PROSE",NULL,$1); }
     ;

proseelem: anyword { $$ = doc_node_make("TEXT",$1,NULL); } // one TEXT for each word
         | URL { $$ = doc_node_make("LINK",$1,NULL); }
         | inlinetag words TAGSYM { $$ = doc_node_make($1,$2,NULL); }
         | FOOTNOTE body TAGSYM { $$ = doc_node_make_take_children("FOOTNOTE",NULL,$2); }
         | NEWLINE { $$ = doc_node_create("NL"); }
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

listbody: listbody HASHES body { $$ = doc_node_add_child($1, doc_node_make_take_children("ITEM",NULL,$3)); }
        | HASHES body { $$ = doc_node_make("(LISTBODY)",NULL, doc_node_make_take_children("ITEM",NULL,$2)); }
;

tablerow: HASHES tablecells { $$ = doc_node_make_take_children("TABROW",NULL,$2); }
;

tablebody: tablebody tablerow { $$ = doc_node_add_child($1,$2); }
         | tablerow { $$ = doc_node_make("(TABLEBODY)",NULL,$1); }
;

tablecells: tablecells BARS optbody { $$ = doc_node_add_child($1, doc_node_make_take_children("TABCOL",NULL,$3)); }
          | optbody { $$ = doc_node_make("(TABLECELLS)",NULL, doc_node_make_take_children("TABCOL",NULL,$1)); }
;

defterms: defterms HASHES body { $$ = doc_node_add_child($1,doc_node_make_take_children("TERM",NULL,$3)); }
        | HASHES body { $$ = doc_node_make("(TERMS)",NULL,doc_node_make_take_children("TERM",NULL,$2)); }
;

deflistrow: defterms BARS optbody
    {
        $$ = doc_node_make_take_children("DEFLISTITEM", NULL, $1);
        doc_node_add_child($$, doc_node_make_take_children("DEFINITION", NULL, $3));
    }
;

deflistbody: deflistbody deflistrow { $$ = doc_node_add_child($1,$2); }
           | deflistrow { $$ = doc_node_make("(DEFLISTBODY)",NULL,$1); }
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

commalist: commalist COMMA nocommawords { free($2); $2=NULL; $$ = doc_node_add_child($1,doc_node_make("STRING",$3,NULL)); }
         | nocommawords { $$ = doc_node_make("(COMMALIST)",NULL,doc_node_make("STRING",$1,NULL)); }
;

%%

DocNode * scdoc_parse_run(int mode) {
    int modes[] = {START_FULL, START_PARTIAL, START_METADATA};
    if(mode<0 || mode>=sizeof(modes)) {
        fprintf(stderr,"scdoc_parse_run(): unknown mode: %d\n",mode);
    }
    scdoc_start_token = modes[mode];
/*    scdoc_start_token = START_FULL;
    scdoc_metadata_mode = 0;
    if(mode==SCDOC_PARSE_PARTIAL) {
        scdoc_start_token = START_PARTIAL;
    } else
    if(mode==SCDOC_PARSE_METADATA) {
        scdoc_metadata_mode = 1;
    }*/
    topnode = NULL;
    method_type = "METHOD";
    if(scdocparse()!=0) {
        return NULL;
    }
    return topnode;
}

void scdocerror(const char *str)
{
    fprintf(stderr, "In %s:\n  At line %d: %s\n\n",scdoc_current_file,scdoclineno,str);

/*  FIXME: this does not work well, since the reported linenumber is often *after* the actual error line
    fseek(scdocin, 0, SEEK_SET);
    int line = 1;
    char buf[256],*txt;
    while(line!=scdoclineno && !feof(scdocin)) {
        int c = fgetc(scdocin);
        if(c=='\n') line++;
    }
    txt = fgets(buf, 256, scdocin);
    if(txt)
        fprintf(stderr,"  %s\n-------------------\n", txt);
*/
}

