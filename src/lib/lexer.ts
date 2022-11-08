import moo from 'moo'
console.log(moo)
export const lexer = moo.compile({
  __: /[ \t]+/u,
  //_: /[ \t]*/u,
  Year: /(?:\d{4}|n\.d\.?)/u,
  BCE: /B\.C\.E\.|B\.C\.|C\.E\.|A\.D\.|a\.d\.|b\.c\.e\.|b\.c\.|c\.e\./u,
  //maybename: /[A-Z]\w*['-]?\w*/u,
  Number: /\d+/u,
  //Loc: ['pp.', 'p.', 'chapter', 'Chapter'],
  Com: ',',
  Dot: '.',
  Lp: '(',
  Rp: ')',
  Sem: ';',
  Col: ':',
  Amp: '&',
  And: /\band\b/u,
  Ca: ['ca.'],
  Quote: /["'](?:\\['"\\]|[^\n"'\\])*["']/u,
  Apo: /['’]/u,
  Slash: '/',
  Dash: /[—−–-]/u,
  Et: /et al\.?/u,
  End: /[?!]/u,
  Punct: /[[\]{}<>]/u,
  Mc: ['Mc', 'Mac'],
  DutchPref: /\b(?:van|der|ter|ten|te|de|la)\b/u,
  Cap: /\p{Lu}/u,
  Lowword: /\p{Ll}+/u,
  NL: { match: /\n/u, lineBreaks: true },
  Misc: /./u,
})
