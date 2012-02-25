%{


#include <cstring>
#define YYSTYPE char *
#include "SCDoc.tab.h"

/*
[a-zA-Z]+       { yylval = strdup(yytext); printf("WORD:'%s'\n",yylval); return WORD; }
*/

%}


%%

[ \t\r]+  {
    yylval = strdup(yytext);
    printf("-- WHITESPACE:'%s'\n",yylval);
    return WHITESPACES;
}

class::         printf("-- CLASS\n"); return CLASS;
title::         printf("-- TITLE\n"); return TITLE;
summary::       printf("-- SUMMARY\n"); return SUMMARY;

code::          printf("-- CODE\n"); return CODE;
note::          printf("-- NOTE\n"); return NOTE;

section::       printf("-- SECTION\n"); return SECTION;
subsection::    printf("-- SUBSECTION\n"); return SUBSECTION;
method::        printf("-- METHOD\n"); return METHOD;
argument::      printf("-- ARGUMENT\n"); return ARGUMENT;

::              printf("-- TAGSYM\n"); return TAGSYM;

\|\|            return BARS;

\n              printf("-- EOL\n"); return EOL;
\n\n+           printf("-- EMPTYLINES\n"); return EMPTYLINES;

:               |
\\::            |
[^:\\\n\t\r ]+    yylval = strdup(yytext); printf("-- TEXT:'%s'\n",yylval); return TEXT;

%%
