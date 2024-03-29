
@preprocessor typescript

@{%
import {lexer} from './lexer'

// TODO: [parser] It's currently extremely slow for large sentences, not good.
const getFullName = (name: {family:string,
                            'non-dropping-particle':string
                           }
                    ) => `${name?.['non-dropping-particle']
                              ? name?.['non-dropping-particle']+' '
                            :''}${name.family}`


const locators = [
                            "act",
                            "appendix",
                            "article-locator",
                            "book",
                            "canon",
                            "chapter",
                            "column",
                            "elocation",
                            "equation",
                            "figure",
                            "folio",
                            "issue",
                            "line",
                            "note",
                            "opus",
                            "page",
                            "paragraph",
                            "part",
                            "rule",
                            "scene",
                            "section",
                            "sub-verbo",
                            "supplement",
                            "table",
                            "timestamp",
                            "title-locator",
                            "verse",
                            "version",
                            "volume"
]

const labelMap: {[key:string]:string}= {
  'p': 'page',
  'pp': 'page',
  'chapter': 'chapter',
  'ch': 'chapter',
  'sec': 'section',
  'par': 'paragraph',
  'paras': 'paragraph',
  "vol": 'volume',
  'app':'appendix',
}
%}

@lexer lexer



Input -> InputContent:+ {% (inp: any[])=>{
                          const [content] = inp
                          return content
                                .reduce((acc: any[],
                                        curr: Record<string, any>
                                        )=>{

                                if(!curr.value){
                                  acc.push(curr)
                                  return acc
                                }

                                if(typeof acc[acc.length-1] ==='string'){
                                  acc[acc.length-1]+=curr.value
                                  return acc
                                }

                                acc.push(curr.value)
                                return acc

                             }, [])
                          }
                        %}


InputContent ->
         ParenCite {% id %}
        | NarrCite {% id %}
        | NonCiteContent {% id %}
        | %Rp NonCiteContent {% n => n.join('') %}

NonCiteContent ->
  %Year {% id %}
 | NonYearParenContent {% id %}
 | %Lp NonYearParenContent:+ %Rp {% ([l,c,r]) => l+c.join('')+r %}
# | %Lp NonYearParenContent:+  {% ([l,c]) => l+c.join('') %}
#  |  NonYearParenContent:+ %Rp {% ([c,r]) => c.join('')+r%}
#  | %Year %Rp {% ([l,c]) => l+c%}

NonYearParenContent ->
   %__ {% id %}
 | %Number {% id %}
 | %Com {% id %}
 | %Dot {% id %}
 | %Sem {% id %}
 | %Col {% id %}
 | %Amp {% id %}
 | %And {% id %}
 | %Ca {% id %}
 | %Quote {% id %}
 | %Apo {% id %}
 | %Slash {% id %}
 | %Dash {% id %}
 | %Punct {% id %}
 | %Mc {% id %}
#  | %DutchPref {% id %}
 | %Cap {% id %}
 | %Lowword {% id %}
 | %NL {% id %}
 | %Misc {% id %}
 | %End {% id %}

# A narrative citation
NarrCite -> NameList %__ %Lp YearList Loc:? %Rp {% ([name,,,yearlist])=>(
                                                           {
                                                             citationId: 'CITE-X',
                                                              citationItems:
                                                              yearlist.map((y:string[])=>({
                                                                  "id":getFullName(name[0])
                                                                                          .replace(/ /g,'')+y[0],
                                                                  itemData:{
                                                                  author: name,
                                                                  issued: {
                                                                    'date-parts': [[y[0]
                                                                                        .replace(/(\d|.-?)[a-z]/,'$1')]]

                                                                  },
                                                                  ...(y[1]? {'original-date': {
                                                                    'date-parts': [[y[1].replace(/(\d)[a-z]/,'$1')]]
                                                                  }
                                                                  }:{})
                                                                  }
                                                              })),
                                                              properties: {noteIndex: 0,mode: "composite"}
                                                           }
                                                                   )
                                                %}

# A parenthetical citation
ParenCite -> %Lp ParenContent %Rp {% ([,content,])=>{
                                                      // This is CSL-JSON cite items
                                                    return  {
                                                        citationId:"CITE-X",
                                                        citationItems: content.flat(),
                                                        properties: {"noteIndex":0}
                                                      }
                                                    }
                                    %}

# Everything between parentheses.
ParenContent ->   SingleParenEntry {% id %}
                | ParenContent %Sem %__ SingleParenEntry      {%
                                                               ([content, semi,,single])=> [
                                                                 ...(content.flat()),
                                                                 ...single
                                                                ]
                                                              %}
                | ParenContent PreAuthsMiddle SingleParenEntry {%
                                                            ([content, pre,single])=>{
                                                               //const sing = single[0]
                                                               if(pre){
                                                               single[0].prefix = pre.join('')
                                                               }
                                                               return [
                                                                 ...(content.flat()),
                                                                ...single
                                                                 ]
                                                                }
                                                              %}


# Everything between semis in a parenthetical citation
# if we have an entry like (Guy, 2020 ,2021, p.4), we assume the prefix is for the first and the locator for the last.
SingleParenEntry -> PreAuthsPre:* ParenCiteAuthYear Loc:? {%
                                                          ([pre, content, loc]) => {
                                                            const l = Object.assign({},loc)
                                                            const p = pre.length
                                                                       ? {prefix: pre?.join('')}
                                                                      : {}

                                                            if(content.length===1){
                                                              content[0] = {...content[0],
                                                              ...l,
                                                              ...p}
                                                              return content
                                                            }
                                                              content[0] = {...content[0],
                                                              ...p}
                                                              content[content.length-1]={...
                                                              content[content.length-1], ...l}
                                                              return content
                                                          }
                                                      %}

# Loc -> %Com %__ GenericContent:+ {% content => {
#                                                 return content.join('')
#                                              }
#                                 %}

# Stuff like (someone said something weird; Allegreya, 2021)
PreAuthsPre ->   GenericContent:+ %Sem %__    {%
                                                 content=> {
                                                             return content[0]
                                                           }
                                              %}
                | GenericContent:+ %Com %__ {% content=> content[0]%}
                | GenericContent:+ %__ {%content=>content[0]%}

# Things like (...; see also Gooden, 2021; Kant, 1800)
# Extremely inefficient
# TODO: Make "(;... see also Gooden, 2021)" style citations less inefficient
# These kinds of checks are note fast.
PreAuthsMiddle -> %Sem %__  GenericContent:+ {%
                                                content=> {
                                                            return content[2]
                                                          }
                                              %}

Loc -> %Com %__ LocContent {% ([,,loc])=>loc %}

LocContent ->
              LocGenericContent:+
              %__
              LocGenericContent:+ {% ([label,space,loc]) => {
                                                           const rawLabel=label
                                                                               .join('')
                                                                               .trim()
                                                                               .toLowerCase()
                                                                               .replace(/\./g,'')

                                                           if(!(labelMap[rawLabel])
                                                            && !locators.includes(rawLabel)){
                                                               return {
                                                                        label:'none',
                                                                        locator: label
                                                                                     .join('')
                                                                              + space +
                                                                                loc
                                                                                   .join('')
                                                                      }
                                                            }

                                                            const properLabel = labelMap[rawLabel] || rawLabel

                                                            return {
                                                              label: properLabel,
                                                              locator: loc.join('').trim()
                                                            }
                                                   }
                                %}
              | LocGenericContent:+ {% ([loc]) => ({locator: loc.join(''),label:'none'}) %}

LocGenericContent -> GenericContent {% content => content %}
                    | %Cap %Lowword LocGenericContent {% ([cap,low,rest])=> [cap+low+rest.join('')] %}
                    | %Cap %Lowword {% ([cap,low])=> [cap+low] %}
# %Loc %__:? GenericContent:+ {% ([loc,,cont]) => {
#                                                                   const locator = cont.join('').trim()
#                                                                   if(loc.value.includes('p.')){
#                                                                     return {locator: locator, label: 'page'}
#                                                                   }
#                                                                   return {locator: locator,label:loc.value}
#                                                                 }
#                                              %}

GenericContent ->   %Lowword                                 {% id %}
                  | %Cap %Cap:+                              {% ([cap,caps]) => cap+caps.join('') %}
                  | %Cap %__                                 {% content=>content.join('') %}
                  | GenericContent %Cap %Lowword                            {% content=>content.join('') %}
                  | %Cap %Dot (%Cap %Dot):+                  {% ([c,d,content])=>c+d+content.flat().join('') %}
                  | %Col                                     {% id %}
                  | %Number                                  {% id %}
                  | %Dot                                     {% id %}
                  | %Dash                                    {% id %}
                  | %Com {% id %}
                  | %__                                      {% id %}
               #   | %Misc {% id %}


# ParenCiteMulti-> %Lp NameList %Com %__ %YearList %Rp {% ([,name,,,,nametwo,,,year]) => (
#                                                               {
#                                                                citationId:"CITE-X",
#                                                                citationItems: [{
#                                                                   "id":getFullName(name).replace(/ /g,'')+year
#                                                                }],
#                                                                properties: {"noteIndex":0}
#                                                               }
#                                                             )
#                                       %}

ParenCiteAuthYear ->  ParenNameMaybeList
                      %Com
                      %__
                      YearList  {% (content) => {
                                                  const [name,,,yearlist] = content
                                                  return yearlist.map((y:string[])=>({
                                                      "id":getFullName(name[0]).replace(/ /g,'')+y[0],
                                                      itemData:{
                                                      author: name,
                                                      issued: {
                                                        'date-parts': [[y[0].replace(/(\d)[a-z]/,'$1')]]
                                                      },
                                                      ...(y[1]? {'original-date': {
                                                        'date-parts': [[y[1].replace(/(\d)[a-z]/,'$1')]]
                                                      }
                                                      }:{})
                                                      }
                                                  }))
                                                }
                                %}



YearList ->   Year {% year=>year %}
            | YearList %Com %__:+ Year {% ([list,,,year])=> {
                                                              return [...list,year]
                                                           }
                                                           %}
# YearList ->   Year {% (y)=>(y) %}

#             | YearList %Com %__ Year {% ([[list],,,year])=> {
#                                                               const yl=[list.flat(),year]
#                                                               return yl
#                                                            }
#                                       %}
#             | YearList %Com %__ YearList {% ([[list],,,year])=> {
#                                                               const yl=[list.flat(),...year]
#                                                               return yl
#                                                            }
#                                       %}

#NameList -> NameListOne:+ Etal:? {% ([namelist,etal])=>namelist[0] %}


NameList ->   Name                                           {% name=>name %}
            | NameList %Com %__ Name                         {% ([name,,,n])=>([name,n].flat()) %}
            | NameList %Com %__ NameList                     {% ([name,,,n])=>([name,n].flat()) %}
            | NameList %Com %__ Comp %__ NameList            {% ([name,,,,,n])=>([name,n].flat()) %}
            | NameList %Com %__ Comp %__                     {% ([name,,,,])=>([name].flat()) %}
            | NameList %__ Comp %__ NameList                 {% ([name,_,and,__,n])=>([name,n].flat()) %}
            | NameList %__ Comp %__ Name                     {% ([name,_,and,__,n])=>([name,n].flat()) %}
            | NameList %__ Comp %__                          {% ([name])=>([name].flat()) %}
            | NameList %Com %__ Etal                         {% ([name])=>([name].flat()) %}
            | NameList Etal                                  {% ([name])=>([name].flat()) %}

ParenNameMaybeList ->  ParenNameMaybe                                  {% name=>name %}
                     | ParenNameMaybeList %Com %__ Name                {% ([name,,,n])=>([name,n].flat()) %}
                     | ParenNameMaybeList %Com %__ NameList            {% ([name,,,n])=>([name,n].flat()) %}
                     | ParenNameMaybeList %Com %__ Comp %__ NameList   {% ([name,,,,,n])=>([name,n].flat()) %}
                     | ParenNameMaybeList %Com %__ Comp %__            {% ([name])=>([name].flat()) %}
                     | ParenNameMaybeList %__ Comp %__ NameList        {% ([name,,,,n])=>([name,n].flat()) %}
                     | ParenNameMaybeList %__ Comp %__                 {% ([name])=>([name].flat()) %}


ParenNameMaybe ->   Name                              {% id %}
                  | Name Etal                         {% ([n])=>n %}
                  | ParenNameMaybe %__ ParenNameMaybe {% ([n,,nn]) => ({...n,...nn,family:n.family+nn.family}) %}
                  | ParenNameMaybe %__ %Lowword       {% ([n,,nn]) => ({...n,family:n.family+nn}) %}

Etal ->%__:? %Et {% etal=>null %}

Name -> Initials %__ LastName {% ([initials, ,name])=> ({given: initials.join(''),...name}) %}
        | LastName {% id %}

LastName ->  SingleName {% id %}
           | HyphenName {% id %}

Comp ->  %And {% id %}
       | %Amp {% id %}

# E.g. James-John
HyphenName -> SingleName %Dash SingleName {% ([first,d,last])=> ( {
                                                                    family: `${getFullName(first)
                                                                              + d
                                                                              + getFullName(last)}`
                                                                  }
                                                                )
                                          %}


SingleName -> BoringNameMaybe {% ([name]) => ({family:name}) %}
              | DutchName {% id %}
              | OReilly {% id %}
              | McConnel {% id %}
              | SpanishName {% id %}


Initials ->   Initial
            | Initials %__:* Initial

Initial -> %Cap %Dot {% id %}

#             | SpanishName

# Spanish names are by far the most difficult to parse, because there's really know way to  correctly get the last names from
# "Bautista Perpinya (2020) said", "Since Locke (1996) said...", and "John Johnson (2999) said" to be
# "Perpinya " "Locke" and "Johnson" respectively without a lookup table of
# first/last names in almost every language. Authors should just not cite people by their first names and/or not put citations
# at the start of sentences!!! GRrrr
# Is it me who is wrong? 🤔 No, it's gotta be the authors.

SpanishName -> BoringNameMaybe %__ BoringNameMaybe {%
                                                    ([first,,last]) => ({
                                                        family: `${first} ${last}`
                                                    })
                                                   %}

DutchName -> DutchPrefix %__ BoringNameMaybe {% ([pref,space, rest]) => (
                                                                          {
                                                                           family: rest,
                                                                           'non-dropping-particle': pref
                                                                                                      .join('')
                                                                          }
                                                                        )
                                              %}

OReilly-> BoringNameMaybe "'" BoringNameMaybe {% ([o, a, name]) =>({family:o+a+name })%}

McConnel -> %Mc BoringNameMaybe {% (name) =>({family:name.join('')}) %}

# Eg James, fuck you Jimmy
BoringNameMaybe -> %Cap %Lowword:*  {% ([cap, rest]) =>( `${cap}${rest.join('')}`) %}

# Just a regular word. I've decided that these cant be names, sorry bell hooks
BoringWord -> %Low:+  {% (word) =>(word.join('')) %}

# Dutch prefix, things like "de", "van der" etc. Fuck the Dutch, this makes everything so much harder
DutchPrefix ->  %DutchPref
              | DutchPrefix %__ %DutchPref

# Modifier for a year when an author-year combo has been cited already, e.g. 2012a

Year ->  %Year {% ([year]) => ([`${year}`.replace(/\./g,'').toUpperCase()]) %}
       | %Year %Dash:? %Lowword {% ([year,, low])=> ([year + low]) %}
       | Year %Slash Year {% (content) => {const[year, sl, year2]=content
                                          return([...year2,...year])}
                             %}
       | %Number:+ %__:* %BCE {% ([num,,rest])=> ([`${/b\.?c\.?/i.test(rest) ? '-' : ''}${num}`]) %}
       | %Ca %__ Year {% ([ca,,year])=> ([`${year}`]) %}

# Year -> Digit Digit Digit Digit {% (year)=>year.join('') %}
#         | "n" "." "d"

# Digit -> [0-9] {% id %}

# Lower -> [a-z] {% id %}

# Cap -> [A-Z] {% id %}

# Hyphen -> [\-]{% id %}

# Apo -> ['’]{% id %}

# Etal -> "et al" Dot:? # Sometimes authors are just bad

# Conj ->  And
#        | Amp

# Rp -> ")"{% id %}

# Lp -> "("{% id %}

# And -> "and"{% id %}

# Amp -> [&]{% id %}

# Dot -> "."{% id %}

# Com -> ","{% id %}

# Sem -> ";"{% id %}

# SentEnd -> [?!]{% id %}
#           | Dot {% id %}

# Misc -> [\[\]{}<>] {% id %}

# _ -> [ \t]:* {% id %} # Optional Whitespace

# __ -> [ \t]:+ {% id %}# Mandatory Whitespace
