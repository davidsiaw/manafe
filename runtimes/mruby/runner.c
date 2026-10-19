/*
  The entry point the browser calls: run one Ruby program in a fresh
  interpreter. Output goes to stdout/stderr, which Emscripten hands to the
  Module's print/printErr callbacks. Returns 0 on success, 1 if the program
  raised (the error and backtrace are printed to stderr).
*/
#include <stdio.h>
#include <emscripten.h>
#include <mruby.h>
#include <mruby/compile.h>

EMSCRIPTEN_KEEPALIVE
int manabase_run(const char *code)
{
  mrb_state *mrb = mrb_open();
  if (!mrb) {
    fputs("could not start mruby\n", stderr);
    return 2;
  }

  mrbc_context *cxt = mrbc_context_new(mrb);
  mrbc_filename(mrb, cxt, "main.rb");
  mrb_load_string_cxt(mrb, code, cxt);

  int status = 0;
  if (mrb->exc) {
    mrb_print_error(mrb);
    status = 1;
  }

  fflush(stdout);
  fflush(stderr);
  mrbc_context_free(mrb, cxt);
  mrb_close(mrb);
  return status;
}
