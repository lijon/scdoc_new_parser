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

(?i:[ \t]*class::[ \t]*)         return CLASS;
(?i:[ \t]*title::[ \t]*)         return TITLE;
(?i:[ \t]*summary::[ \t]*)       return SUMMARY;
(?i:[ \t]*related::[ \t]*)       return RELATED;
(?i:[ \t]*categories::[ \t]*)    return CATEGORIES;
(?i:[ \t]*redirect::[ \t]*)      return REDIRECT;

(?i:[ \t]*classtree::[ \t]*)     return CLASSTREE;
(?i:[ \t]*copymethod::[ \t]*)    return COPYMETHOD;
(?i:[ \t]*keyword::[ \t]*)       return KEYWORD;
(?i:[ \t]*private::[ \t]*)       return PRIVATE;

(?i:[ \t]*section::[ \t]*)       return SECTION;
(?i:[ \t]*subsection::[ \t]*)    return SUBSECTION;
(?i:[ \t]*method::[ \t]*)        return METHOD;
(?i:[ \t]*argument::[ \t]*)      return ARGUMENT;

(?i:[ \t]*description::[ \t\n]*)   return DESCRIPTION;
(?i:[ \t]*classmethods::[ \t\n]*)  return CLASSMETHODS;
(?i:[ \t]*instancemethods::[ \t\n]*) return INSTANCEMETHODS;
(?i:[ \t]*examples::[ \t\n]*)      return EXAMPLES;

(?i:[ \t]*returns::[ \t\n]*)       return RETURNS;
(?i:[ \t]*discussion::[ \t\n]*)    return DISCUSSION;

(?i:[ \t]*list::[ \t\n]*)          return LIST;
(?i:[ \t]*tree::[ \t\n]*)          return TREE;
(?i:[ \t]*numberedlist::[ \t\n]*)  return NUMBEREDLIST;
(?i:[ \t]*definitionlist::[ \t\n]*) return DEFINITIONLIST;
(?i:[ \t]*table::[ \t\n]*)         return TABLE;
(?i:[ \t]*footnote::[ \t\n]*)      return FOOTNOTE;
(?i:[ \t]*warning::[ \t\n]*)       return WARNING;
(?i:[ \t]*note::[ \t\n]*)          return NOTE;

(?i:link::[ \t]*)          BEGIN(verbatim); return LINK;
(?i:anchor::[ \t]*)        BEGIN(verbatim); return ANCHOR;
(?i:soft::[ \t]*)          BEGIN(verbatim); return SOFT;
(?i:image::[ \t]*)         BEGIN(verbatim); return IMAGE;
(?i:strong::[ \t]*)        BEGIN(verbatim); return STRONG;
(?i:emphasis::[ \t]*)      BEGIN(verbatim); return EMPHASIS;
(?i:code::[ \t]*)          BEGIN(verbatim); return CODE;
(?i:teletype::[ \t]*)      BEGIN(verbatim); return TELETYPE;
(?i:math::[ \t]*)          BEGIN(verbatim); return MATH;

(?i:[ \t]*code::[ \t]*\n+)          BEGIN(verbatim); return CODEBLOCK;
(?i:[ \t]*teletype::[ \t]*\n+)      BEGIN(verbatim); return TELETYPEBLOCK;
(?i:[ \t]*math::[ \t]*\n+)          BEGIN(verbatim); return MATHBLOCK;

<*>[ \t\n]*::    BEGIN(0); return TAGSYM;
[ \t\n]*\|\|[ \t\n]*            return BARS;
[ \t\n]*\#\#[ \t\n]*            return HASHES;

\n              return EOL;
\n\n+           return EMPTYLINES;

<*>\\::         yylval.str = strdup("::"); return TEXT;

[a-zA-Z0-9]+    |
[.,!?()]+       |
<*>[ \t\r]+ |
<verbatim>[^:\\ ]+ |
[^:\\\n]        |
<*>.            yylval.str = strdup(yytext); return TEXT;

%%

