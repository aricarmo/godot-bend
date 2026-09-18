// Godot
// =====

// The JS twins of godot.c, so `bend main.bend` still checks and runs a
// program outside the engine: print goes to stdout and frames tick at
// 60 Hz without waiting.

function gd_print(text) {
  io_out(1, io_bytes(text + "\n"));
  return { $: "Unit" };
}

function gd_frame() {
  return 16667;
}
