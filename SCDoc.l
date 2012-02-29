%{

#include <string.h>
#include "SCDoc.h"
#include "SCDoc.tab.h"

int scdoc_start_token = 0;

%}

%option yylineno noyywrap never-interactive nounistd

%x verbatim
%x verbatim2
%%
%{

if (scdoc_start_token) {
    int t = scdoc_start_token;
    scdoc_start_token = 0;
    return t;
}

%}

(?i:[ \t]*class::[ \t]*)         return CLASS;
(?i:[ \t]*title::[ \t]*)         return TITLE;
(?i:[ \t]*summary::[ \t]*)       return SUMMARY;
(?i:[ \t]*related::[ \t]*)       return RELATED;
(?i:[ \t]*categories::[ \t]*)    return CATEGORIES;
(?i:[ \t]*redirect::[ \t]*)      return REDIRECT;

(?i:[ \t]*classtree::[ \t]*)     return CLASSTREE;
(?i:[ \t]*keyword::[ \t]*)       return KEYWORD;

(?i:[ \t]*private::[ \t]*)       return PRIVATE;
(?i:[ \t]*section::[ \t]*)       return SECTION;
(?i:[ \t]*subsection::[ \t]*)    return SUBSECTION;
(?i:[ \t]*copymethod::[ \t]*)    return COPYMETHOD;
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

(?i:link::[ \t]*)           BEGIN(verbatim); return LINK;
(?i:anchor::[ \t]*)         BEGIN(verbatim); return ANCHOR;
(?i:image::[ \t]*)          BEGIN(verbatim); return IMAGE;
(?i:soft::[ \t\n]*)         BEGIN(verbatim); return SOFT;
(?i:strong::[ \t\n]*)       BEGIN(verbatim); return STRONG;
(?i:emphasis::[ \t\n]*)     BEGIN(verbatim); return EMPHASIS;
(?i:code::[ \t]*)           BEGIN(verbatim); return CODE;
(?i:teletype::[ \t]*)       BEGIN(verbatim); return TELETYPE;
(?i:math::[ \t]*)           BEGIN(verbatim); return MATH;

(?i:[ \t]*code::[ \t]*\n+)      BEGIN(verbatim2); return CODEBLOCK;
(?i:[ \t]*teletype::[ \t]*\n+)  BEGIN(verbatim2); return TELETYPEBLOCK;
(?i:[ \t]*math::[ \t]*\n+)      BEGIN(verbatim2); return MATHBLOCK;

<INITIAL,verbatim>[ \t\n]*::    BEGIN(0); return TAGSYM;
<verbatim2>\n[ \t\n]*::         BEGIN(0); return TAGSYM;
[ \t]*\|\|[ \t\n]*              return BARS;
[ \t]*\#\#[ \t\n]*              return HASHES;

<verbatim2>\n   scdoclval.str = strdup("\n"); return TEXT;
<verbatim>\n+   scdoclval.str = strdup(" "); return TEXT;
<INITIAL>\n     return NEWLINE;
\n([ \t]*\n)+           return EMPTYLINES;

\\\|\|                  scdoclval.str = strdup("||"); return TEXT;
\\\#\#                  scdoclval.str = strdup("##"); return TEXT;
<INITIAL,verbatim>\\::  scdoclval.str = strdup("::"); return TEXT;
<verbatim,verbatim2>\t  scdoclval.str = strdup("    "); return TEXT;
[ \r\t]+                scdoclval.str = strdup(" "); return TEXT;

[a-zA-Z]+:\/\/[^ \t\n:]+        scdoclval.str = strdup(scdoctext); return URL;
[a-zA-Z]+                       |
<*>[.,!?(){}\[\]'"0-9]+         |
<verbatim,verbatim2>[^:\\\t\n ]+ |
[^:\\\n]                        |
<*>.                            scdoclval.str = strdup(scdoctext); return TEXT;

%%

