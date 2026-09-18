// Godot
// =====

// The JS twins of godot.c, so `bend main.bend` still checks and runs a
// program outside the engine. There is no engine here: print goes to
// stdout, frames tick at 60 Hz without waiting, every object is a fresh
// slot, and a call pops its arguments and answers Nil.

const gd_stack = [];
let   gd_slots = 1;

const GD_UNIT = { $: "Unit" };

function gd_print(text) {
  io_out(1, io_bytes(text + "\n"));
  return GD_UNIT;
}

function gd_frame() {
  return 1 / 60;
}

function gd_self() {
  return 1;
}

function gd_singleton(name) {
  return ++gd_slots;
}

function gd_new(name) {
  return ++gd_slots;
}

function gd_put(kind, v) {
  gd_stack.push([kind, v]);
  return GD_UNIT;
}

function gd_push_nil()       { return gd_put(0n, null); }
function gd_push_bool(v)     { return gd_put(1n, Number(v) !== 0); }
function gd_push_int(v)      { return gd_put(2n, v); }
function gd_push_float(v)    { return gd_put(3n, v); }
function gd_push_str(v)      { return gd_put(4n, v); }
function gd_push_vec2(x, y)  { return gd_put(5n, [x, y]); }
function gd_push_obj(slot)   { return gd_put(6n, slot); }
function gd_push_vec3(x, y, z)     { return gd_put(7n, [x, y, z]); }
function gd_push_color(r, g, b, a) { return gd_put(8n, [r, g, b, a]); }

function gd_array_new(n) {
  const items = gd_stack.splice(gd_stack.length - Number(n));
  return gd_put(9n, items);
}

function gd_array_open() {
  const items = gd_take();
  gd_stack.push(...items);
  return items.length;
}

function gd_call(slot, method, argc) {
  gd_stack.length -= Number(argc);
  return gd_put(0n, null);
}

function gd_kind() {
  return gd_stack[gd_stack.length - 1][0];
}

function gd_take() {
  return gd_stack.pop()[1];
}

function gd_pop()       { gd_take(); return GD_UNIT; }
function gd_pop_bool()  { return gd_take(); }
function gd_pop_int()   { return gd_take(); }
function gd_pop_float() { return gd_take(); }
function gd_pop_str()   { return gd_take(); }
function gd_pop_vec2()  { const p = gd_take(); return io_tup(p[0], p[1]); }
function gd_pop_obj()   { return gd_take(); }

function gd_pop_vec3() {
  const p = gd_take();
  return io_tup(p[0], io_tup(p[1], p[2]));
}

function gd_pop_color() {
  const c = gd_take();
  return io_tup(c[0], io_tup(c[1], io_tup(c[2], c[3])));
}

// No engine, no signals: the queue stays empty.
function gd_connect(slot, signal, tag) { return GD_UNIT; }
function gd_events()                   { return 0n; }
function gd_event()                    { return 0; }
function gd_drop(slot)                 { return GD_UNIT; }
function gd_listen(on)                 { return GD_UNIT; }

function gd_static(cls, method, hash, argc) {
  gd_stack.length -= Number(argc);
  return gd_put(0n, null);
}

function gd_util(name, hash, sig) {
  gd_stack.length -= sig.indexOf(">");
  return gd_put(0n, null);
}
