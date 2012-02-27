%{


#include <string.h>
//#define YYSTYPE char *
#include "SCDoc.h"
#include "SCDoc.tab.h"

%}

%option yylineno
  /* %option bison-locations */

%x verbatim
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

(?i:link::)          BEGIN(verbatim); return LINK;
(?i:anchor::)        BEGIN(verbatim); return ANCHOR;
(?i:soft::)          BEGIN(verbatim); return SOFT;
(?i:image::)         BEGIN(verbatim); return IMAGE;
(?i:strong::)        BEGIN(verbatim); return STRONG;
(?i:emphasis::)      BEGIN(verbatim); return EMPHASIS;

(?i:code::)          BEGIN(verbatim); return CODE;
(?i:teletype::)      BEGIN(verbatim); return TELETYPE;
(?i:math::)          BEGIN(verbatim); return MATH;

(?i:code::[ \t]*\n+)          BEGIN(verbatim); return CODEBLOCK;
(?i:teletype::[ \t]*\n+)      BEGIN(verbatim); return TELETYPEBLOCK;
(?i:math::[ \t]*\n+)          BEGIN(verbatim); return MATHBLOCK;

<*>::    BEGIN(0); return TAGSYM;
\|\|            return BARS;
\#\#            return HASHES;

\n              return EOL;
\n\n+           return EMPTYLINES;

<*>\\::            yylval.str = strdup("::"); return TEXT;
[a-zA-Z0-9.,!?]+    |
[^:\\\n\t\r ]   |
.               yylval.str = strdup(yytext); return TEXT;
<verbatim>[^:\\]+    yylval.str = strdup(yytext); return TEXT;
%%

