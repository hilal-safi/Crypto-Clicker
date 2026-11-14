#!/usr/bin/env python3
"""Writes the Kotlin models and the JSON contract from the Swift bridge's views.

The Swift views in android/swift/Sources/CryptoClickerBridge are the one definition of what the
native game sends the app. This reads every `struct …: Encodable` there and writes:

- android/app/src/main/kotlin/com/hilalsafi/cryptoclicker/core/Models.kt: a Kotlin data class for
  each view, with a `from(JsonObject)` that reads every field strictly (a missing required field,
  a wrong type or an unknown field fails the app's contract test);
- android/contract/response.json: a sample response holding every field of every view, which the
  Kotlin and Swift contract tests check against.

Run it after changing a view:  python3 android/tools/generate_models.py
CI runs it with --check, which fails if the generated files are out of date.

Rules for the Swift views, so this stays a small script:
- `struct Name: Encodable` (other conformances may follow, e.g. `: Encodable, Equatable`);
- one stored property per line, `let name: Type` or `var name: Type`, with no default value;
- types: String, Int, Double, Bool, another view, `[T]`, `[[T]]`, and `T?` of any of these.
Kotlin names drop a trailing "View" (MinerView -> Miner), except for those in NAME_MAP.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ANDROID = os.path.dirname(HERE)
SWIFT_DIR = os.path.join(ANDROID, 'swift', 'Sources', 'CryptoClickerBridge')
MODELS = os.path.join(ANDROID, 'app', 'src', 'main', 'kotlin', 'com', 'hilalsafi', 'cryptoclicker', 'core', 'Models.kt')
CONTRACT = os.path.join(ANDROID, 'contract', 'response.json')
ROOT = 'Response'

NAME_MAP = {
    'GameView': 'GameView',
    'TapView': 'TapResult',
}

PRIMITIVES = {'String': 'String', 'Int': 'Int', 'Double': 'Double', 'Bool': 'Boolean'}
READERS = {'String': 'string', 'Int': 'int', 'Double': 'double', 'Bool': 'bool'}
LIST_READERS = {'String': 'strings', 'Int': 'ints', 'Double': 'doubles', 'Bool': 'bools'}
GRID_READERS = {'String': 'stringGrid', 'Int': 'intGrid', 'Double': 'doubleGrid', 'Bool': 'boolGrid'}
KOTLIN_KEYWORDS = {'as', 'break', 'class', 'continue', 'do', 'else', 'false', 'for', 'fun', 'if', 'in',
                   'interface', 'is', 'null', 'object', 'package', 'return', 'super', 'this', 'throw',
                   'true', 'try', 'typealias', 'typeof', 'val', 'var', 'when', 'while'}


class Field:
    def __init__(self, name, swift_type, doc):
        self.name = name
        self.optional = swift_type.endswith('?')
        base = swift_type[:-1] if self.optional else swift_type
        self.depth = 0
        while base.startswith('[') and base.endswith(']'):
            base = base[1:-1].strip()
            self.depth += 1
        if base.endswith('?'):
            raise SystemExit(f'{name}: optional elements ({swift_type}) are not supported')
        if self.depth > 2:
            raise SystemExit(f'{name}: {swift_type} nests too deep')
        self.base = base
        self.doc = doc


class View:
    def __init__(self, name, fields, doc, source):
        self.name = name
        self.fields = fields
        self.doc = doc
        self.source = source


def kotlin_name(swift_name):
    if swift_name in NAME_MAP:
        return NAME_MAP[swift_name]
    if swift_name.endswith('View') and len(swift_name) > 4:
        return swift_name[:-4]
    return swift_name


def strip_comments(line):
    # Drops a trailing // comment, but not inside a string literal.
    out, quoted, i = [], False, 0
    while i < len(line):
        c = line[i]
        if c == '"':
            quoted = not quoted
        if not quoted and line.startswith('//', i):
            break
        out.append(c)
        i += 1
    return ''.join(out)


def parse_views():
    views = {}
    for file in sorted(os.listdir(SWIFT_DIR)):
        if not file.endswith('.swift'):
            continue
        lines = open(os.path.join(SWIFT_DIR, file), encoding='utf-8').read().split('\n')
        doc = []
        i = 0
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            if stripped.startswith('///'):
                doc.append(stripped[3:].strip())
                i += 1
                continue
            m = re.match(r'^\s*(?:public |private |fileprivate |internal )?struct (\w+)\s*:\s*([^{]*)\{', line)
            if m and re.search(r'\bEncodable\b', m.group(2)):
                name = m.group(1)
                struct_doc, doc = doc, []
                fields = []
                depth = line.count('{') - line.count('}')
                field_doc = []
                i += 1
                while i < len(lines) and depth > 0:
                    body = lines[i]
                    text = body.strip()
                    if depth == 1 and text.startswith('///'):
                        field_doc.append(text[3:].strip())
                    elif depth == 1:
                        code = strip_comments(body).strip()
                        fm = re.match(r'^(?:let|var)\s+(\w+)\s*:\s*([^={}]+?)\s*$', code)
                        if fm and not code.startswith('static'):
                            fields.append(Field(fm.group(1), fm.group(2).replace(' ', ''), field_doc))
                        if code and not code.startswith('@'):
                            field_doc = []
                    depth += body.count('{') - body.count('}')
                    i += 1
                if name in views:
                    raise SystemExit(f'{name} is defined twice ({views[name].source} and {file})')
                views[name] = View(name, fields, struct_doc, file)
                continue
            if stripped and not stripped.startswith('@'):
                doc = []
            i += 1
    return views


def reachable(views):
    seen, order = set(), []

    def visit(name):
        if name in seen:
            return
        if name not in views:
            raise SystemExit(f'{name} is used by a view but is not an Encodable struct in {SWIFT_DIR}')
        seen.add(name)
        order.append(name)
        for field in views[name].fields:
            if field.base not in PRIMITIVES:
                visit(field.base)

    visit(ROOT)
    return order


def kotlin_type(field):
    base = PRIMITIVES.get(field.base) or kotlin_name(field.base)
    for _ in range(field.depth):
        base = f'List<{base}>'
    return base + ('?' if field.optional else '')


def reader(field):
    key = json.dumps(field.name)
    suffix = 'OrNull' if field.optional else ''
    if field.base in PRIMITIVES:
        if field.depth == 0:
            return f'o.{READERS[field.base]}{suffix}({key})'
        if field.depth == 1:
            return f'o.{LIST_READERS[field.base]}{suffix}({key})'
        return f'o.{GRID_READERS[field.base]}{suffix}({key})'
    cls = kotlin_name(field.base)
    if field.depth == 0:
        return f'{cls}.from(o.obj({key}))' if not field.optional else f'o.objOrNull({key})?.let({cls}::from)'
    if field.depth == 1:
        return f'o.list{suffix}({key}, {cls}::from)'
    return f'o.grid{suffix}({key}, {cls}::from)'


def kdoc(lines, indent):
    if not lines:
        return ''
    text = ' '.join(lines).replace('*/', '* /')
    return f'{indent}/** {text} */\n'


def write_models(views, order):
    out = [
        '// GENERATED by android/tools/generate_models.py from the Swift views in',
        '// android/swift/Sources/CryptoClickerBridge. Don\'t edit: change the Swift view and run the script.',
        '// Numbers and wording come formatted from Swift, so both apps show them identically; these',
        '// classes only carry them. Optional Swift fields are nullable here; every other field is required.',
        '@file:Suppress("unused")',
        '',
        'package com.hilalsafi.cryptoclicker.core',
        '',
    ]
    for name in order:
        view = views[name]
        cls = kotlin_name(name)
        out.append(kdoc(view.doc, '').rstrip('\n')) if view.doc else None
        if not view.fields:
            out.append(f'class {cls} {{')
            out.append('    override fun equals(other: Any?) = other is ' + cls)
            out.append('    override fun hashCode() = 0')
            out.append('    companion object {')
            out.append(f'        fun from(@Suppress("UNUSED_PARAMETER") o: JsonObject) = {cls}()')
            out.append('    }')
            out.append('}')
            out.append('')
            continue
        out.append(f'data class {cls}(')
        for field in view.fields:
            doc = kdoc(field.doc, '    ')
            if doc:
                out.append(doc.rstrip('\n'))
            prop = f'`{field.name}`' if field.name in KOTLIN_KEYWORDS else field.name
            out.append(f'    val {prop}: {kotlin_type(field)},')
        out.append(') {')
        out.append('    companion object {')
        if name == ROOT:
            out.append('        fun parse(text: String): Response = from(Json.parseObject(text))')
            out.append('')
        out.append(f'        fun from(o: JsonObject) = {cls}(')
        for field in view.fields:
            prop = f'`{field.name}`' if field.name in KOTLIN_KEYWORDS else field.name
            out.append(f'            {prop} = {reader(field)},')
        out.append('        )')
        out.append('    }')
        out.append('}')
        out.append('')
    return '\n'.join(line for line in out if line is not None).rstrip('\n') + '\n'


def sample_value(views, field, path, stack):
    def one(base):
        if base == 'String':
            return 'text'
        if base == 'Int':
            return 1
        if base == 'Double':
            return 1.5
        if base == 'Bool':
            return True
        return sample(views, base, stack)

    value = one(field.base)
    for _ in range(field.depth):
        value = [value]
    return value


def sample(views, name, stack=()):
    if name in stack:
        raise SystemExit(f'{" -> ".join(stack + (name,))}: views may not contain themselves')
    return {field.name: sample_value(views, field, name, stack + (name,)) for field in views[name].fields}


def main():
    check = '--check' in sys.argv[1:]
    views = parse_views()
    order = reachable(views)
    unused = sorted(set(views) - set(order))
    models = write_models(views, order)
    contract = json.dumps(sample(views, ROOT), indent=2, sort_keys=True, ensure_ascii=False) + '\n'
    outputs = [(MODELS, models), (CONTRACT, contract)]
    stale = []
    for path, text in outputs:
        current = open(path, encoding='utf-8').read() if os.path.exists(path) else None
        if current != text:
            stale.append(path)
            if not check:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(text)
    fields = sum(len(views[n].fields) for n in order)
    if unused:
        print('Not reachable from Response (left out):', ', '.join(unused))
    if check:
        if stale:
            print('Out of date (run android/tools/generate_models.py):', *[os.path.relpath(p, ANDROID) for p in stale])
            sys.exit(1)
        print(f'Models and contract are up to date: {len(order)} views, {fields} fields.')
    else:
        print(f'Wrote {len(order)} views, {fields} fields' + (f'; updated {len(stale)} file(s).' if stale else '; nothing changed.'))


if __name__ == '__main__':
    main()
