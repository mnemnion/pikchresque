# Pikchresque


First, there was [Pic].  Authored by [Brian Kernighan][bwk], Pic is one
of several 'little languages' from the classic Unix era.  Original Pic
worked like this:

![Original Pik](img/og-pik.svg "The workflow from the original PIC user manual.
")

A diagram taken directly from the user manual.  Pic was (and is) a
[troff] preprocessor, written in C, with aid of [lex] and [yacc].

Next, there was (and is!)  [Pikchr].  This is a port and adaptation of
Pic, by [D. Richard Hipp][drh].  Which works like this:

![Original Pikchr](img/pikchr.svg "The workflow from the Pikchr home page.")

Another diagram taken directly from the user manual.  Or, homepage.  The
documentation for sure.  This 'little language' has a few changes from
the original, but is broadly compatible: it's used in the [SQLite] and
[Fossil] projects for technical documentation.

Also written in C, but in this case, using [Lemon], an alternative
LALR(1) parser generator used, notably, to generate SQLite's SQL parser.

This: is **Pikchresque**

![Pikchresque](img/esque.svg "Pikchresque diagram")

## What and Why

Pikchr is more of a dialect of Pic than a language in its own right;
Pikchresque is more of an accent.  It began as a [pikchr fork], which
I've been hacking on an on-again-off-again basis for a few years.  I
got most of the way to where I wanted to go and kinda stalled out.  It
happens.

In 2025, I wrote [Zitron], by translating Lemon into Zig, and then
adapting the result to emit Zig code rather than C. These quests were,
at the time, only related insofar as hacking on Pikchr(esque) is how I
came to appreciate Lemon well enough to want to base a parser generator
on it.

Later, while working on Zitron tooling, it became clear that the task
would benefit from a non-trivial Zitron _program_.  While I have some
ambition of writing one of those _de novo_, that kind of thing takes
time, and having nice tooling, while not a hard requirement, is a boon
to developing anything so complex as a language, little or otherwise.

So I told Codex to translate my C/Lemon fork of Pikchr to Zig/Zitron,
and, it did.  There's more to it than that, always is.  But not much.

Where I stalled out on the original Pikchr fork is, well.  The obvious
way to do what I wanted to do is a hash map.  Pikchr doesn't use those,
it's a few linked lists and some array tables — and in C, one does not
simply _use_ a hash map.  I had reckoned some halfway plausible routes
to the summit using more linked lists, but never picked up the gumption
to haul my carcass uphill.

It's not that hand-rolling a hashmap is difficult, it's isn't, but it's
undignified.

In Zig, this is just a call to `HashMap` away.  So here we are.


## Further Features

Pikchresque is a proper superset of Pikchr.  Although it doesn't
generate eyeball-identical SVG for the same inputs, it can be
build-time configured to do so[^1].

Textually, the SVGs are markedly different.  This was in the service of
the following:


### Responsive SVG

Pikchr is a core component of Fossil.  Not just a version control
system, and a _good_ one, Fossil is also a server for software projects.
It has documents, tickets, wikis, forums, even chat.

Styling in Fossil uses skins.  Some skins are light, others are dark:
so Pikchr can generate a light diagram, or a dark one, from the same
script.

What it can't do is generate a diagram which is light in a light mode,
and dark in a dark mode.

Pikchresque can.


### Accessible SVG

Pikchresque adds two rules to the grammar:

```pik
# Instead of 'title' you may use 'label', but not both.
title "This is a high-level summary of what this diagram is about."

description "This is a detailed description of the diagram.  \
It has enough information that users of screen readers will have \
as much information about the diagram as text can provide."
```

These are properly marked up with aria roles[^2].  I'm no a11y expert,
but my limited experiments with the results suggest that it's at least
acceptable: which, it pains me to say, is not true of stock Pikchr
diagrams.  I am open to any informed suggestions about how to improve
the experience further.

[^2]: Note that the browser will take no interest in these elements
unless the SVG is inlined or an `<object>`: as an `<img>` you'll want
that `alt` tag anyway.


### Extensible SVG

The output of Pikchresque is extensively marked up with classes.  An
oval gets `oval`, labeled elements receive that label, and so on.  There
are also gnomic style classes to enable responsive color, although those
are meant as an implementation detail.

Further classes may be added:

```pik
box class 'filter_stage markdown' rad 10px "Markdown" "Formatter" "(markdown.c)" fit
```

Will add the classes `filter-stage` and `markdown` to the box,
and in general to all SVG elements making up the class'ed object.
The underscore in the input, and the hyphen in the output, are both
intentional.


### Text color

Pikchresque adds the keyword / attribute `textcolor`, which sets the
color of the object in question's text.  In Pikchr there's just color: a
red box will have red text, although there are ways to achieve the same
effect.  As a result, a Pikchr diagram with `color` set in a context
which would affect text color as well, will not see the color of that
text change.

#### Those diagrams don't look responsive lol

It's [not my bug][nmb], you're in dark mode and [using Safari][safari].

[^1]: Pass `pikchr_perfect` at build time.

[pic]: https://pikchr.org/home/uv/pic.pdf
[troff]: https://en.wikipedia.org/wiki/Troff
[lex]: https://en.wikipedia.org/wiki/Lex_(software)
[yacc]: https://en.wikipedia.org/wiki/Yacc
[Pikchr]: https://pikchr.org/home/doc/trunk/homepage.md
[bwk]: https://en.wikipedia.org/wiki/Brian_Kernighan
[drh]: https://en.wikipedia.org/wiki/D._Richard_Hipp
[sqlite]: https://sqlite.org
[fossil]: https://fossil-scm.org
[lemon]: https://sqlite.org/lemon.html
[pikchr fork]: https://chiselapp.com/user/mnemnion/repository/pikchresque/doc/trunk/homepage.md
[zitron]: https://github.com/mnemnion/zitron
[nmb]: https://github.com/w3c/csswg-drafts/issues/7213
[safari]: https://bugs.webkit.org/show_bug.cgi?id=199134
