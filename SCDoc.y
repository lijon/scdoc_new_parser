%{

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

#define YYERROR_VERBOSE

#define YYSTYPE char *

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

int sectionlevel;

void yyerror(const char *str)
{
    fprintf(stderr, "error: %s\n",str);
}

int yywrap()
{
    return 1;
}

int main()
{
    sectionlevel = 0;
    yyparse();
}

char *strmerge(char *a, char *b) {
    char *s = (char *)malloc(strlen(a)+strlen(b)+1);
    strcpy(s,a);
    strcat(s,b);
    return s;
}

char *striptrailingws(char *s) {
    char *s2 = strchr(s,0);
    while(--s2 > s && isspace(*s2)) {
        *s2 = 0;
    }
    return s;
}

%}

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
%token TEXT WHITESPACES EOL EMPTYLINES

%start document

%%

document: dochead sections
        ;

dochead: dochead headline
       | headline
       ;

headline: headtag words2 eol { printf("HEADERLINE: %s '%s'\n",$1,striptrailingws($2)); }
        ;

optws:
     | WHITESPACES
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

sectiontag: CLASSMETHODS
          | INSTANCEMETHODS
          | DESCRIPTION
          | EXAMPLES
          ;
sections: sections section { $$ = strmerge($1,$2); }
        | section { $$ = $1; }
        ;
section: SECTION words2 eol optsubsections { $$ = $4; printf("SECTION:%s\n",$2); }
       | sectiontag eol optsubsections { printf("FIXED SECTION\n"); }
       ;

optsubsections: subsections
              |
              ;
subsections: subsections subsection { $$ = strmerge($1,$2); }
           | subsection { $$ = $1; }
           | subsubsections { $$ = $1; }
           ;

subsection: SUBSECTION words2 eol optsubsubsections { $$ = $4; printf("SUBSECTION:%s\n",$2); }
          ;

optsubsubsections: subsubsections
                 |
                 ;
subsubsections: subsubsections subsubsection { $$ = strmerge($1,$2); }
              | subsubsection { $$ = $1; }
              | body  { $$ = $1; }
              ; 

subsubsection: METHOD words2 eol methodbody { $$ = $4; printf("METHOD:%s\n",$2); }
             ;

methodbody: optbody optargs optreturns optdiscussion
          ;
optbody: body
       |
       ;
optargs: args
       |
       ;
args: args arg
    | arg
    ;
arg: ARGUMENT words2 eol body { printf("ARGUMENT:%s\n",$2); }
   ;
optreturns: RETURNS body { printf("RETURNS:%s\n",$2); }
          |
          ;
optdiscussion: DISCUSSION body { printf("DISCUSSION:%s\n",$2); }
             |
             ;

body: body bodyelem { $$ = strmerge($1,$2); }
    | bodyelem { $$ = $1; }
    ;

bodyelem: rangetag body TAGSYM { printf("RANGETAG: %s '%s'\n",$1,$2); $$ = $2; }
        | listtag eatws listbody TAGSYM { printf("LISTTAG: %s '%s'\n",$1,$2); $$ = $2; }
        | tabletag eatws tablebody TAGSYM { printf("TABLETAG: %s '%s'\n",$1,$2); $$ = $2; }
        | modaltag wordsnl TAGSYM { printf("MODALTAG: %s '%s'\n",$1,$2); $$ = $2; }
        | singletag words2 eol { printf("SINGLETAG: %s '%s'\n",$1,$2); $$ = $2; }
        | anywordnl { $$ = $1; }
        ;

eatws: eatws anyws
     | anyws
     ;

listbody: listbody HASHES body
        | HASHES body
        ;

tablebody: tablebody HASHES body optcells
        | HASHES body optcells
        ;

optcells: tablecells
        |
        ;

tablecells: tablecells BARS body
         | BARS body
         ;

singletag: CLASSTREE
         | COPYMETHOD
         | KEYWORD
         | PRIVATE
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

listtag: LIST
       | TREE
       | NUMBEREDLIST
       ;
       
tabletag: DEFINITIONLIST
       | TABLE
       ;

rangetag: FOOTNOTE
        | WARNING
        | NOTE
        ;


anyws: WHITESPACES
     | eol
     ;

anyword: TEXT { $$ = $1; }
       | WHITESPACES { $$ = $1; }
       ;

words: words anyword { $$ = strmerge($1,$2); }
     | anyword { $$ = $1; }
     ;

eol: EOL { $$ = "\n"; }
   | EMPTYLINES { $$ = "\n-------\n"; }
   ;

anywordnl: anyword { $$ = $1; }
         | eol { $$ = $1; }
         ;

wordsnl: wordsnl anywordnl { $$ = strmerge($1,$2); }
       | anywordnl { $$ = $1; }
       ;

