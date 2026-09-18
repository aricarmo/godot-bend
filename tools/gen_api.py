#!/usr/bin/env python3
"""Generates typed Bend wrappers for Godot classes, one file per class.

  godot --headless --dump-extension-api        # writes extension_api.json
  tools/gen_api.py extension_api.json godot/api Node Node2D Sprite2D
  tools/gen_api.py extension_api.json godot/api --all

A wrapper is a thin def over the dynamic core of Godot.bend:

  def set_position(self: Godot.Object, position: Godot.Vec2) -> IO(Unit):
    Godot.run(self, "set_position", [Godot.vec2(position)])

So it adds the types and nothing else: the call still goes by name, through
the same stack, and a wrong receiver still answers the type's zero and an
error in Godot's log. Objects stay one type, Godot.Object (Bend has no
subtyping), so a Sprite2D takes Node2D.set_position as it is.

A static method takes no object and goes by its hash (Godot.static), and
Global.bend holds what belongs to no class: the global enums (KEY_W) and
the utility functions (randf, lerp, ..), which go by hash and a spelling of
their types (Godot.util).

A method's trailing arguments with defaults are left to Godot: `name` takes
the required ones, and `name.all` takes every one. A method with an argument
of a kind the binding does not carry yet (RID, Dictionary, Transform2D, ..)
is skipped and counted in the file's header; an answer of such a kind comes
back as a raw Godot.Variant.
"""

import json
import os
import sys

# Names a Bend parameter cannot take.
RESERVED = {
    "def", "type", "law", "match", "case", "do", "return", "import", "as",
    "for", "exs", "where", "is", "with", "in", "if", "else", "let", "self",
    "Type", "Data", "Kind", "Quant",
}

# Godot type -> (Bend type, how to make the Variant, which call reads it)
PLAIN = {
    "bool":       ("Bool",         "Godot.VBool{%s}",   "call_bool"),
    "int":        ("U32",          "Godot.VInt{%s}",    "call_int"),
    "float":      ("F32",          "Godot.VFloat{%s}",  "call_float"),
    "String":     ("String",       "Godot.VStr{%s}",    "call_str"),
    "StringName": ("String",       "Godot.VStr{%s}",    "call_str"),
    "NodePath":   ("String",       "Godot.VStr{%s}",    "call_str"),
    "Vector2":    ("Godot.Vec2",   "Godot.vec2(%s)",    "call_vec2"),
    "Vector3":    ("Godot.Vec3",   "Godot.vec3(%s)",    "call_vec3"),
    "Color":      ("Godot.Color",  "Godot.color(%s)",   "call_color"),
    "Array":      ("List<&2, Godot.Variant>", "Godot.VArr{%s}", "call_list"),
    "Variant":    ("Godot.Variant", "%s",               "call"),
}


def kind(gtype, classes):
    """The (Bend type, maker, call) of a Godot type, or None."""
    if gtype.startswith("enum::") or gtype.startswith("bitfield::"):
        return PLAIN["int"]
    if gtype.startswith("typedarray::"):
        return PLAIN["Array"]
    if gtype in PLAIN:
        return PLAIN[gtype]
    if gtype in classes:
        return ("Godot.Object", "Godot.VObj{%s}", "call_obj")
    return None


def param(name, taken):
    name = name if name not in RESERVED else name + "_"
    while name in taken:
        name += "_"
    taken.add(name)
    return name


def pack(items, indent, last=""):
    """Items joined by commas into lines of at most 80 columns."""
    lines, cur = [], indent
    for i, item in enumerate(items):
        piece = item + ("," if i + 1 < len(items) else last)
        if cur.strip() and len(cur) + 1 + len(piece) > 80:
            lines.append(cur.rstrip())
            cur = indent
        cur += ("" if cur == indent else " ") + piece
    return lines + [cur.rstrip()]


def def_head(name, params, rtype):
    one = "def %s(%s) -> %s:" % (name, ", ".join(params), rtype)
    if len(one) <= 80:
        return [one]
    return ["def %s(" % name] + pack(params, "  ") + [") -> %s:" % rtype]


def def_body(caller, method, values, vararg):
    items = "[" + ", ".join(values) + "]"
    if vararg:
        items = "List.append(&2, Godot.Variant, %s, rest)" % items
    one = '  %s(self, "%s", %s)' % (caller, method, items)
    if len(one) <= 80:
        return [one]
    if vararg:
        return ['  %s(self, "%s",' % (caller, method), "    " + items + ")"]
    return (['  %s(self, "%s", [' % (caller, method)]
            + pack(values, "    ", "])"))


def answer(rkind, action, indent="  "):
    """A body that runs action, an IO(Variant), and reads it as rkind."""
    if rkind is None:
        return [indent + "Godot.done(" + action + ")"]
    if rkind[2] == "call":
        return [indent + action]
    return [indent + "do IO<%s>:" % rkind[0],
            indent + "  v : Godot.Variant <- " + action,
            indent + "  return Godot.to_%s(v)" % rkind[2][5:]]


def method_defs(m, classes, used, owner=""):
    """The defs of one method ([] when it cannot be carried) and a reason.
    used holds the file's def names: a method that meets one (GDScript has
    a method called new) gets a trailing underscore."""
    if m.get("is_virtual"):
        return [], "virtual"
    args = m.get("arguments", [])
    kinds = [kind(a["type"], classes) for a in args]
    if any(k is None for k in kinds):
        return [], "argument"
    ret = m.get("return_value")
    rkind = kind(ret["type"], classes) if ret else None
    if ret and rkind is None:
        rkind = PLAIN["Variant"]
    required = sum(1 for a in args if "default_value" not in a)
    out = []
    base = m["name"]
    while base in used:
        base += "_"
    used.add(base)
    variants = [(base, required)]
    if required < len(args):
        variants.append((base + ".all", len(args)))
    for name, count in variants:
        taken = set()
        names = [param(a["name"], taken) for a in args[:count]]
        params = ([] if m.get("is_static") else ["self: Godot.Object"]) + [
            "%s: %s" % (n, k[0]) for n, k in zip(names, kinds)]
        values = [k[1] % n for n, k in zip(names, kinds)]
        if m.get("is_vararg"):
            params.append("rest: List<&2, Godot.Variant>")
        rtype = "IO(%s)" % rkind[0] if ret else "IO(Unit)"
        caller = "Godot." + (rkind[2] if ret else "run")
        out += def_head(name, params, rtype)
        if m.get("is_static"):
            items = "[" + ", ".join(values) + "]"
            if m.get("is_vararg"):
                items = "List.append(&2, Godot.Variant, %s, rest)" % items
            out += answer(rkind if ret else None, 'Godot.static("%s", "%s", %d, %s)'
                          % (owner, m["name"], m["hash"], items))
        else:
            out += def_body(caller, m["name"], values, m.get("is_vararg"))
        out += [""]
    return out, None


def u32(value):
    """An enum value as the U32 a VInt carries, or None past 32 bits."""
    if -(1 << 31) <= value < (1 << 32):
        return value & 0xFFFFFFFF
    return None


def class_file(c, classes, singletons):
    name = c["name"]
    lines = []
    skipped = {}
    body = []
    if c.get("is_instantiable"):
        body += ["def new() -> IO(Godot.Object):",
                 '  Godot.new("%s")' % name, ""]
    if name in singletons:
        body += ["def singleton() -> IO(Godot.Object):",
                 '  Godot.singleton("%s")' % name, ""]
    seen = {"new", "singleton"}
    for enum in c.get("enums", []):
        for v in enum["values"]:
            n = u32(v["value"])
            if n is not None and v["name"] not in seen:
                seen.add(v["name"])
                body += ["def %s() -> U32:" % v["name"], "  %d" % n, ""]
    for k in c.get("constants", []):
        n = u32(k["value"])
        if n is not None and k["name"] not in seen:
            seen.add(k["name"])
            body += ["def %s() -> U32:" % k["name"], "  %d" % n, ""]
    count = 0
    for m in c.get("methods", []):
        defs, why = method_defs(m, classes, seen, name)
        if why:
            skipped[why] = skipped.get(why, 0) + 1
        else:
            count += 1
            body += defs
    parent = c.get("inherits")
    lines += ["# %s" % name, "# " + "=" * len(name), ""]
    lines += ["# Godot's %s%s, generated by tools/gen_api.py from" % (
        name, " (inherits %s)" % parent if parent else "")]
    lines += ["# extension_api.json; edit the generator, not this file. %d" % count]
    lines += ["# methods; left out: %s." % (", ".join(
        "%d %s" % (n, "with an argument not carried yet" if w == "argument"
                   else w) for w, n in sorted(skipped.items())) or "none")]
    if parent:
        lines += ["# An inherited method is in %s.bend: objects are one type," % parent,
                  "# so it takes a %s as it is." % name]
    lines += ["import Base", "import ../Godot.bend as Godot", ""]
    return "\n".join(lines + body).rstrip("\n") + "\n"


SIG = {"float": "f", "int": "i", "bool": "b", "String": "s", "Variant": "v"}


def global_file(api, classes):
    """Global.bend: the global enums and the utility functions."""
    body, seen, count, skipped = [], set(), 0, 0
    for enum in api["global_enums"]:
        body += ["# %s" % enum["name"], ""]
        for v in enum["values"]:
            n = u32(v["value"])
            if n is not None and v["name"] not in seen:
                seen.add(v["name"])
                body += ["def %s() -> U32:" % v["name"], "  %d" % n, ""]
    body += ["# Utility functions", ""]
    for f in api["utility_functions"]:
        args = f.get("arguments", [])
        rtype = f.get("return_type")
        rsig = "-" if rtype is None else "o" if rtype == "Object" else SIG.get(rtype)
        if f.get("is_vararg") or rsig is None or any(a["type"] not in SIG for a in args):
            skipped += 1
            continue
        count += 1
        taken = set()
        names = [param(a["name"], taken) for a in args]
        kinds = [kind(a["type"], classes) for a in args]
        rkind = kind(rtype, classes) if rtype else None
        sig = "".join(SIG[a["type"]] for a in args) + ">" + rsig
        name = f["name"]
        while name in seen:
            name += "_"
        seen.add(name)
        head = def_head(name, ["%s: %s" % (n, k[0]) for n, k in zip(names, kinds)],
                        "IO(%s)" % rkind[0] if rkind else "IO(Unit)")
        items = "[" + ", ".join(k[1] % n for n, k in zip(names, kinds)) + "]"
        body += head + answer(rkind, 'Godot.util("%s", %d, "%s", %s)' % (
            f["name"], f["hash"], sig, items)) + [""]
    lines = ["# Global", "# ======", "",
             "# What belongs to no class, generated by tools/gen_api.py from",
             "# extension_api.json; edit the generator, not this file: the global",
             "# enums, a def per value, and %d utility functions (%d left out: the" % (count, skipped),
             "# vararg ones and those over a kind not carried yet). Bend has its own",
             "# F32 math, which is pure; these are effects, and worth it for what",
             "# only the engine knows, like its random numbers.",
             "import Base", "import ../Godot.bend as Godot", ""]
    return "\n".join(lines + body).rstrip("\n") + "\n"


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    api = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    classes = {c["name"]: c for c in api["classes"]}
    singletons = {s["name"] for s in api["singletons"]}
    wanted = list(classes) if sys.argv[3] == "--all" else sys.argv[3:]
    os.makedirs(out, exist_ok=True)
    for name in wanted:
        if name not in classes:
            sys.exit("no class named " + name)
        with open(os.path.join(out, name + ".bend"), "w") as f:
            f.write(class_file(classes[name], classes, singletons))
    with open(os.path.join(out, "Global.bend"), "w") as f:
        f.write(global_file(api, classes))
    print("wrote %d files to %s, and Global.bend" % (len(wanted), out))
    total = sum(len(classes[n].get("methods", [])) for n in wanted)
    kept = sum(1 for n in wanted for m in classes[n].get("methods", [])
               if method_defs(m, classes, set())[1] is None)
    print("%d of %d methods carried" % (kept, total))


if __name__ == "__main__":
    main()
