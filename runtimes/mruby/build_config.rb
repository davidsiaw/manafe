# mruby build configuration for the browser runtime. Used by ./build.
#
# The host build exists only to produce mrbc, which the cross build needs to
# compile mruby's own Ruby sources.
MRuby::Build.new do |conf|
  conf.toolchain
  conf.gembox 'default'
end

MRuby::CrossBuild.new('emscripten') do |conf|
  conf.toolchain :emscripten

  conf.gembox 'stdlib'      # pack, sprintf, Time, Struct, Data, Random
  conf.gembox 'stdlib-ext'  # the String, Array, Hash, Enumerable... extensions
  conf.gembox 'math'        # Math, Rational, Complex, bigint
  conf.gembox 'metaprog'    # send, define_method, instance_variable_get...
  conf.gem core: 'mruby-io' # puts, print, printf and p live here in mruby 3.4
  conf.gem core: 'mruby-errno'
  conf.gem core: 'mruby-compiler' # to run source code, not just bytecode
  conf.gem core: 'mruby-error'
  conf.gem core: 'mruby-bin-config' # mruby-config, for the flags to link with

  conf.cc.flags << '-Oz'
end
