# JsRegex

[![Gem Version](https://badge.fury.io/rb/js_regex.svg)](http://badge.fury.io/rb/js_regex)
[![Build Status](https://github.com/jaynetics/js_regex/workflows/tests/badge.svg)](https://github.com/jaynetics/js_regex/actions)
[![Build Status](https://github.com/jaynetics/js_regex/workflows/gouteur/badge.svg)](https://github.com/jaynetics/js_regex/actions)
[![codecov](https://codecov.io/gh/jaynetics/js_regex/branch/master/graph/badge.svg)](https://codecov.io/gh/jaynetics/js_regex)

This is a Ruby gem that translates Ruby's regular expressions to the JavaScript flavor.

It can handle [far more](#SF) of Ruby's regex capabilities than a [search-and-replace approach](https://github.com/rails/rails/blob/b67043393b5ed6079989513299fe303ec3bc133b/actionpack/lib/action_dispatch/routing/inspector.rb#L42), and if any incompatibilities remain, it returns [helpful warnings](#HW) to indicate them.

This means you'll have better chances of translating your regexes, and if there is still a problem, at least you'll know.

### Installation

Add it to your gemfile or run

    gem install js_regex

### Usage

In Ruby:

```ruby
require 'js_regex'

ruby_hex_regex = /0x\h+/i

js_regex = JsRegex.new(ruby_hex_regex)

js_regex.warnings # => []
js_regex.source # => '0x[0-9A-Fa-f]+'
js_regex.options # => 'i'
```

An `options:` argument lets you force options:

```ruby
JsRegex.new(/x/i, options: 'g').to_h
# => {source: 'x', options: 'gi'}
```

Set the [g flag](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp/global) like this if you want to use the regex to find or replace multiple matches per string.

To inject the result directly into JavaScript, use `#to_s` or String interpolation. E.g. in inline JavaScript in HAML or SLIM you can simply do:

```javascript
var regExp = #{js_regex};
```

Use `#to_json` if you want to send it as JSON or `#to_h` to include it as a data attribute of a DOM element.

```ruby
render json: js_regex

js_regex.to_h # => {source: '[0-9A-Fa-f]+', options: ''}
```

To turn the data attribute or parsed JSON back into a regex in JavaScript, use the `new RegExp()` constructor:

```javascript
var regExp = new RegExp(jsonObj.source, jsonObj.options);
```

<a name='HW'></a>
### Heed the Warnings

You might have noticed the empty `warnings` array in the example above:

```ruby
js_regex = JsRegex.new(ruby_hex_regex)
js_regex.warnings # => []
```

If this array isn't empty, that means that your Ruby regex contained some [stuff that can't be carried over to JavaScript](#UF). You can still use the result, but this is not recommended. Most likely it won't match the same strings as your Ruby regex.

```ruby
advanced_ruby_regex = /(?<!fizz)buzz/

js_regex = JsRegex.new(advanced_ruby_regex)
js_regex.warnings # => ["Dropped unsupported negative lookbehind assertion '(?<!fizz)' at index 0"]
js_regex.source # => 'buzz'
```

There is also a strict initializer, `JsRegex::new!`, which raises a `JsRegex::Error` if there are incompatibilites. This is particularly useful if you use JsRegex to convert regex-like strings, e.g. strings entered by users, as a `JsRegex::Error` might also occur if the given regex is invalid:

```ruby
begin
  user_input = '('
  JsRegex.new(user_input)
rescue JsRegex::Error => e
  e.message # => "Premature end of pattern (missing group closing parenthesis)"
end
```

<a name='SF'></a>
### Supported Features

In addition to the conversions supported by the default approach, this gem will correctly handle the following features:

| Description                   | Example               |
|-------------------------------|-----------------------|
| escaped meta chars            | \\\A                  |
| dot matching astral chars     | /./ =~ '😋'           |
| Ruby's multiline mode [1]     | /.+/m                 |
| Ruby's free-spacing mode      | / http (s?) /x        |
| atomic groups [2]             | a(?>bc\|b)c           |
| conditionals [2]              | (?(1)b), (?('a')b\|c) |
| option groups/switches        | (?i-m:..), (?x)..     |
| local encoding options        | (?u:\w)               |
| absence groups                | /\\\*(?~\\\*/)\\\*/   |
| possessive quantifiers [2]    | ++, *+, ?+            |
| chained quantifiers           | /A{4}{6}/ =~ 'A' * 24 |
| hex types \h and \H           | \H\h{6}               |
| bell and escape shortcuts     | \a, \e                |
| all literals, including \n    | eval("/\n/")          |
| newline-ready anchor \Z       | last word\Z           |
| generic linebreak \R          | data.split(/\R/)      |
| meta and control escapes      | /\M-\C-X/             |
| numeric backreferences        | \1, \k&lt;1&gt;       |
| relative backreferences       | \k&lt;-1&gt;          |
| named backreferences          | \k&lt;foo&gt;         |
| numeric subexpression calls   | \g&lt;1&gt;           |
| relative subexpression calls  | \g&lt;-1&gt;          |
| named subexpression calls     | \g&lt;foo&gt;         |
| nested sets                   | [a-z[A-Z]]            |
| types in sets                 | [a-z\h]               |
| properties in sets            | [a-z\p{sc}]           |
| set intersections             | [\w&amp;&amp;[^a]]    |
| recursive set negation        | [^a[^b]]              |
| posix types                   | [[:alpha:]]           |
| posix negations               | [[:^alpha:]]          |
| codepoint lists               | \u{61 63 1F601}       |
| unicode properties            | \p{Arabic}, \p{Dash}  |
| unicode abbreviations         | \p{Mong}, \p{Sc}      |
| unicode negations             | \p{^L}, \P{L}, \P{^L} |
| astral plane properties [2]   | \p{emoji}             |
| astral plane literals [2]     | &#x1f601;             |
| astral plane ranges [2]       | [&#x1f601;-&#x1f632;] |


[1] Keep in mind that [Ruby's multiline mode](http://ruby-doc.org/core-2.1.1/Regexp.html#class-Regexp-label-Options) is more of a "dot-all mode" and totally different from [JavaScript's multiline mode](http://javascript.info/regexp-multiline-mode).

[2] See [here](#EX) for information about how this is achieved.

<a name='UF'></a>
### Unsupported Features

Currently, the following functionalities can't be carried over to JavaScript. If you try to convert a regex that uses these features, corresponding parts of the pattern will be dropped from the result.

In most of these cases that will lead to a warning, but changes that are not considered risky happen without warning. E.g. comments are removed silently because that won't lead to any operational differences between the Ruby and JavaScript regexes.

| Description                    | Example               | Warning |
|--------------------------------|-----------------------|---------|
| lookbehind                     | (?&lt;=, (?&lt;!, \K  | yes     |
| whole pattern recursion        | \g<0>                 | yes     |
| backref by recursion level     | \k<1+1>               | yes     |
| previous match anchor          | \G                    | yes     |
| extended grapheme type         | \X                    | yes     |
| variable length absence groups | (?~(a+\|bar))         | yes     |
| working word boundary anchors  | \b, \B                | yes [3] |
| capturing group names          | (?&lt;a&gt;, (?'a'    | no      |
| comment groups                 | (?#comment)           | no      |
| inline comments (in x-mode)    | /[a-z] # comment/x    | no      |


[3] \b and \B *are* carried over, but generate a warning because they only recognize ASCII word chars in JavaScript. This holds true for all JavaScript versions and RegExp modes.

<a name='EX'></a>
### How it Works

JsRegex uses the gem [regexp_parser](https://github.com/ammar/regexp_parser) to parse a Ruby Regexp.

It traverses the AST returned by `regexp_parser` depth-first, and converts it to its own tree of equivalent JavaScript RegExp tokens, marking some nodes for treatment in a second pass.

The second pass then carries out all modifications that require knowledge of the complete tree.

After the second pass, JsRegex flat-maps the final tree into a new source string.

Many Regexp tokens work in JavaScript just as they do in Ruby, or allow for a straightforward replacement, but some conversions are a little more involved.

**Atomic groups and possessive quantifiers** are missing in JavaScript, so the only way to emulate their behavior is by substituting them with [backreferenced lookahead groups](http://instanceof.me/post/52245507631/regex-emulate-atomic-grouping-with-lookahead).

**Astral plane characters** convert to ranges of [surrogate pairs](https://dmitripavlutin.com/what-every-javascript-developer-should-know-about-unicode/#24surrogatepairs), so they don't require ES6.

**Properties and posix classes** expand to equivalent character sets, or surrogate pair alternations if necessary. The gem [regexp_property_values](https://github.com/jaynetics/regexp_property_values) helps by reading out their codepoints from Onigmo.

**Character sets a.k.a. bracket expressions** offer many more features in Ruby compared to JavaScript. To work around this, JsRegex calls on the gem [character_set](https://github.com/jaynetics/character_set) to calculate the matched codepoints of the whole set and build a completely new set string for all except the most simple cases.

**Conditionals** expand to equivalent expressions in the second pass, e.g. `(<)?foo(?(1)>)` expands to `(?:<foo>|foo)` (simplified example).

**Subexpression calls** are replaced with the conversion result of their target, e.g. `(.{3})\g<1>` expands to `(.{3})(.{3})`.

The tricky bit here is that these expressions may be nested, and that their expansions may increase the capturing group count. This means that any following backreferences need an update. E.g. <code>(.{3})\g<1>(.)<b>\2</b></code> (which matches strings like "FooBarXX") converts to <code>(.{3})(.{3})(.)<b>\3</b></code>.

### Contributions

Feel free to send suggestions, point out issues, or submit pull requests.

### Outlook

Possible future improvements might include an "ES6 mode" using the [u flag](https://javascript.info/regexp-unicode), which would allow for more concise representations of astral plane properties and sets.

As far as supported conversions are concerned, this gem is pretty much feature-complete. Most of the unsupported features listed above are either impossible or impractical to replicate in JavaScript.
