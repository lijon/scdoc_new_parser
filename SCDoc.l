%{


#include <string.h>
//#define YYSTYPE char *
#include "SCDoc.h"
#include "SCDoc.tab.h"

%}

%option yylineno
  /* %option bison-locations */

%%

[ \t\r]+  {
    yylval.str = strdup(yytext);
    return WHITESPACES;
}

(?i:class::)         return CLASS;
(?i:title::)         return TITLE;
(?i:summary::)       return SUMMARY;
(?i:related::)       return RELATED;
(?i:categories::)    return CATEGORIES;
(?i:redirect::)      return REDIRECT;

(?i:classtree::)     return CLASSTREE;
(?i:copymethod::)    return COPYMETHOD;
(?i:keyword::)       return KEYWORD;
(?i:private::)       return PRIVATE;

(?i:section::)       return SECTION;
(?i:subsection::)    return SUBSECTION;
(?i:method::)        return METHOD;
(?i:argument::)      return ARGUMENT;

(?i:description::)   return DESCRIPTION;
(?i:classmethods::)  return CLASSMETHODS;
(?i:instancemethods::) return INSTANCEMETHODS;
(?i:examples::)      return EXAMPLES;
(?i:returns::)       return RETURNS;
(?i:discussion::)    return DISCUSSION;

(?i:list::)          return LIST;
(?i:tree::)          return TREE;
(?i:numberedlist::)  return NUMBEREDLIST;
(?i:definitionlist::) return DEFINITIONLIST;
(?i:table::)         return TABLE;
(?i:footnote::)      return FOOTNOTE;
(?i:warning::)       return WARNING;
(?i:note::)          return NOTE;

(?i:link::)          return LINK;
(?i:anchor::)        return ANCHOR;
(?i:soft::)          return SOFT;
(?i:image::)         return IMAGE;
(?i:strong::)        return STRONG;
(?i:emphasis::)      return EMPHASIS;

(?i:code::)          return CODE;
(?i:teletype::)      return TELETYPE;
(?i:math::)          return MATH;

(?i:code::[ \t]*\n+)          return CODEBLOCK;
(?i:teletype::[ \t]*\n+)      return TELETYPEBLOCK;
(?i:math::[ \t]*\n+)          return MATHBLOCK;

::              return TAGSYM;
\|\|            return BARS;
\#\#            return HASHES;

\n              return EOL;
\n\n+           return EMPTYLINES;

\\::            |
[a-zA-Z0-9]+    |
[^:\\\n\t\r ]   |
.               yylval.str = strdup(yytext); return TEXT;

%%

/*
:               |
\\::            |
[^:\\\n\t\r ]+    yylval.str = strdup(yytext); return TEXT;
*/
