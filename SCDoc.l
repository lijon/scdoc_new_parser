%{


#include <cstring>
#define YYSTYPE char *
#include "SCDoc.tab.h"

%}

%%

[ \t\r]+  {
    yylval = strdup(yytext);
    return WHITESPACES;
}

class::         return CLASS;
title::         return TITLE;
summary::       return SUMMARY;
related::       return RELATED;
categories::    return CATEGORIES;
redirect::      return REDIRECT;

classtree::     return CLASSTREE;
copymethod::    return COPYMETHOD;
keyword::       return KEYWORD;
private::       return PRIVATE;

section::       return SECTION;
subsection::    return SUBSECTION;
method::        return METHOD;
argument::      return ARGUMENT;

description::   return DESCRIPTION;
classmethods::  return CLASSMETHODS;
instancemethods:: return INSTANCEMETHODS;
examples::      return EXAMPLES;
returns::       return RETURNS;
discussion::    return DISCUSSION;

list::          return LIST;
tree::          return TREE;
numberedlist::  return NUMBEREDLIST;
definitionlist:: return DEFINITIONLIST;
table::         return TABLE;
footnote::      return FOOTNOTE;
warning::       return WARNING;
note::          return NOTE;

link::          return LINK;
anchor::        return ANCHOR;
soft::          return SOFT;
image::         return IMAGE;
teletype::      return TELETYPE;
math::          return MATH;
strong::        return STRONG;
emphasis::      return EMPHASIS;
code::          return CODE;

::              return TAGSYM;
\|\|            return BARS;
\#\#            return HASHES;

\n              return EOL;
\n\n+           return EMPTYLINES;

:               |
\\::            |
[^:\\\n\t\r ]+    yylval = strdup(yytext); printf("-- %s\n",yytext); return TEXT;

%%
