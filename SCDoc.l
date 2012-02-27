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

(?i:class::[ \t]*)         return CLASS;
(?i:title::[ \t]*)         return TITLE;
(?i:summary::[ \t]*)       return SUMMARY;
(?i:related::[ \t]*)       return RELATED;
(?i:categories::[ \t]*)    return CATEGORIES;
(?i:redirect::[ \t]*)      return REDIRECT;

(?i:classtree::[ \t]*)     return CLASSTREE;
(?i:copymethod::[ \t]*)    return COPYMETHOD;
(?i:keyword::[ \t]*)       return KEYWORD;
(?i:private::[ \t]*)       return PRIVATE;

(?i:section::[ \t]*)       return SECTION;
(?i:subsection::[ \t]*)    return SUBSECTION;
(?i:method::[ \t]*)        return METHOD;
(?i:[ \t\n]*argument::[ \t]*)      return ARGUMENT;

(?i:description::[ \t\n]*)   return DESCRIPTION;
(?i:classmethods::[ \t\n]*)  return CLASSMETHODS;
(?i:instancemethods::[ \t\n]*) return INSTANCEMETHODS;
(?i:examples::[ \t\n]*)      return EXAMPLES;

(?i:returns::[ \t\n]*)       return RETURNS;
(?i:discussion::[ \t\n]*)    return DISCUSSION;

(?i:[ \t\n]*list::[ \t\n]*)          return LIST;
(?i:[ \t\n]*tree::[ \t\n]*)          return TREE;
(?i:[ \t\n]*numberedlist::[ \t\n]*)  return NUMBEREDLIST;
(?i:[ \t\n]*definitionlist::[ \t\n]*) return DEFINITIONLIST;
(?i:[ \t\n]*table::[ \t\n]*)         return TABLE;
(?i:[ \t\n]*footnote::[ \t\n]*)      return FOOTNOTE;
(?i:[ \t\n]*warning::[ \t\n]*)       return WARNING;
(?i:[ \t\n]*note::[ \t\n]*)          return NOTE;

(?i:link::[ \t]*)          BEGIN(verbatim); return LINK;
(?i:anchor::[ \t]*)        BEGIN(verbatim); return ANCHOR;
(?i:soft::[ \t]*)          BEGIN(verbatim); return SOFT;
(?i:image::[ \t]*)         BEGIN(verbatim); return IMAGE;
(?i:strong::[ \t]*)        BEGIN(verbatim); return STRONG;
(?i:emphasis::[ \t]*)      BEGIN(verbatim); return EMPHASIS;

(?i:code::[ \t]*)          BEGIN(verbatim); return CODE;
(?i:teletype::[ \t]*)      BEGIN(verbatim); return TELETYPE;
(?i:math::[ \t]*)          BEGIN(verbatim); return MATH;

(?i:[ \t\n]*code::[ \t]*\n+)          BEGIN(verbatim); return CODEBLOCK;
(?i:[ \t\n]*teletype::[ \t]*\n+)      BEGIN(verbatim); return TELETYPEBLOCK;
(?i:[ \t\n]*math::[ \t]*\n+)          BEGIN(verbatim); return MATHBLOCK;

<*>[ \t\n]*::    BEGIN(0); return TAGSYM;
[ \t\n]*\|\|[ \t\n]*            return BARS;
[ \t\n]*\#\#[ \t\n]*            return HASHES;

\n              return EOL;
\n\n+           return EMPTYLINES;

<*>\\::         yylval.str = strdup("::"); return TEXT;

[a-zA-Z0-9]+    |
[.,!?()]+       |
<verbatim>[ \t\r]+ |
<verbatim>[^:\\ ]+ |
[^:\\\n]        |
<*>.            yylval.str = strdup(yytext); return TEXT;

%%

