---
title: Mojo🔥 changelog
sidebar_label: Changelog
description: A history of significant Mojo changes.
toc_max_heading_level: 2
---

This is a list of changes to the Mojo language, standard library, and tools.

To check your current version, run `mojo --version`.

## v25.6 nightly

This version is still a work in progress.

See how to [install the nightly release](/max/packages#install).

<!-- INSERT HERE : This line is required for post-process-docs.py -->

## v25.5 (pending)

### ✨ Highlights

### Language enhancements

- `@parameter for` now works on a broader range of collection types, enabling
  things like `@parameter for i in [1, 2, 3]: ...`.

- Parametric aliases are now supported: Aliases can be specified with an
  optional parameter list (just like functions). Parametric aliases are
  considered first class parameter values, too.

- The compiler now detects attempts to materialize references (and related types
  like slices/pointers) to comptime interpreter stack memory into runtime code.
  The compiler cannot currently track the lifetime of internal stack objects
  when materialized to runtime, which could cause memory leaks.  Consider this
  example:

  ```mojo
  fn test_comptime_materialize():
    # This is ok! Forms a comptime reference to a comptime "stack" value of String
    # type.
    alias bad = String("foo" + "bar").unsafe_ptr()
    # This is ok too, dereferences the pointer at comptime loading the byte.
    alias byte = bad[]
    # This materializes a Byte from comptime to runtime.
    var rt_byte = byte
    # Error: cannot materialize to runtime value, the type contains an origin
    # referring to a compile-time value
    var use_bad = bad
  ```

  Previously the compiler would materialize the memory representation of the
  `String` value but not know it needs to be destroyed.  It now detects the
  problem. If you run into this, rework the code to materialize the full object
  (e.g. the String) to runtime explicitly.

- `StringLiteral` now automatically materializes to a `String` when used at
  runtime:

  ```mojo
  alias param = "foo"        # type = StringLiteral
  var runtime_value = "bar"  # type = String
  var runtime_value2 = param # type = String
  ```

  This enables all the behavior users expect without having to convert
  or annotate types, for example:

  ```mojo
  var string = "hello"
  string += " world"

  var if_result = "foo" if True else "bar"
  ```

Initializing a `String` from a `StringLiteral` initially points to static
constant memory, and does not perform SSO or allocate until the first
mutation.

### Language changes

- The `@value` decorator has been formally deprecated with a warning, it will
  be removed in the next release of Mojo.  Please move to the `@fieldwise_init`
  and synthesized `Copyable` and `Movable` trait conformance.

- Implicit trait conformance is removed. All conformances must be explicitly
  declared.

- The `owned` argument convention is being renamed to `var`. This reflects that
  `var` is used consistently for a "named, scoped, owning of a value" already
  which is exactly what the `owned` convention does.  In this release, both
  `var` and `owned` are allowed in an argument list, but `owned` will be removed
  in a subsequent release, so please move your code over.

- Function overloading is now fully supported as long as, among two function
  signatures with the same list of argument types, one position is a
  keyword-only argument in at least one signature, and that position differs in
  argument name. Previously an edge case prevented this support when the return
  types are different. For example, these two functions can now co-exist:

  ```mojo
  fn get(self, idx: Int) -> Int
  fn get(self, *, idx2: Int) -> Float32
  ```

### Standard library changes

- The `Dict` now has an `H` parameter which allows users to provider a
  custom `Hasher` type.
  - `default_hasher` (AHasher) and `default_comp_time_hasher` (Fnv1a)
    are now provided
  - The `H` parameter of `Dict` defaults to `default_hasher`

- The `Hashable` trait has been updated to use a new data flow strategy.
  - Users are now required to implement the method
    `fn __hash__[H: Hasher](self, mut hasher: H):`
    (see `Hashable` docstring for further details).

- Indexing into a `String` now returns a `StringSlice`, avoiding an allocation.

- Added support for a wider range of consumer-grade AMD hardware, including:
  - AMD Radeon RX 7xxx GPUs
  - AMD Radeon RX 9xxx GPUs
- Compile-time checks for AMD RDNA3+ GPUs are now provided by the functions:
  - `_is_amd_rdna3()`
  - `_is_amd_rdna4()`
  - `_is_amd_rdna()`
- Added WMMA matrix-multiplication instructions for RDNA3+ GPUs to help support
  running AI models on those GPUs.

- `memory.UnsafePointer` is now implicitly included in all mojo files. Moreover,
  `OpaquePointer` (the equivalent of a `void*` in C) is moved into the `memory`
  module, and is also implicitly included.

- Python interop changes:

  - Mojo functions can now natively accept
    keyword arguments from Python using `OwnedKwargsDict[PythonObject]` as the
    last parameter. This enables direct calling from Python with keyword
    arguments without requiring wrapper functions.

    ```mojo
    from collections import OwnedKwargsDict

    # Callable from Python as `foo(10, y=20)`
    fn foo(x: PythonObject, kwargs: OwnedKwargsDict[PythonObject]):
        y = kwargs["y"]
    ```

  - The `PythonTypeBuilder` utility now allows:
    - registering bindings for Python static methods, i.e. methods that don't
      require an instance of the class.
    - registering initializers that take arguments. Types no longer need to be
      `Defaultable` to be exposed and created from Python.

  - The `PythonConvertible` trait has been renamed to `ConvertibleToPython`.
    This is now consistent with the `ConvertibleFromPython` trait, modeling
    Mojo types that can be converted either to or from a `PythonObject`.

- Added `Iterator` trait for modeling types that produce a sequence of values.

  A type can implement `Iterator` by providing `__next__()` and `__has_next__()`
  methods. This naming and behavior is based on
  the Python
  [`Iterator`](https://docs.python.org/3/library/collections.abc.html#collections.abc.Iterator)
  typing annotation, diverging slightly due to constraints present in Mojo today.

  Any type that implements `Iterator` can be used within `for` and
  `@parameter for` looping syntax.

  `Iterator` does not currently have a variant for supporting iteration over
  borrowed `ref` values.

- `InlineArray` can now be constructed with a size of 0. This makes it easier to
  use `InlineArray` in situations where the number of elements is generic and
  could also be 0.

- `List.append(Span)` has been renamed to `List.extend(Span)`. It is important
  for readability and consistency that `append()` always grows the length of
  the list by exactly 1. `extend()` in both Python and Rust is the variant of
  this operation that takes an arbitrary-length number of additional elements
  (possibly 0) to add to the list.

- A new `io` module is available in the library. Some core input/output types
  previously in the `builtin` module have been moved and imports may need to be
  adjusted.
  - `utils/write.mojo` got moved to `io/write.mojo` as well.

- Added support for NVIDIA GeForce RTX 3090.

- `String.split()` now returns a `List[StringSlice]`.

- `StringLiteral.strip()` family of functions now return a `StaticString`.

### Tooling changes

- Added support for GCC-style debug flags `-g0`, `-g1`, and `-g2` to match
  common compiler conventions:
  - `-g0`: No debug information (alias for `--debug-level=none`)
  - `-g1`: Line table debug information (alias for `--debug-level=line-tables`)
  - `-g2`: Full debug information (alias for `--debug-level=full`)

- Added progress reporting support to the Mojo language server. This will emit progress
  notifications in your editor when the server is currently parsing a document.

### ❌ Removed

- Various functions from the `sys.info` have been removed.  Use the appropriate method
  on `CompilationTarget` from `sys.info` instead.
  - `is_x86()`
  - `has_sse4()`
  - `has_avx()`
  - `has_avx2()`
  - `has_avx512f()`
  - `has_fma()`
  - `has_vnni()`
  - `has_neon()`
  - `has_neon_int8_dotprod()`
  - `has_neon_int8_matmul()`

- `UnsafePointer.address_of()` has been removed.  Use `UnsafePointer(to=...)`
  constructor instead.  Similarly, `Pointer.address_of()` has been removed.

- `DType.tensor_float32` has been removed due to lack of support for it in the
  library and the compiler.

### 🛠️ Fixed

- [#4121](https://github.com/modular/modular/issues/4121) - better error message
  for `.value()` on empty `Optional`.

- [#4566](https://github.com/modular/modular/issues/4566) - Hang when assigning
  loop variable inside `@parameter for`.

- [#4820](https://github.com/modular/modular/issues/4820) - `math.exp2` picks
  the wrong implementation for `float64`.

- [#4836](https://github.com/modular/modular/issues/4836) - Else path in
  `@parameter for` broken.

- [#4499](https://github.com/modular/modular/issues/4499) - Traits with
  `ref self` cause issues when used as parameter.

- [#4911](https://github.com/modular/modular/issues/4911) - `InlineArray`
  now calls the move constructor for its elements when moved.

- [#3927](https://github.com/modular/modular/issues/3927) - `InlineArray`
  now can be constructed with a size of 0.

- [#4954](https://github.com/modular/modular/issues/4954) - `InlineArray`
  now does not call the copy constructor when being moved.

- [#5066](https://github.com/modular/modular/issues/5066) - Correctly fill
  64-bit values on AMD in `enqueue_fill`.

- [#4982](https://github.com/modular/modular/issues/4982) - Add `toggle_all`
  to `BitSet`.

- [#5086](https://github.com/modular/modular/issues/5086) - Add `set_all`
  to `BitSet`.

- [#5057](https://github.com/modular/modular/issues/5057) - Span
  Performance Regression.

- [#5051](https://github.com/modular/modular/issues/5051) - Incorrect
  `.modular` Directory Location on Linux.

- [#5021](https://github.com/modular/modular/issues/5021) - LSP Crashes
  in VSCode when a local package exists.

- [#5016](https://github.com/modular/modular/issues/5016) - Conditional
  Conformance Trait Alias Bug.

## v25.4 (2025-06-18)

### ✨ Highlights {#25-4-highlights}

- Mojo now supports AMD GPUs, expanding hardware compatibility beyond NVIDIA
  to include AMD's GPU ecosystem. This enables Mojo applications to leverage
  AMD's RDNA and CDNA architectures for high-performance computing workloads,
  providing developers with greater flexibility in choosing hardware platforms
  for AI and compute-intensive applications.

- Primitives for working with NVIDIA Blackwell GPUs have been added,
  providing low-level access to the latest GPU architecture features. These
  primitives enable developers to take advantage of Blackwell's enhanced
  compute capabilities, improved memory bandwidth, and advanced AI acceleration
  features, including support for newer tensor operations and optimized memory
  management patterns.

- The Python-Mojo bindings are available as a preview release! This is the
  ability to call into Mojo functions from existing Python codebases. The use
  case is to speed up hot spots/slow Python code by rewriting certain portions
  of your code in Mojo to achieve performance.

- Mojo collection types received many enhancements.

  - [`List`](/mojo/stdlib/collections/list/List/),
    [`Set`](/mojo/stdlib/collections/set/Set/), and
    [`Dict`](/mojo/stdlib/collections/dict/Dict/) literals have been
    reimplemented to provide Python-equivalent features and syntax, including
    simple literals like `[1, 2, 3]` and `{k1: v1, k2: v2}`.

  - List comprehensions like
    `[a*b for a in range(10) if isprime(a) for b in range(20)]`
    as well as dictionary and set comprehensions are now supported.

  - Iterating over a collection with a `for` loop no longer requires using the
    `[]` deference operator.

  See [Language enhancements](#25-4-language-enhancements) and
  [Standard library changes](#25-4-standard-library-changes) for more details.

- The entire MAX Kernel library is now fully open sourced! For more information,
  see the
  [MAX AI kernels library reference](/mojo/lib#max-ai-kernels-library) and the
  [MAX AI kernels source](https://github.com/modular/modular/tree/main/max/kernels).

- Mojo is now available on [Godbolt.org](https://godbolt.org), which is also
  known as the "Compiler Explorer". See <https://mojo.godbo.lt/z/EshWcoqe7> for
  an example.

### Language enhancements {#25-4-language-enhancements}

- `var` declarations in functions now support more flexible "patterns", allowing
  multiple values to be declared at once, for example `var a, b = 4, 5` and
  `var a, b : Int, Float64`.

- Mojo now supports the use of Python-style type patterns when declaring
  variables on first assignment without the `var` keyword. For example, `x = 4;
  y: UInt8 = 5` declares both `x` and `y`, where `x` is inferred to the default
  type of `Int` whereas `y` gets the explicit type `UInt8`. Declaring variables
  without `var` gives you a function-scoped name, whereas `var` makes things
  scoped to the statement they are in (lexical scoping), such as the body of an
  `if` statement.

- Mojo now supports `ref` patterns that bind a stored LValue into a named
  declaration, extending the argument convention into local function scope.

  This can be useful when you want to do something with a reference, but don't
  want the conceptual overhead of a
  [`Pointer`](/mojo/stdlib/memory/pointer/Pointer/). These are equivalent:

  ```mojo
  fn use_pointer(your_list: List[Int]):
      var p = Pointer(to=your_list[i])  # Form a safe pointer
      ...
      use(p[])     # dereference it

  fn use_ref(your_list: List[Int]):
      ref r = your_list[i]  # Bind element reference to 'r'
      ...
      use(r)     # use it
  ```

  References are bound in their initializer and cannot be mutated afterward:
  uses and mutations of the reference are interpreted as uses and mutations
  of the value referenced by the value.

- The Mojo compiler will now synthesize `__moveinit__()`, `__copyinit__()`, and
  `copy()` methods for structs that conform to
  [`Movable`](/mojo/stdlib/builtin/value/Movable/),
  [`Copyable`](/mojo/stdlib/builtin/value/Copyable/), and
  [`ExplicitlyCopyable`](/mojo/stdlib/builtin/value/ExplicitlyCopyable/)
  (respectively) but that do not implement the methods explicitly.

- A new [`@fieldwise_init`](/mojo/manual/decorators/fieldwise-init) decorator
  can be attached to structs to synthesize a field-wise initializer—an
  `__init__()` method that takes the same arguments as the fields in the struct.
  This gives access to this helpful capability without having to opt into the
  rest of the methods that `@value` synthesizes. This decorator allows an
  optional `@fieldwise_init("implicit")` form for single-element structs, which
  marks the initializer as [`@implicit`](/mojo/manual/decorators/implicit).

- `try` and `raise` now work at compile time.

- "Initializer lists" are now supported for creating struct instances with an
  inferred type based on context, for example:

  ```mojo
  fn foo(x: SomeComplicatedType): ...

  # Example with normal initializer.
  foo(SomeComplicatedType(1, kwarg=42))
  # Example with initializer list.
  foo({1, kwarg=42})
  ```

- List literals have been redesigned to work better. They produce homogenous
  sequences by invoking the `T(<elements>, __list_literal__: ())` constructor of
  a type `T` that is inferred by context, or otherwise defaulting to the
  standard library [`List`](/mojo/stdlib/collections/list/List/) type. The
  `ListLiteral` type has been removed from the standard library.

- Dictionary and set literals now work and default to creating instances of the
  [`Dict`](/mojo/stdlib/collections/dict/Dict/) and
  [`Set`](/mojo/stdlib/collections/set/Set/) types in the collections library.

### Language changes {#25-4-language-changes}

- Implicit trait conformance is deprecated. Each instance of implicit
  conformance results in a warning, but compilation still goes through. Soon it
  will be upgraded into an error. Any code currently relying on implicit
  conformance should either declare conformances explicitly or, if appropriate,
  replace empty, non-load-bearing traits with trait compositions.

- Mojo doesn't allow the use of `out` or `mut` as an argument name any longer.
  Previously you could use `fn x(out: Int)`, but this causes ambiguity with
  function types. Please use names like `output` instead.

- `def` arguments are no longer implicitly mutable. If you would like to have a
   locally mutable argument, declare it `owned` explicitly.

- Global (file-scope) variables are deprecated. Global variables in Mojo are
  only partially implemented and are known to cause cryptic errors. Now the Mojo
  compiler issues a warning on global variable usage.

### Standard library changes {#25-4-standard-library-changes}

- GPU programming enhancements and changes:

  - Mojo now supports AMD GPUs, expanding hardware compatibility beyond NVIDIA
    to include AMD's GPU ecosystem. This enables Mojo applications to leverage
    AMD's RDNA and CDNA architectures for high-performance computing workloads,
    providing developers with greater flexibility in choosing hardware platforms
    for AI and compute-intensive applications.

  - Primitives for working with NVIDIA Blackwell GPUs have been added,
    providing low-level access to the latest GPU architecture features. These
    primitives enable developers to take advantage of Blackwell's enhanced
    compute capabilities, improved memory bandwidth, and advanced AI acceleration
    features, including support for newer tensor operations and optimized memory
    management patterns. See the [`gpu.tcgen05`](/mojo/stdlib/gpu/tcgen05/)
    module API reference documentation for more information.

  - Added support for a wider range of consumer-grade hardware, including:
    - NVIDIA RTX 2060 GPUs
    - NVIDIA RTX 4090 GPUs

  - Fixed the `sum()` and `prefix_sum()` implementations in the
    [`gpu.block`](/mojo/stdlib/gpu/block/) and
    [`gpu.warp`](/mojo/stdlib/gpu/warp/) modules. Previously, the
    implementations have been incorrect and would either return wrong results or
    hang the kernel (due to the deadlock). [PR
    4508](https://github.com/modular/modular/pull/4508) and [PR
    4553](https://github.com/modular/modular/pull/4553) by [Kirill
    Bobyrev](https://github.com/kirillbobyrev) mitigate the found issues and add
    tests to ensure correctness going forward.

- Collection type enhancements and changes:

  - The [`Dict`](/mojo/stdlib/collections/dict/Dict/) type is now part of the
    prelude, so there is no need to import it anymore.

  - The [`List`](/mojo/stdlib/collections/list/List/),
    [`Span`](/mojo/stdlib/memory/span/Span/),
    [`Dict`](/mojo/stdlib/collections/dict/Dict/),
    [`Set`](/mojo/stdlib/collections/set/Set/),
    [`VariadicPack`](/mojo/stdlib/builtin/variadics/VariadicPack/), and
    [`Deque`](/mojo/stdlib/collections/deque/Deque/) iterators now return
    references to elements directly, instead of returning
    [`Pointer`](/mojo/stdlib/memory/pointer/Pointer/). This means that you
    should no longer use the `[]` deference operator with the loop index
    variable:

    ```mojo
    var states: List[String] = ["California", "Hawaii", "Oregon"]

    # Old:
    for state in states:
      print(state[])

    # New:
    for state in states:
      # state is an immutable reference
      print(state)
    ```

    By default the reference is immutable. You can use the `ref` keyword
    to bind the index variable as a mutable reference:

    ```mojo
    for ref state in states:
      # state is a mutable reference
      state += "!"  # Update the existing list element
    ```

  - [`List`](/mojo/stdlib/collections/list/List/),
    [`InlineArray`](/mojo/stdlib/collections/inline_array/InlineArray/),
    [`Deque`](/mojo/stdlib/collections/deque/Deque/),
    [`LinkedList`](/mojo/stdlib/collections/linked_list/LinkedList/), and
    [`SIMD`](/mojo/stdlib/builtin/simd/SIMD/) types all support construction via
    list literal syntax:

    ```mojo
    var list: List[Int] = [1, 2, 3]
    var vec: SIMD[DType.uint8, 8] = [1, 2, 3, 4, 5, 6, 7, 8]
    var deque: Deque[Float64] = [1, 2.5]
    var llist: LinkedList[Int] = [1, 2, 3]
    var arr: InlineArray[String, 3] = ["hi", "hello", "hey"]
    ```

  - [`Dict`](/mojo/stdlib/collections/dict/Dict/) and
    [`Set`](/mojo/stdlib/collections/set/Set/) support construction via dict
    literal and set literal syntax, respectively:

    ```mojo
    var dict1 = {String("foo"): 1, String("bar"): 2}  # Dict[String, Int]
    var dict2 = {1: 4, 2: 7, 3: 18}                   # Dict[Int, Int]
    var set = {1, 2, 3}                               # Set[Int]
    ```

  - Python-style list, dictionary, and set comprehensions are now supported.
    For example:

    ```mojo
    # Basic list comprehension using a List[String]
    var upper_strs = [str.upper() for str in strs]  # List[String]

    # Nested list comprehension with conditional expression
    var nums = [a * b for a in range(1, 5) if a % 2 == 0 for b in [-1, 1]]  # List[Int]

    # Dictionary comprehension
    var squares_dict = {num: num * num for num in range(10)}  # Dict[Int, Int]

    # Set comprehension
    var unique_remainders = {num % 4 for num in range(10)}  # Set[Int]
    ```

  - The [`BitSet`](/mojo/stdlib/collections/bitset/BitSet) data structure was
    added to the [`collections`](/mojo/stdlib/collections/) package. This is a
    fixed `BitSet` that simplifies working with a set of bits and performing bit
    operations.

  - [`VariadicList`](/mojo/stdlib/builtin/variadics/VariadicList),
    [`VariadicListMem`](/mojo/stdlib/builtin/variadics/VariadicListMem), and
    [`VariadicPack`](/mojo/stdlib/builtin/variadics/VariadicPack) moved to the
    new [`variadics`](/mojo/stdlib/builtin/variadics/) module.

  - The `CollectionElement` trait has been removed. You can replace any use of
    it with `Copyable & Movable`.

Python-Mojo interoperability enhancements and changes:

- Python objects are now constructible with list, set, and dict literal syntax,
  for example: `var list: PythonObject = [1, "foo", 2.0]` will produce a Python
  list containing other Python objects and `var d: PythonObject = {}` will
  construct an empty dictionary.

- `Python.unsafe_get_python_exception()` and
  `Python.throw_python_exception_if_error_state()` have been removed in favor of
  `Python().cpython().unsafe_get_error()` and `Python().cpython().get_error()`.

- Since virtually any operation on a
  [`PythonObject`](/mojo/stdlib/python/python_object/PythonObject) can raise,
  the `PythonObject` struct no longer implements the
  [`Indexer`](/mojo/stdlib/builtin/int/Indexer/) and
  [`Intable`](/mojo/stdlib/builtin/int/Intable/) traits. Instead, it now
  conforms to [`IntableRaising`](/mojo/stdlib/builtin/int/IntableRaising), and
  users should convert explicitly to built-in types and handle exceptions as
  needed. In particular, the
  [`PythonObject.__int__()`](/mojo/stdlib/python/python_object/PythonObject#__int__)
  method now returns a Python `int` instead of a mojo `Int`, so users must
  explicitly convert to a mojo `Int` if they need one (and must handle the
  exception if the conversion fails, for example due to overflow).

- [`PythonObject`](/mojo/stdlib/python/python_object/PythonObject) no longer
  implements the following traits:

  - [`Stringable`](/mojo/stdlib/builtin/str/Stringable/). Instead, the
    [`PythonObject.__str__()`](/mojo/stdlib/python/python_object/PythonObject#__str__)
    method now returns a Python `str` object and can raise. The new
    [`Python.str()`](/mojo/stdlib/python/python/Python#str) static method can
    also be used to convert an arbitrary `PythonObject` to a Python `str`
    object.

  - [`KeyElement`](/mojo/stdlib/collections/dict/#keyelement). Since Python
    objects may not be hashable—and even if they are, they could theoretically
    raise in the
    [`__hash__()`](/mojo/stdlib/python/python_object/PythonObject#__hash__)
    method—`PythonObject` cannot conform to
    [`Hashable`](/mojo/stdlib/hashlib/hash/Hashable/). This has no effect on
    accessing Python `dict` objects with `PythonObject` keys, since
    [`__getitem__()`](/mojo/stdlib/python/python_object/PythonObject#__getitem__)
    and
    [`__setitem__()`](/mojo/stdlib/python/python_object/PythonObject#__setitem__)
    should behave correctly and raise as needed. Two overloads of the
    [`Python.dict()`](/mojo/stdlib/python/python/Python#dict) factory function
    have been added to allow constructing dictionaries from a list of key-value
    tuples and from keyword arguments.

  - [`EqualityComparable`](/mojo/stdlib/builtin/equality_comparable/EqualityComparable/).
    The
    [`PythonObject.__eq__()`](/mojo/stdlib/python/python_object/PythonObject#__eq__)
    and
    [`PythonObject.__ne__()`](/mojo/stdlib/python/python_object/PythonObject#__ne__)
    methods need to return other `PythonObject` values to support rich
    comparisons. Code that previously compared `PythonObject` values should be
    wrapped in [`Bool()`](/mojo/stdlib/builtin/bool/Bool/#__init__) to perform
    the fallible conversion explicitly: `if Bool(obj1 == obj2): ...`.

  - [`Floatable`](/mojo/stdlib/builtin/floatable/Floatable/). An explicit,
    raising constructor is added to
    [`SIMD`](/mojo/stdlib/builtin/simd/SIMD/#__init__) to allow constructing
    `Float64` values from `PythonObject` values that implement `__float__()`.

- A new
  [`def_function()`](/mojo/stdlib/python/bindings/PythonModuleBuilder#def_function)
  API was added to
  [`PythonModuleBuilder`](/mojo/stdlib/python/bindings/PythonModuleBuilder) to
  allow declaring Python bindings for arbitrary functions that take and return
  `PythonObject`s. Similarly, a new
  [`def_method()`](/mojo/stdlib/python/bindings/PythonTypeBuilder#def_method)
  API is added to
  [`PythonTypeBuilder`](/mojo/stdlib/python/bindings/PythonTypeBuilder) to allow
  declaring Python bindings for methods that take and return `PythonObject`s.

- The
  [`ConvertibleFromPython`](/mojo/stdlib/python/python_object/ConvertibleFromPython)
  trait is now public. This trait is implemented by Mojo types that can be
  constructed by converting from a `PythonObject`. This is the reverse operation
  of the
  [`PythonConvertible`](/mojo/stdlib/python/python_object/PythonConvertible)
  trait.

- [`Bool`](/mojo/stdlib/builtin/bool/Bool/),
  [`Int`](/mojo/stdlib/builtin/int/Int/), and
  [`String`](/mojo/stdlib/collections/string/string/String/) now implement
  `ConvertibleFromPython`.

- [`PythonObject(alloc=<value>)`](/mojo/stdlib/python/python_object/PythonObject#__init__)
  is a new constructor that can be used to directly store Mojo values in Python
  objects.

  This initializer will fail if the type of the provided Mojo value has not
  previously had a corresponding Python `type` object globally registered using
  [`PythonModuleBuilder.add_type()`](/mojo/stdlib/python/bindings/PythonModuleBuilder#add_type).

- [`PythonObject`](/mojo/stdlib/python/python_object/PythonObject) has new
  methods for downcasting to a pointer to a contained Mojo value, for use in
  Python/Mojo interop.

  ```mojo
  struct Person:
      var name: String

  fn greet(obj: PythonObject) raises:
    var person = obj.downcast_value_ptr[Person]()

    print("Hello ", person[].name, "from Mojo🔥!")
  ```

  - [`PythonObject.downcast_value_ptr[T]()`](/mojo/stdlib/python/python_object/PythonObject#downcast_value_ptr)
    checks if the object is a wrapped instance of the Mojo type `T`, and if so,
    returns an `UnsafePointer[T]`. Otherwise, an exception is raised.

  - [`PythonObject.unchecked_downcast_value_ptr[T]()`](/mojo/stdlib/python/python_object/PythonObject#unchecked_downcast_value_ptr)
    unconditionally returns an `UnsafePointer[T]` without any runtime type
    checking. This is useful when using Python/Mojo interop to optimize an inner
    loop and minimizing overhead is desirable.

    Also added an equivalent
    [`UnsafePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#__init__)
    initializer for downcasting from a `PythonObject`.

  - The `TypedPythonObject` type has been removed. Use `PythonObject` instead.

  - The `Python.is_type(x, y)` static method has been removed. Use the
    expression `x is y` instead.

- [`os.abort(messages)`](/mojo/stdlib/os/os/abort) no longer supports a
  variadic number of [`Writable`](/mojo/stdlib/utils/write/Writable/) messages.
  While this API was high-level and convenient, it generated a lot of IR for
  simple and common cases, such as when we have a single `StringLiteral`
  message. We now no longer need to generate a bunch of bloated IR and instead,
  callers must create the `String` on their side before calling
  `os.abort(message)`.

- The [`atof()`](/mojo/stdlib/collections/string/string/atof/) function has been
  entirely rewritten as it produced incorrect results for very low and very high
  exponents. It now works correctly for strings with fewer than 19 digits left
  of the `e`. For example `1.1385616158185648648648648648616186186e-3` won't
  work, and will raise an error. Anything that does not produce an error is now
  guaranteed to be correct. While the current implementation is not the fastest,
  it's based on the paper [Number Parsing at a Gigabyte per
  Second](https://arxiv.org/abs/2101.11408) by Daniel Lemire. So with a bit of
  effort to pinpoint the slow parts, we can easily have state of the art
  performance in the future.

- The [`math.isclose()`](/mojo/stdlib/math/math/isclose/) function now supports
  both symmetric (Python-style) and asymmetric (NumPy-style) comparison modes
  via a new `symmetrical` parameter. The parameter defaults to the newly added
  symmetric support. The function now only supports floating-point types,
  removing previous pseudo-support for integer and boolean types. Support added
  in [PR 4608](https://github.com/modular/modular/pull/4608) by
  [@soraros](https://github.com/soraros).

- The [`compile`](/mojo/stdlib/compile/) module now provides the
  [`get_type_name()`](/mojo/stdlib/compile/reflection/get_type_name/) function
  to get the fully qualified name of a type. For example,
  `compile.get_type_name[Int]()` returns `"stdlib.builtin.int.Int"`.

### Tooling changes {#25-4-tooling-changes}

- Added support for emitting LLVM Intermediate Representation (.ll) using
  `--emit=llvm`.
  - Example usage: `mojo build --emit=llvm YourModule.mojo`

- Removed support for the command line option `--emit-llvm` in favor of
  `--emit=llvm`.

- Added support for emitting assembly code (.s) using `--emit=asm`.
  - Example usage: `mojo build --emit=asm YourModule.mojo`

- Added associated alias support for documentation generated via [`mojo
  doc`](/mojo/cli/doc).

- Added struct and trait conformance list sorting support to [`mojo
  format`](/mojo/cli/format).

### ❌ Removed {#25-4-removed}

- `VariadicPack.each()` and `VariadicPack.each_idx()` methods have been removed.
  Use the [`@parameter
  for`](/mojo/manual/decorators/parameter#parametric-for-statement)
  language construct to achieve this now. The `write_buffered()` and
  `write_args()` functions have also been removed, to improve compile speed and
  reduce register pressure on GPU, you should now unroll the variadic pack at
  each call site:

  Unbuffered:

  ```mojo
  fn write[*Ts: Writable](mut self, *args: *Ts):
      var string = String()

      @parameter
      for i in range(args.__len__()):
          args[i].write_to(string)
  ```

  Buffered:

  ```mojo
  from utils.write import _WriteBufferStack

  fn write[*Ts: Writable](mut self, *args: *Ts):
      var string = String()
      var buffer = _WriteBufferStack(string)

      @parameter
      for i in range(args.__len__()):
          args[i].write_to(buffer)

      buffer.flush()
  ```

### 🛠️ Fixed {#25-4-fixed}

- [#1649](https://github.com/modular/modular/issues/1649) - Trailing comma is
  not supported in assignments.
- [#3415](https://github.com/modular/modular/issues/3415) - Type annotation
  fails on implicit variable declarations.
- [#4352](https://github.com/modular/modular/issues/4352) - `math.sqrt`
  products incorrect results for large inputs.
- [#4518](https://github.com/modular/modular/issues/4518) - Try Except Causes
  False Positive "Uninitialized Value".
- [#4677](https://github.com/modular/modular/issues/4677) - `UIntN` Comparison
  Yields Incorrect Result When Function Parameter Is Involved
  (`UInt8`–`UInt64`).
- [#4684](https://github.com/modular/modular/issues/4684) - Failure inferring
  type of initializer list from field of struct.
- [#4688](https://github.com/modular/modular/issues/4668) - Incorrect result for
  unsigned `gt` and `le` comparisons.
- [#4694](https://github.com/modular/modular/issues/4694) - Compiler error
  handling `x or y` expressions with PythonObject.
- [#4719](https://github.com/modular/modular/issues/4719) - `Dict.setdefault`
  should not be marked with `raises`.

### Special thanks

Special thanks to our community contributors:

[@astrobdr](https://github.com/astrobdr),
[@bgreni](https://github.com/bgreni),
[@gabrieldemarmiesse](https://github.com/gabrieldemarmiesse),
[@godardt](https://github.com/godardt),
[@hardikkgupta](https://github.com/hardikkgupta),
[@Hundo1018](https://github.com/Hundo1018),
[@kirillbobyrev](https://github.com/kirillbobyrev),
[@martinvuyk](https://github.com/martinvuyk),
[@msaelices](https://github.com/msaelices),
[@mzaks](https://github.com/mzaks),
[@OwenJRJones](https://github.com/OwenJRJones),
[@shogo314](https://github.com/shogo314),
[@sibarras](https://github.com/sibarras),
[@simveit](https://github.com/simveit),
[@soraros](https://github.com/soraros),
[@sstadick](https://github.com/sstadick)

## v25.3 (2025-05-06)

### ✨ Highlights

- Parts of the Mojo standard library continue to be progressively open sourced!
  Packages that are open sourced now include:

  - [`algorithm`](/mojo/stdlib/algorithm/)
  - [`benchmark`](/mojo/stdlib/benchmark/)
  - [`buffer`](/mojo/stdlib/buffer/)
  - [`compile`](/mojo/stdlib/compile/)
  - [`complex`](/mojo/stdlib/complex/)
  - [`gpu`](/mojo/stdlib/gpu/)
  - [`logger`](/mojo/stdlib/logger/)
  - [`runtime`](/mojo/stdlib/runtime/)
  - [`subprocess`](/mojo/stdlib/subprocess/)

  For more information, see the
  [Standard library reference](/mojo/lib#standard-library) and the
  [Standard library source](https://github.com/modular/modular/tree/main/mojo/stdlib).

- Parts of the MAX AI kernels library continue to be progressively open sourced!
  Packages that are open sourced now include:

  - [`layout`](/mojo/kernels/layout/)
  - [`linalg`](/mojo/kernels/linalg/)

  For more information, see the
  [MAX AI kernels library reference](/mojo/lib#max-ai-kernels-library) and the
  [MAX AI kernels source](https://github.com/modular/modular/tree/main/max/kernels).

- Trait compositions are now supported via the `&` syntax. A trait composition
  combines two traits into one logical trait whose constraint set is the union
  of the constraint sets of the two original traits. For more information, see
  [Trait compositions](/mojo/manual/traits/#trait-compositions) in the Mojo
  Manual.

- String types in Mojo got several significant improvements. See
  [Standard library changes](#25-3-standard-library-changes) for details.

### Language changes {#25-3-language-changes}

- Mojo can now use [user-declared `__merge_with__()` dunder
  methods](https://github.com/modular/modular/blob/main/mojo/proposals/custom-type-merging.md)
  to merge values when using different types in ternary operations. This has
  been adopted to allow pointers to work naturally with the ternary operator,
  for example `var x = one_pointer if cond else other_pointer`.

- Auto-parameterization now extends to struct metatypes. For example, this
  declaration `fn foo[M: __type_of(StringLiteral[_])]` will auto-parameterize
  on the unbound parameter of `StringLiteral`.

- The Mojo compiler now warns about stores to values that are never used, e.g.:
  `x = foo(); x = bar()` will warn about the first assignment to `x` because
  it is overwritten.  You can generally address this by deleting dead code, or
  by assigning to `_` instead: `_ = foo(); x = bar()`.  You may also encounter
  this in variable declarations, e.g. `var x = 0; ...; x = foo()`.  In this
  case, change the variable to being declared as uninitialized, e.g.
  `var x: Int`.  You may also silence this warning entirely for a variable by
  renaming it to start with an underscore, e.g. `_x`.

- The Mojo compiler now warns about obsolete use of `mut self` in initializers,
  please switch over to `fn __init__(out self)` instead.

- `def` functions now require type annotations on arguments, and treat a missing
  return type as returning `None`. Previously these defaulted to the `object`
  type which led to a variety of problems.  Support for `object` has been
  removed until we have time to investigate a proper replacement.

### Standard library changes {#25-3-standard-library-changes}

String types in Mojo got several significant improvements:

- The [`String`](/mojo/stdlib/collections/string/string/String/) type no longer
  copies data from
  [`StringLiteral`](/mojo/stdlib/builtin/string_literal/StringLiteral/) and
  [`StaticString`](/mojo/stdlib/collections/string/string_slice/#aliases) since
  they are known-static-constant values. This allows us to make construction
  from these values be implicit, which improves ergonomics and performance
  together. It also implements the "small string optimization", which avoids
  heap allocation for common short strings. On a 64-bit system, `String` can
  hold up to 23 bytes inline. Its copy constructor is now O(1), performing
  string data copy lazily on mutation.

- The types
  [`StringSlice`(/mojo/stdlib/collections/string/string_slice/StringSlice/) and [`StaticString`](/mojo/stdlib/collections/string/string_slice/#aliases)
  are now part of the prelude, there is no need to import them anymore. These
  are useful for code that just needs a "view" of string data, not to own and
  mutate it.

- The [`StringLiteral`](/mojo/stdlib/builtin/string_literal/StringLiteral/) type
  has been moved to a more reliable "dependent type" design where the value of
  the string is carried in a parameter instead of a stored member. This defines
  away a category of compiler crashes when working with `StringLiteral` that
  involved attempting to manipulate a `StringLiteral` at run time. As a
  consequence of this change, many APIs should switch to using
  [`StaticString`](/mojo/stdlib/collections/string/string_slice/#aliases)
  instead of `StringLiteral`. For more information on this "dependent type"
  design for literals, see the proposal,
  [Fixing Simple Literals in Mojo](https://github.com/modular/modular/blob/main/mojo/proposals/fixing-simple-literals.md).

- `String` supports a new `String(unsafe_uninit_length=x)` constructor and
  `str.resize(unsafe_uninit_length=x)` for clients that want to allocate space
  that they intend to fill in with custom unsafe initialization patterns.  The
  `String(ptr=x, length=y)` constructor has been removed.

- `String` supports working with legacy C APIs that assume null termination,
  but the details have changed: `String` is now no longer implicitly
  null-terminated, which means that it is incorrect to assume that
  `str.unsafe_ptr()` will return a null-terminated string.  For that, use the
  `str.unsafe_cstr_ptr()` method. It now requires the string to be mutable in
  order to make null-termination lazy on demand. This improves performance for
  strings that are not passed to legacy APIs.

- The [`List`](/mojo/stdlib/collections/list/List) type has been improved
  similarly to `String` to reduce inconsistency and enable power-user features,
  including removing adding `List(unsafe_uninit_length=x)` and
  `list.resize(unsafe_uninit_size=n)` methods avoid initialized memory that the
  caller plans to overwrite.

- [`Set`](/mojo/stdlib/collections/set/Set/) now conforms to the
  [`Copyable`](/mojo/stdlib/builtin/value/Copyable/) trait so you can store sets
  in other types of collections (for example, as values in a `Dict`).

- The following traits have been removed in favor of trait composition:
  `EqualityComparableCollectionElement`, `RepresentableCollectionElement`,
  `TestableCollectionElement`, `Testable`, `StringableIdentifiable`,
  `StringableCollectionElement`, `IntervalPayload`, `WritableCollectionElement`,
  `ComparableCollectionElement`, `BoolableCollectionElement`,
  `EqualityComparableWritableCollectionElement`,
  `EqualityComparableWritableCollectionElementNew`, `CollectionElementNew`,
  `WritableCollectionElementNew`.

  For example, you can replace `EqualityComparableCollectionElement` with
  `EqualityComparable & CollectionElement`. `StringableCollectionElement` was
  already deprecated and scheduled to be removed; it can be replaced with
  `Writable & CollectionElement`.

- The [`PythonObject`](/mojo/stdlib/python/python_object/PythonObject) type is
  being reworked in preparation for some improvements to Mojo-Python
  interoperability:

  - Since virtually any operation on a `PythonObject` can raise, the
    `PythonObject` struct no longer implements the following traits:
    `ImplicitlyBoolable`, `ImplicitlyIntable`.

  - `PythonObject` is no longer implicitly constructible from tuple or list
    literals. For example, `var x : PythonObject = [1, 2, "foo"]` is no longer
    accepted. Instead, please use the new `Python.list()` and `Python.tuple()`
    factory methods. For example:

    ```mojo
    var x = Python.list(1, 2, "foo")
    ```

    (The `list()` and `tuple()` factory methods were originally added on
    `PythonObject`, but have been moved to the `Python` struct.)

    We hope to re-enable literal syntax in the future as the standard library
    matures.

  - `PythonObject.from_borrowed_ptr()` has been removed in favor of a
    constructor with a keyword-only `from_borrowed_ptr` argument.

  - The deprecated `PythonObject.to_float64()` method has been removed. Use the
    `Float64()` constructor, instead.

- [`Span`](/mojo/stdlib/memory/span/Span) now has a `swap_elements()` method
  which takes two indices and swaps them within the span.

- [`Pointer`](/mojo/stdlib/memory/pointer/Pointer/) now has a `get_immutable()`
  method to return a new `Pointer` with the same underlying data but with an
  `ImmutableOrigin`.

- You can now forward a
  [`VariadicPack`](/mojo/stdlib/builtin/variadics/VariadicPack/) where all
  values are `Writable` to a writer using
  [`WritableVariadicPack`](/mojo/stdlib/utils/write/WritableVariadicPack/):

  ```mojo
  from utils.write import WritableVariadicPack

  fn print_message[*Ts: Writable](*messages: *Ts):
      print("message:", WritableVariadicPack(messages), "[end]")

  x = 42
  print_message("'x = ", x, "'")
  ```

  ```text
  message: 'x = 42' [end]
  ```

  In this example the variadic pack is buffered to the stack in the `print` call
  along with the extra arguments, before doing a single syscall to write to
  stdout.

- [`debug_assert()`](/mojo/stdlib/builtin/debug_assert/debug_assert/) in AMD GPU
  kernels now behaves the same as on NVIDIA, printing the thread information and
  variadic args passed after the condition:

  ```mojo
  from gpu.host import DeviceContext

  fn kernel():
      var x = 1
      debug_assert(x == 2, "x should be 2 but is: ", x)

  def main():
      with DeviceContext() as ctx:
          ctx.enqueue_function[kernel](grid_dim=2, block_dim=2)
  ```

  Running `mojo run -D ASSERT=all [filename]` will output:

  ```text
  At /tmp/test.mojo:5:17: block: [0,0,0] thread: [0,0,0] Assert Error: x should be 2 but is: 1
  At /tmp/test.mojo:5:17: block: [0,0,0] thread: [1,0,0] Assert Error: x should be 2 but is: 1
  At /tmp/test.mojo:5:17: block: [1,0,0] thread: [0,0,0] Assert Error: x should be 2 but is: 1
  At /tmp/test.mojo:5:17: block: [1,0,0] thread: [1,0,0] Assert Error: x should be 2 but is: 1
  ```

- The
  [`constrained[cond, string]()`](/mojo/stdlib/builtin/constrained/constrained/)
  function now accepts multiple strings that are printed concatenated on
  failure, so you can use:

  ```mojo
  constrained[cond, "hello: ", String(n), ": world"]()
  ```

  This is more compile-time efficient and somewhat more ergonomic than using
  string concatenation.

- [`pathlib.Path.write_text()`](/mojo/stdlib/pathlib/path/Path/#write_text) now
  accepts a `Writable` argument instead of a `Stringable` argument. This makes
  the function more efficient by removing a String allocation.

- Added
  [`pathlib.Path.write_bytes()`](/mojo/stdlib/pathlib/path/Path/#write_bytes)
  which enables writing raw bytes to a file.

- Added
  [`os.path.split_extension()`](/mojo/stdlib/os/path/path/split_extension) to
  split a path into its root and extension.

- Added [`os.path.is_absolute()`](/mojo/stdlib/os/path/path/is_absolute) to
  check if a given path is absolute or not.

- One can now specify the consistency model used in atomic operations with the
  default being sequential consistency. The consistency models are defined in
  the [`Consistency`](/mojo/stdlib/os/atomic/Consistency/) struct.

- Added
  [`Variant.is_type_supported()`](/mojo/stdlib/utils/variant/Variant/#is_type_supported)
  method. ([PR #4057](https://github.com/modular/modular/pull/4057)) Example:

  ```mojo
    def takes_variant(mut arg: Variant):
        if arg.is_type_supported[Float64]():
            arg = Float64(1.5)
    def main():
        var x = Variant[Int, Float64](1)
        takes_variant(x)
        if x.isa[Float64]():
            print(x[Float64]) # 1.5
  ```

- The `type` parameter of `SIMD` has been renamed to `dtype`.

- The `is_power_of_two(x)` function in the `bit` package is now a method on
  `Int`, `UInt` and `SIMD`.

- The `Pointer.address_of(...)` and `UnsafePointer.address_of(...)` functions
  have been deprecated. Please use the
  [`Pointer(to=...)`](/mojo/stdlib/memory/pointer/Pointer#__init__) and
  [`UnsafePointer(to=...)`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#__init__)
  constructors instead. Conceptually, this is saying "please initialize a
  `Pointer` (a reference, if you will) to *some other address in memory*. In the
  future, these `address_of()` functions will be removed.

### Tooling changes {#25-3-tooling-changes}

- Fixed SIMD boolean display in debugger: SIMD boolean values now display
  correctly with proper bit extraction.

- Improved language server performance: The language server now avoids
  parsing more than it needs to, improving performance across the board.

- The Mojo compiler is now able to interpret all arithmetic operations from
  the `index` dialect that are used in methods of `Int` and `UInt` types.
  That allows users to finally compute constants at compile time:

  ```mojo
  alias a: Int = 1000000000
  alias b: Int = (5 * a) // 2
  ```

  Previously, the compiler would throw the error "cannot fold operation".

- Added a new `--emit-llvm` option to the `mojo build` command, which allows
  users to emit LLVM IR. When `--emit-llvm` is specified, the build process
  will: compile mojo code to LLVM IR, save the IR to a .ll file (using the same
  name as the input file), and print the IR to stdout for immediate inspection.

### Other changes

- The syntax for adding attributes to an `__mlir_op` is now limited to inherent
  attributes (those defined by the op definition). Most users will not need to
  attach other kinds of attributes, and this helps guard against typos and mojo
  code getting outdated when the dialect changes.

### ❌ Removed {#25-3-removed}

- The `SIMD.roundeven()` method has been removed from the standard library.
  This functionality is now handled by the
  [`round()`](/mojo/stdlib/builtin/math/round) function.

- Error messages about the obsolete `borrowed` and `inout` keywords, as well as
  the obsolete `-> Int as name` syntax have been removed.

- The `object` type has been removed.

- `utils.numerics.ulp` has been removed. Use the
  [`ulp()`](/mojo/stdlib/math/math/ulp) function from the `math` package
  instead.

- Several free functions that were deprecated in the 25.2 release have now been
  removed.  This includes:

  - The `str` free function. Use the `String` constructor instead.
  - The `int` free function. Use the `Int` constructor instead.
  - The `bool` free function. Use the `Bool` constructor instead.
  - The `float` free function. Use the `Float64` constructor instead.

- Removed deprecated
  [`DeviceContext`](/mojo/stdlib/gpu/host/device_context/DeviceContext/) methods
  `copy_sync()` and `memset_sync()`.

- The `unroll()` utility has been removed. Use the
  [`@parameter for` construct](/mojo/manual/decorators/parameter#parametric-for-statement)
  instead.

  ```mojo
  from utils.loop import unroll

  # Before
  @always_inline
  @parameter
  fn foo[i: Int]():
      body_logic[i]()
  unroll[foo, iteration_range]()

  # After
  @parameter
  for i in range(iteration_range):
      body_logic[i]()
  ```

- The `InlinedString` type has been removed.  Use `String` instead which now
  supports the Small String Optimization (SSO).

- The `AsBytes` trait has been removed.

### 🛠️ Fixed {#25-3-fixed}

- [#3510](https://github.com/modular/modular/issues/3510) - `PythonObject`
  doesn't handle large `UInt64` correctly.

- [#3847](https://github.com/modular/modular/issues/3847) - Count leading zeros
  can't be used on `SIMD` at compile time.

- [#4198](https://github.com/modular/modular/issues/4198) - Apple M4
  is not properly detected with `sys.is_apple_silicon()`.

- [#3662](https://github.com/modular/modular/issues/3662) - Code using
  `llvm.assume` cannot run at compile time.

- [#4273](https://github.com/modular/modular/issues/4273) - `count_leading_zeros`
  doesn't work for vectors with size > 1 at compile time.

- [#4320](https://github.com/modular/modular/issues/4320) - Intermittent
  miscompilation with bytecode imported traits.

- [#4281](https://github.com/modular/modular/issues/4281) - MAX does not support
  RTX 5000-series GPUs.

- [#4163](https://github.com/modular/modular/issues/4163) - Corner case in
  initializers.

- [#4360](https://github.com/modular/modular/issues/4360) - Fix constructor emission
  for parameterized types conforming to a trait composition.

- [#4362](https://github.com/modular/modular/issues/4362) - Function call with
  `IntLiteral` incorrectly eliminated despite side-effects.

- [#4431](https://github.com/modular/modular/issues/4431) - [BUG]
  Python.evaluate doesn't handle null termination correctly.

- [#4492](https://github.com/modular/modular/issues/4488) - Fix `StringSlice.replace`
  seg fault.

### Special thanks

Special thanks to our community contributors:

[@auris](https://github.com/auris),
[@bgreni](https://github.com/bgreni),
[@christianbator](https://github.com/christianbator),
[@KamilGucik](https://github.com/KamilGucik),
[@kasmith11](https://github.com/kasmith11),
[@martinvuyk](https://github.com/martinvuyk),
[@ratulb](https://github.com/ratulb),
[@rd4com](https://github.com/rd4com),
[@sora](https://github.com/sora),
[@thatstoasty](https://github.com/thatstoasty), and
[@winding-lines](https://github.com/winding-lines).

## v25.2 (2025-03-25)

### ✨ Highlights

- Check out the new [GPU basics](/mojo/manual/gpu/basics) section of the [Mojo
  Manual](/mojo/manual) and the [Get started with GPU programming with Mojo and
  the MAX Driver](/mojo/manual/gpu/intro-tutorial) tutorial for a guide to
  getting started with GPU programming in Mojo!

- Some APIs in the [`gpu`](/mojo/stdlib/gpu/) package were enhanced to simplify
  working with GPUs.

  - If you're executing a GPU kernel only once, you can now skip compiling it
    first before enqueueing it, and pass it directly to
    [`DeviceContext.enqueue_function()`](/mojo/stdlib/gpu/host/device_context/DeviceContext#enqueue_function).

  - The three separate methods on `DeviceContext` for asynchronously copying
    buffers between host and GPU memory have been combined to single overloaded
    [`enqueue_copy()`](/mojo/stdlib/gpu/host/device_context/DeviceContext/#enqueue_copy)
    method, and the three separate methods for synchronous copies have been
    combined into an overloaded
    [`copy_sync()`](/mojo/stdlib/gpu/host/device_context/DeviceContext/#copy_sync)
    method.

  - The `gpu.shuffle` module has been renamed to
    [`gpu.warp`](/mojo/stdlib/gpu/warp/) to better reflect its purpose.

  - The [`gpu`](/mojo/stdlib/gpu) package API documentation has been expanded,
    and API documentation for the [`layout`](/mojo/kernels/layout) package is
    underway, beginning with core types, functions, and traits.

  See the [Standard library changes](#25-2-standard-library-changes) section of
  the changelog for more information.

- The legacy `borrowed`/`inout` keywords and `-> T as foo` syntax are no longer
  supported and now generate a compiler error. Please move to `read`/`mut`/`out`
  argument syntax instead. See [Argument
  conventions](/mojo/manual/values/ownership#argument-conventions) in the Mojo
  Manual for more information.

- The standard library has many changes related to strings. Notably, the `Char`
  type has been renamed to
  [`Codepoint`](/mojo/stdlib/collections/string/codepoint/Codepoint), to better
  capture its intended purpose of storing a single Unicode codepoint.
  Additionally, related method and type names have been updated as well. See
  [Standard library changes](#25-2-standard-library-changes) for more details.

- Support has been added for 128- and 256-bit signed and unsigned integers. This
  includes the [`DType`](/mojo/stdlib/builtin/dtype/DType) aliases
  `DType.int128`, `DType.uint128`, `DType.int256`, and `DType.uint256`, as well
  as [`SIMD`](/mojo/stdlib/builtin/simd/SIMD) support for 128- and 256-bit
  signed and unsigned element types. Note that this exposes capabilities (and
  limitations) of LLVM, which may not always provide high performance for these
  types and may have missing operations like divide, remainder, etc. See
  [Standard library changes](#25-2-standard-library-changes) for more details.

### Language changes {#25-2-language-changes}

- References to aliases in struct types with unbound (or partially) bound
  parameters sets are now allowed as long as the referenced alias doesn't
  depend on any unbound parameters:

  ```mojo
  struct StructWithParam[a: Int, b: Int]:
    alias a1 = 42
    alias a2 = a+1

  fn test():
    _ = StructWithParams.a1 # ok
    _ = StructWithParams[1].a2 # ok
    _ = StructWithParams.a2 # error, 'a' is unbound.
  ```

- The Mojo compiler now warns about `@parameter for` with large loop unrolling
  factor (>1024 by default), which can lead to long compilation time and large
  generated code size. Set `--loop-unrolling-warn-threshold` to change default
  value to a different threshold or to `0` to disable the warning.

- The Mojo compile-time interpreter can now handle many more LLVM intrinsics,
  including ones that return floating point values. This allows functions like
  [`round()`](/mojo/stdlib/builtin/math/round) to be constant folded when used
  in a compile-time context.

- The Mojo compiler now has only one compile-time interpreter. It had two
  previously: one to handle a few cases that were important for dependent types
  in the parser (but which also had many limitations), and the primary one that
  ran at "instantiation" time which is fully general. This was confusing and
  caused a wide range of bugs. We've now removed the special case parse-time
  interpreter, replacing it with a more general solution for dependent types.
  This change should be invisible to most users, but should resolve a number of
  long-standing bugs and significantly simplifies the compiler implementation,
  allowing us to move faster.

### Standard library changes {#25-2-standard-library-changes}

- [`Optional`](/mojo/stdlib/collections/optional/Optional),
  [`Span`](/mojo/stdlib/memory/span/Span), and
  [`InlineArray`](/mojo/stdlib/collections/inline_array/InlineArray) have been
  added to the prelude. You now no longer need to explicitly import these types
  to use them in your program.

- GPU programming changes:

  - You can now skip compiling a GPU kernel first before enqueueing it, and pass
    it directly to
    [`DeviceContext.enqueue_function()`](/mojo/stdlib/gpu/host/device_context/DeviceContext#enqueue_function):

    ```mojo
    from gpu.host import DeviceContext

    fn func():
        print("Hello from GPU")

    with DeviceContext() as ctx:
        ctx.enqueue_function[func](grid_dim=1, block_dim=1)
    ```

    However, if you're reusing the same function and parameters multiple times,
    this incurs some overhead of around 50-500 nanoseconds per enqueue. So you
    can still compile the function first with
    [`DeviceContext.compile_function()`](/mojo/stdlib/gpu/host/device_context/DeviceContext#compile_function)
    and pass it to `DeviceContext.enqueue_function()` like this:

    ```mojo
    with DeviceContext() as ctx:
      var compiled_func = ctx.compile_function[func]()
      # Multiple kernel launches with the same function/parameters
      ctx.enqueue_function(compiled_func, grid_dim=1, block_dim=1)
      ctx.enqueue_function(compiled_func, grid_dim=1, block_dim=1)
    ```

  - The following methods on
    [`DeviceContext`](/mojo/stdlib/gpu/host/device_context/DeviceContext):

    - `enqueue_copy_to_device()`
    - `enqueue_copy_from_device()`
    - `enqueue_copy_device_to_device()`

    have been combined to a single overloaded
    [`enqueue_copy()`](/mojo/stdlib/gpu/host/device_context/DeviceContext/#enqueue_copy)
    method. Additionally, the methods:

    - `copy_to_device_sync()`
    - `copy_from_device_sync()`
    - `copy_device_to_device_sync()`

    have been combined into an overloaded
    [`copy_sync()`](/mojo/stdlib/gpu/host/device_context/DeviceContext/#copy_sync)
    method.

  - The `gpu.shuffle` module has been renamed to
    [`gpu.warp`](/mojo/stdlib/gpu/warp/) to better reflect its purpose. For
    example:

    ```mojo
    import gpu.warp as warp

    var val0 = warp.shuffle_down(x, offset)
    var val1 = warp.broadcast(x)
    ```

- Support has been added for 128- and 256-bit signed and unsigned integers.

  - The following aliases have been added to the
    [`DType`](/mojo/stdlib/builtin/dtype/DType) struct: `DType.int128`,
    `DType.uint128`, `DType.int256`, and `DType.uint256`.

  - The [`SIMD`](/mojo/stdlib/builtin/simd/SIMD) type now supports 128- and
    256-bit signed and unsigned element types. Note that this exposes
    capabilities (and limitations) of LLVM, which may not always provide high
    performance for these types and may have missing operations like divide,
    remainder, etc.

  - The following [`Scalar`](/mojo/stdlib/builtin/simd/#aliases) aliases for
    1-element `SIMD` values have been added: `Int128`, `UInt128`, `Int256`, and
    `UInt256`.

- [`String`](/mojo/stdlib/collections/string) and friends:

  - The `Char` type has been renamed to
    [`Codepoint`](/mojo/stdlib/collections/string/codepoint/Codepoint), to
    better capture its intended purpose of storing a single Unicode codepoint.
    Additionally, related method and type names have been updated as well,
    including:

    - `StringSlice.chars()` and `String.chars()` to
      [`StringSlice.codepoints()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#codepoints)
      and
      [`String.codepoints()`](/mojo/stdlib/collections/string/string/String/#codepoints),
      respectively

    - `StringSlice.char_slices()` and `String.char_slices()` to
      [`StringSlice.codepoint_slices()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#codepoint_slices)
      and
      [`String.codepoint_slices()`](/mojo/stdlib/collections/string/string/String/#codepoint_slices),
      respectively

    - `CharsIter` to
      [`CodepointsIter`](/mojo/stdlib/collections/string/string_slice/CodepointsIter)

    - `Char.unsafe_decode_utf8_char()` to
      [`Codepoint.unsafe_decode_utf8_codepoint()`](/mojo/stdlib/collections/string/codepoint/Codepoint/#unsafe_decode_utf8_codepoint)

    - Made the iterator type returned by the string `codepoint_slices()` methods
      public as
      [`CodepointSliceIter`](/mojo/stdlib/collections/string/string_slice/CodepointSliceIter/).

  - [`StringSlice`](/mojo/stdlib/collections/string/string_slice/StringSlice)
    now supports several additional methods moved from
    [`String`](/mojo/stdlib/collections/string/string/String). The existing
    `String` methods have been updated to instead call the corresponding new
    `StringSlice` methods:

    - [`center()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#center)
    - [`is_ascii_digit()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#is_ascii_digit)
    - [`is_ascii_printable()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#is_ascii_printable)
    - [`islower()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#islower)
    - [`isupper()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#isupper)
    - [`ljust()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#ljust)
    - [`lower()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#lower)
    - [`rjust()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#rjust)
    - [`split()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#split)
    - [`upper()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#upper)

  - Added a
    [`StringSlice.is_codepoint_boundary()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#is_codepoint_boundary)
    method for querying if a given byte index is a boundary between encoded
    UTF-8 codepoints.

  - [`StringSlice.__getitem__(Slice)`](/mojo/stdlib/collections/string/string_slice/StringSlice/#__getitem__)
    now raises an error if the provided slice start and end positions do not
    fall on a valid codepoint boundary. This prevents construction of malformed
    `StringSlice` values, which could lead to memory unsafety or undefined
    behavior. For example, given a string containing multi-byte encoded data,
    like:

    ```mojo
    str_slice = "Hi👋!"
    ```

    and whose in-memory and decoded data looks like:

    <table style='border-collapse: collapse;'>
      <colgroup>
        <col style='border: 1px solid black;'/>
        <col style='border: 1px solid black; width: 3em' span='7'/>
      </colgroup>
      <tbody style='text-align: center;'>
          <tr style='border: 1px solid black;'>
              <td style='text-align: left; font-weight: bold;'>String</td>
              <td colspan='7'>Hi👋!</td>
          </tr>
          <tr style='border: 1px solid black;'>
              <td style='text-align: left; font-weight: bold;'>Codepoint Characters</td>
              <td>H</td>
              <td>i</td>
              <td colspan='4'>👋</td>
              <td>!</td>
          </tr>
          <tr style='border: 1px solid black;'>
              <td style='text-align: left; font-weight: bold;'>Codepoints</td>
              <td>72</td>
              <td>105</td>
              <td colspan='4'>128075</td>
              <td>33</td>
          </tr>
          <tr style='border: 1px solid black;'>
              <td style='text-align: left; font-weight: bold;'>Bytes</td>
              <td>72</td>
              <td>105</td>
              <td>240</td>
              <td>159</td>
              <td>145</td>
              <td>139</td>
              <td>33</td>
          </tr>
          <tr style='border: 1px solid black;'>
              <td style='text-align: left; font-weight: bold;'>Index</td>
              <td>0</td>
              <td>1</td>
              <td>2</td>
              <td>3</td>
              <td>4</td>
              <td>5</td>
              <td>6</td>
          </tr>
      </tbody>
    </table>

    attempting to slice bytes `[3-5)` with `str_slice[3:5]` would previously
    erroneously produce a malformed `StringSlice` as output that did not
    correctly decode to anything:

    <table style='border-collapse: collapse;'>
      <colgroup>
        <col style='border: 1px solid black;'/>
        <col style='border: 1px solid black; width: 3em' span='2'/>
      </colgroup>
      <tbody style='text-align: center;'>
          <tr style='border: 1px solid black;'>
              <td style='text-align: left; font-weight: bold;'>String</td>
              <td colspan='2' style='font-style: italic;'>invalid</td>
          </tr>
          <tr style='border: 1px solid black;'>
              <td style='text-align: left; font-weight: bold;'>Codepoint Characters</td>
              <td colspan='2' style='font-style: italic;'>invalid</td>
          </tr>
          <tr style='border: 1px solid black;'>
              <td style='text-align: left; font-weight: bold;'>Codepoints</td>
              <td colspan='2' style='font-style: italic;'>invalid</td>
          </tr>
          <tr style='border: 1px solid black;'>
              <td style='text-align: left; font-weight: bold;'>Bytes</td>
              <td>159</td>
              <td>145</td>
          </tr>
          <tr style='border: 1px solid black;'>
              <td style='text-align: left; font-weight: bold;'>Index</td>
              <td>0</td>
              <td>1</td>
          </tr>
      </tbody>
    </table>

    The same statement will now raise an error informing the user that their
    indices are invalid.

  - The `StringLiteral.get[value]()` method, which converts a compile-time value
    of [`Stringable`](/mojo/stdlib/builtin/str/Stringable) type has been changed
    to a function named
    [`get_string_literal[value]()`](/mojo/stdlib/builtin/string_literal/get_string_literal).

- Collections:

  - A new [`IntervalTree`](/mojo/stdlib/collections/interval/IntervalTree) data
    structure has been added to the standard library. This is a tree data
    structure that allows for efficient range queries.

  - Added an iterator to
    [`LinkedList`](/mojo/stdlib/collections/linked_list/LinkedList) ([PR
    #4005](https://github.com/modular/modular/pull/4005))

    - [`LinkedList.__iter__()`](/mojo/stdlib/collections/linked_list/LinkedList/#__iter__)
      to create a forward iterator.

    - [`LinkedList.__reversed__()`](/mojo/stdlib/collections/linked_list/LinkedList/#__reversed__)
      for a backward iterator.

    ```mojo
    var ll = LinkedList[Int](1, 2, 3)
    for element in ll:
      print(element[])
    ```

  - `List.bytecount()` has been renamed to
    [`List.byte_length()`](/mojo/stdlib/collections/list/List/#byte_length) for
    consistency with the string-like APIs.

  - The
    [`InlineArray(unsafe_uninitialized=True)`](/mojo/stdlib/collections/inline_array/InlineArray/#__init__)
    constructor is now spelled `InlineArray(uninitialized=True)`.

- The design of the [`IntLiteral`](/mojo/stdlib/builtin/int_literal/IntLiteral)
  and [`FloatLiteral`](/mojo/stdlib/builtin/float_literal/FloatLiteral) types
  has been changed to maintain their compile-time-only value as a parameter
  instead of a stored field. This correctly models that infinite precision
  literals are not representable at runtime, and eliminates a number of bugs hit
  in corner cases. This is made possible by enhanced dependent type support in
  the compiler.

- The `Buffer` struct has been removed in favor of
  [`Span`](/mojo/stdlib/memory/span/Span) and
  [`NDBuffer`](/mojo/stdlib/buffer/buffer/NDBuffer).

- The [`round()`](/mojo/stdlib/builtin/math/round) function is now fixed to
  perform "round half to even" (also known as "bankers' rounding") instead of
  "round half away from zero".

- The
  [`UnsafePointer.alloc()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer/#alloc)
  method has changed to produce pointers with an empty `Origin` parameter,
  instead of with `MutableAnyOrigin`. This mitigates an issue with the any
  origin parameter extending the lifetime of unrelated local variables for this
  common method.

- Several more packages are now documented:

  - [`compile`](/mojo/stdlib/compile) package
  - [`gpu`](/mojo/stdlib/gpu) package
  - [`layout`](/mojo/kernels/layout) package is underway, beginning with core
    types, functions, and traits

- Added a new
  [`sys.is_compile_time()`](/mojo/stdlib/sys/compile/is_compile_time) function.
  This enables you to query whether code is being executed at compile time or
  not. For example:

  ```mojo
  from sys import is_compile_time

  fn check_compile_time() -> String:
    if is_compile_time():
        return "compile time"
    else:
        return "runtime"

  def main():
      alias var0 = check_compile_time()
      var var1 = check_compile_time()
      print("var0 is evaluated at ", var0, " , while var1 is evaluated at ", var1)
  ```

  will print `var0 is evaluated at compile time, while var1 is evaluated at
  runtime`.

### Tooling changes {#25-2-tooling-changes}

- Mojo API documentation generation is now able to display function and struct
  parameter references inside nested parametric types using names instead of
  indices. For example, instead of

  ```mojo

  sort[type: CollectionElement, //, cmp_fn: fn($1|0, $1|0) capturing -> Bool](span: Span[type, origin])

  ```

  it now displays

  ```mojo

  sort[type: CollectionElement, //, cmp_fn: fn(type, type) capturing -> Bool](span: Span[type, origin])

  ```

### ❌ Removed

- Use of legacy argument conventions like `inout` and the use of `as` in named
  results now produces an error message instead of a warning.

- Direct access to `List.size` has been removed. Use the public API instead.

  Examples:

  Extending a List:

  ```mojo
  base_data = List[Byte](1, 2, 3)

  data_list = List[Byte](4, 5, 6)
  ext_data_list = base_data.copy()
  ext_data_list.extend(data_list) # [1, 2, 3, 4, 5, 6]

  data_span = Span(List[Byte](4, 5, 6))
  ext_data_span = base_data.copy()
  ext_data_span.extend(data_span) # [1, 2, 3, 4, 5, 6]

  data_vec = SIMD[DType.uint8, 4](4, 5, 6, 7)
  ext_data_vec_full = base_data.copy()
  ext_data_vec_full.extend(data_vec) # [1, 2, 3, 4, 5, 6, 7]

  ext_data_vec_partial = base_data.copy()
  ext_data_vec_partial.extend(data_vec, count=3) # [1, 2, 3, 4, 5, 6]
  ```

  Slicing and extending a list efficiently:

  ```mojo
  base_data = List[Byte](1, 2, 3, 4, 5, 6)
  n4_n5 = Span(base_data)[3:5]
  extra_data = Span(List[Byte](8, 10))
  end_result = List[Byte](capacity=len(n4_n5) + len(extra_data))
  end_result.extend(n4_n5)
  end_result.extend(extra_data) # [4, 5, 8, 10]
  ```

- `InlinedFixedVector` and `InlineList` have been removed. Instead, use
  [`InlineArray`](/mojo/stdlib/collections/inline_array/InlineArray) when the
  upper bound is known at compile time. If the upper bound is not known until
  runtime, use [`List`](/mojo/stdlib/collections/list/List) with the `capacity`
  constructor to minimize allocations.

### 🛠️ Fixed

- [#3976](https://github.com/modular/modular/issues/3976) The `variance`
  argument in [`random.randn_float64()`](/mojo/stdlib/random/random/randn_float64)
  and [`random.randn()`](/mojo/stdlib/random/random/randn) has been renamed to
  `standard_deviation` so that values are drawn from the correct distribution.

### Special thanks

Special thanks to our community contributors:
[@bgreni](https://github.com/bgreni),
[@fnands](https://github.com/fnands),
[@illiasheshyn](https://github.com/illiasheshyn),
[@izo0x90](https://github.com/izo0x90),
[@lydiandy](https://github.com/lydiandy),
[@martinvuyk](https://github.com/martinvuyk),
[@msaelices](https://github.com/msaelices),
[@owenhilyard](https://github.com/owenhilyard),
[@rd4com](https://github.com/rd4com),
[@yinonburgansky](https://github.com/yinonburgansky)

## v25.1 (2025-02-13)

### ✨ Highlights

- The legacy `borrowed`/`inout` keywords and `-> T as foo` syntax are deprecated
  and now generate a compiler warning. Please move to `read`/`mut`/`out`
  argument syntax instead. See
  [Argument conventions](/mojo/manual/values/ownership#argument-conventions)
  in the Mojo Manual for more information.

- The `bool()`, `float()`, `int()`, and `str()` functions are deprecated and
  generate compiler warnings. Please use the `Bool()`, `Float64()`, `Int()`, and
  `String()` constructors instead. See [Standard library
  changes](#25-1-standard-library-changes) for more details.

- The standard library has many changes related to strings. The new
  [`Char`](/mojo/stdlib/collections/string/codepoint/Codepoint) struct
  represents a single Unicode character, and includes several methods for
  categorizing character types. When iterating over the characters of a `String`
  with a `for` loop, you now should use the
  [`String.chars()`](/mojo/stdlib/collections/string/string/String#chars) method
  to provide an iterator of `Char` values or the
  [`String.char_slices()`](/mojo/stdlib/collections/string/string/String#char_slices)
  method to provide an iterator of
  [`StringSlice`](/mojo/stdlib/collections/string/string_slice/StringSlice/)
  instances for each character. `StringRef` has been removed in favor of
  [`StringSlice`](/mojo/stdlib/collections/string/string_slice/StringSlice/).
  And various functionality has moved from `String` and `StringLiteral` to the
  more general `StringSlice` type. See [Standard library
  changes](#25-1-standard-library-changes) for more details.

- You can now use [`SIMD`](/mojo/stdlib/builtin/simd/SIMD) constructors to cast
  existing `SIMD` values (including `Scalar` values) to a different type, though
  you can still use the [`SIMD.cast()`](/mojo/stdlib/builtin/simd/SIMD#cast)
  method to infer the size of the new vector. See [Standard library
  changes](#25-1-standard-library-changes) for more details.

### Language changes {#25-1-language-changes}

- The legacy `borrowed`/`inout` keywords and `-> T as foo` syntax now generate
  a warning. Please move to `read`/`mut`/`out` argument syntax instead. See
  [Argument conventions](/mojo/manual/values/ownership#argument-conventions)
  in the Mojo Manual for more information.

- Initializers are now treated as static methods that return an instance of
  `Self`.  This means the `out` argument of an initializer is now treated the
  same as any other function result or `out` argument. This is generally
  invisible, except that patterns like `instance.__init__()` and
  `x.__copyinit__(y)` no longer work.  Simply replace them with `instance = T()`
  and `x = y` respectively.

- The [`@value`](/mojo/manual/decorators/value) decorator now additionally
  derives an implementation of the
  [`ExplicitlyCopyable`](/mojo/stdlib/builtin/value/ExplicitlyCopyable/) trait.
  This will ease the transition to explicit copyability requirements by default
  in the Mojo collection types.

- Indexing into a homogenous tuple now produces the consistent element type
  without needing a rebind:

  ```mojo
    var x = (1, 2, 3, 3, 4)
    var y : Int = x[idx]     # Just works!
  ```

- You can now overload positional arguments with a keyword-only argument, and
  keyword-only arguments with different names:

  ```mojo
    struct OverloadedKwArgs:
        var val: Int

        fn __init__(out self, single: Int):
            self.val = single

        fn __init__(out self, *, double: Int):
            self.val = double * 2

        fn __init__(out self, *, triple: Int):
            self.val = triple * 3

        fn main():
            OverloadedKwArgs(1)        # val=1
            OverloadedKwArgs(double=1) # val=2
            OverloadedKwArgs(triple=2) # val=6
  ```

  This also works with indexing operations:

  ```mojo
  struct OverloadedKwArgs:
    var vals: List[Int]

    fn __init__(out self):
        self.vals = List[Int](0, 1, 2)

    fn __getitem__(self, idx: Int) -> Int:
        return self.vals[idx]

    fn __getitem__(self, *, idx2: Int) -> Int:
        return self.vals[idx2 * 2]

    fn __setitem__(mut self, idx: Int, val: Int):
        self.vals[idx] = val

    fn __setitem__(mut self, val: Int, *, idx2: Int):
          self.vals[idx2 * 2] = val


  fn main():
      var x = OverloadedKwArgs()
      print(x[1])       # 1
      print(x[idx2=1])  # 2

      x[1] = 42
      x[idx2=1] = 84

      print(x[1])       # 42
      print(x[idx2=1])  # 84
  ```

- The `__disable_del x` operation has been tightened up to treat all fields of
  `x` as consumed by the point of the deletion, so it should be used after all
  the subfields are transferred or otherwise consumed (for example, at the end
  of the function), not before uses of the fields.

### GPU programming {#25-1-gpu-programming}

- The new [`gpu` package](/mojo/stdlib/gpu/) provides low-level programming
  constructs for working with GPUs. The Mojo `gpu` APIs allow you to manually
  manage interaction between the CPU host and GPU device, manage memory between
  devices, synchronize threads, and more. Currently the best way to use these
  APIs is from inside a [MAX custom operation](/max/custom-ops/).

  The following code example shows a GPU kernel written in Mojo:

  ```mojo
  from max.tensor import ManagedTensorSlice
  from gpu import thread_idx, block_dim, block_idx

  fn gpu_add_kernel(out: ManagedTensorSlice, x: ManagedTensorSlice[out.type, out.rank]):
      tid_x = thread_idx.x + block_dim.x * block_idx.x
      tid_y = thread_idx.y + block_dim.y * block_dim.y
      if tid_x < x.dim_size(0) and tid_y < x.dim_size(1):
          out[tid_x, tid_y] = x[tid_x, tid_y] + 1
  ```

  The example above includes only the actual kernel code that’s run on the GPU,
  not the code to define a custom operation or launch the kernel. For more
  complete examples, see
  [`vector_addition.mojo`](https://github.com/modular/modular/blob/main/examples/custom_ops/kernels/vector_addition.mojo)
  and
  [`top_k.mojo`](https://github.com/modular/modular/blob/main/examples/custom_ops/kernels/top_k.mojo).

- The [`layout` package](/mojo/kernels/layout/) includes APIs for working with
  *layouts*, which describe the organization of a tensor (for example, row-major
  or column-major layout), and the
  [`LayoutTensor`](/mojo/kernels/layout/layout_tensor/LayoutTensor) type, which
  represents a tensor with a specified layout. The `layout` package can be used
  to build efficient tensor operations that run on a GPU.

  We’ll continue adding code examples and documentation for the `gpu` and
  `layout` packages in future releases.

### Standard library changes {#25-1-standard-library-changes}

- The builtin functions for converting values to different types have been
  deprecated for actual constructors:

  | **Before** | **After**   |
  | ---------- | ----------- |
  | `bool()`   | `Bool()`    |
  | `float()`  | `Float64()` |
  | `int()`    | `Int()`     |
  | `str()`    | `String()`  |

  These functions were a workaround before Mojo had a way to distinguish between
  implicit and explicit constructors. For this release you'll get a deprecation
  warning, and in the next release they'll become compiler errors. You can
  quickly update your code by doing a `Match Case` and `Match Whole Word`
  search and replace for `int(` to `Int(` etc.

- [`String`](/mojo/stdlib/collections/string/string) and friends:

  - Added [`Char`](/mojo/stdlib/collections/string/codepoint/Codepoint) for
    representing and storing single Unicode characters.

    - `Char` implements
      [`CollectionElement`](/mojo/stdlib/builtin/value/CollectionElement/),
      [`EqualityComparable`](/mojo/stdlib/builtin/equality_comparable/EqualityComparable/),
      [`Intable`](/mojo/stdlib/builtin/int/Intable/), and
      [`Stringable`](/mojo/stdlib/builtin/str/Stringable/).

    - `Char` provides methods for categorizing character types, including:
      [`Char.is_ascii()`](/mojo/stdlib/collections/string/codepoint/Codepoint/#is_ascii),
      [`Char.is_ascii_digit()`](/mojo/stdlib/collections/string/codepoint/Codepoint/#is_ascii_digit),
      [`Char.is_ascii_upper()`](/mojo/stdlib/collections/string/codepoint/Codepoint/#is_ascii_upper),
      [`Char.is_ascii_lower()`](/mojo/stdlib/collections/string/codepoint/Codepoint/#is_ascii_lower),
      [`Char.is_ascii_printable()`](/mojo/stdlib/collections/string/codepoint/Codepoint/#is_ascii_printable),
      [`Char.is_posix_space()`](/mojo/stdlib/collections/string/codepoint/Codepoint/#is_posix_space),
      [`Char.is_python_space()`](/mojo/stdlib/collections/string/codepoint/Codepoint/#is_python_space).

    - Added a `String()` constructor from `Char`.

    - `Char` can be converted to `UInt32` via
      [`Char.to_u32()`](/mojo/stdlib/collections/string/codepoint/Codepoint/#to_u32).

    - [`chr()`](/mojo/stdlib/collections/string/string/chr/) will now abort if
      given a codepoint value that is not a valid `Char`.

  - `StringRef` has been removed in favor of
    [`StringSlice`](/mojo/stdlib/collections/string/string_slice/StringSlice/).
    The two types are ABI compatible, and for the exact same behavior one can
    use `StaticString`, which is an alias to
    `StringSlice[StaticConstantOrigin]`.

  - Various functionality has moved from `String` and `StringLiteral` to the
    more general `StringSlice` type.

  - Added
    [`StringSlice.from_utf8()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#from_utf8)
    factory method, for validated construction of a `StringSlice` from a buffer
    containing UTF-8 encoded data. This method will raise if the buffer contents
    are not valid UTF-8.

  - Added
    [`StringSlice.chars()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#chars)
    which returns an iterator over `Char`s. This is a compliant UTF-8 decoder
    that returns each Unicode codepoint encoded in the string.

  - Added
    [`StringSlice.__getitem__(Slice)`](/mojo/stdlib/collections/string/string_slice/StringSlice/#__getitem__)
    which returns a substring. Only step sizes of 1 are supported.

  - Several standard library functions have been changed to take `StringSlice`
    instead of `String`. This generalizes them to be used for any appropriately
    encoded string in memory, without requiring that the string be heap
    allocated. This includes:
    [`ascii()`](/mojo/stdlib/collections/string/string/ascii),
    [`atol()`](/mojo/stdlib/collections/string/string/atol),
    [`atof()`](/mojo/stdlib/collections/string/string/atof),
    [`b16decode()`](/mojo/stdlib/base64/base64/b16decode),
    [`b16encode()`](/mojo/stdlib/base64/base64/b16encode),
    [`b64decode()`](/mojo/stdlib/base64/base64/b64decode),
    [`b64encode()`](/mojo/stdlib/base64/base64/b64encode), and
    [`ord()`](/mojo/stdlib/collections/string/string/ord).

  - Added new
    [`String.chars()`](/mojo/stdlib/collections/string/string/String/#chars) and
    [`String.char_slices()`](/mojo/stdlib/collections/string/string/String/#char_slices)
    iterator methods, and deprecated the existing `String.__iter__()` method.

    Different use-cases may prefer iterating over the `Char`s encoded in a
    string, or iterating over subslices containing single characters. Neither
    iteration semantics is an obvious default, so the existing `__iter__()`
    method has been deprecated in favor of writing explicit iteration methods
    for the time being.

    Code of the form:

    ```mojo
    var s: String  = ...
    for c in s:
        # ...
    ```

    can be migrated to using the `.char_slices()` method:

    ```mojo
    var s: String = ...
    for c in s.char_slices():
        # ...
    ```

  - Added
    [`StringSlice.char_length()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#char_length)
    method, to pair with the existing
    [`StringSlice.byte_length()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#byte_length)
    method.

  - The
    [`String.__len__()`](/mojo/stdlib/collections/string/string/String/#__len__)
    and
    [`StringSlice.__len__()`](/mojo/stdlib/collections/string/string_slice/StringSlice/#__len__)
    methods now return the length of the string in bytes.

    Previously, these methods were documented to note that they would eventually
    return a length in Unicode codepoints. They have been changed to guarantee
    a length in bytes, since the length in bytes is how they are most often used
    today (for example, as bounds to low-level memory manipulation logic).
    Additionally, length in codepoints is a more specialized notion of string
    length that is rarely the correct metric.

    Users that know they need the length in codepoints can use the
    `str.char_length()` method, or `len(str.chars())`.

  - `StringSlice` now implements
    [`Representable`](/mojo/stdlib/builtin/repr/Representable/), and that
    implementation is now used by `String.__repr__()` and
    `StringLiteral.__repr__()`.

  - `StringSlice` now implements
    [`EqualityComparable`](/mojo/stdlib/builtin/equality_comparable/EqualityComparable/).

    Up until now, `StringSlice` has implemented a more general `__eq__()` and
    `__ne__()` comparison with `StringSlice` types that had arbitrary other
    origins. However, to satisfy `EqualityComparable`, `StringSlice` now also
    has narrower comparison methods that support comparing only with another
    `StringSlice` with the exact same origin.

  - The `String.write()` static method has moved to a `String()` constructor,
    and is now buffered. Instead of doing:

    ```mojo
    var msg = "my message " + String(x) + " " + String(y) + " " + String(z)
    ```

    Which reallocates the `String` you should do:

    ```mojo
    var msg = String("my message", x, y, z, sep=" ")
    ```

    Which is cleaner, and buffers to the stack so the `String` is allocated only
    once.

  - You can now pass any [`Writer`](/mojo/stdlib/utils/write/Writer/) to
    [`write_buffered()`](/mojo/stdlib/utils/write/write_buffered/):

    ```mojo
    from utils.write import write_buffered

    var string = String("existing string")
    write_buffered(string, 42, 42.4, True, sep=" ")
    ```

    This writes to a buffer on the stack before reallocating the `String`.

- Collections:

  - A new [`LinkedList`](/mojo/stdlib/collections/linked_list/LinkedList/) type
    has been added to the standard library.

  - Added
    [`Optional.copied()`](/mojo/stdlib/collections/optional/Optional#copied) for
    constructing an owned `Optional[T]` from an `Optional[Pointer[T]]` by
    copying the pointee value.

  - Added [`Dict.get_ptr()`](/mojo/stdlib/collections/dict/Dict#get_ptr) which
    returns an `Optional[Pointer[V]]`. If the given key is present in the
    dictionary, the optional will hold a pointer to the value. Otherwise, an
    empty optional is returned.

  - Added new [`List.extend()`](/mojo/stdlib/collections/list/List#extend)
    overloads taking [`SIMD`](/mojo/stdlib/builtin/simd/SIMD) and
    [`Span`](/mojo/stdlib/memory/span/Span/). These enable growing a
    `List[Scalar[..]]` by copying the elements of a `SIMD` vector or
    `Span[Scalar[..]]`, simplifying the writing of some optimized SIMD-aware
    functionality.

- [`UnsafePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer/) changes:

  - `UnsafePointer`'s `bitcast()` method has now been split into
    [`bitcast()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#bitcast) for
    changing the type,
    [`origin_cast()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#origin_cast)
    for changing mutability,
    [`static_alignment_cast()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#static_alignment_cast)
    for changing alignment, and
    [`address_space_cast()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#address_space_cast)
    for changing the address space.

  - `UnsafePointer` is now parameterized on mutability. Previously,
    `UnsafePointer` could only represent mutable pointers.

    The new `mut` parameter can be used to restrict an `UnsafePointer` to a
    specific mutability: `UnsafePointer[T, mut=False]` represents a pointer to
    an immutable `T` value. This is analogous to a `const *` pointer in C++.

  - [`UnsafePointer.address_of()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#address_of)
    will now infer the origin and mutability of the resulting pointer from the
    argument. For example:

    ```mojo
    var local = 10
    # Constructs a mutable pointer, because `local` is a mutable memory location
    var ptr = UnsafePointer.address_of(local)
    ```

    To force the construction of an immutable pointer to an otherwise mutable
    memory location, use a cast:

    ```mojo
    var local = 10
    # Cast the mutable pointer to be immutable.
    var ptr = UnsafePointer.address_of(local).origin_cast[mut=False]()
    ```

  - The `unsafe_ptr()` method on several standard library collection types have
    been updated to use parametric mutability: they will return an
    `UnsafePointer` whose mutability is inherited from the mutability of the
    `ref self` of the receiver at the call site. For example, `ptr1` will be
    immutable, while `ptr2` will be mutable:

    ```mojo
    fn take_lists(read list1: List[Int], mut list2: List[Int]):
        # Immutable pointer, since receiver is immutable `read` reference
        var ptr1 = list1.unsafe_ptr()

        # Mutable pointer, since receiver is mutable `mut` reference
        var ptr2 = list2.unsafe_ptr()
    ```

- New and updated traits:

  - The [`ExplicitlyCopyable`](/mojo/stdlib/builtin/value/ExplicitlyCopyable/)
    trait has changed to require a `fn copy(self) -> Self` method. Previously,
    an initializer with the signature `fn __init__(out self, *, other: Self)`
    had been required by `ExplicitlyCopyable`.

    This improves the "greppability" and at-a-glance readability when a
    programmer is looking for places in their code that may be performing
    copies.

  - The `IntLike` trait has been removed and its functionality incorporated into
    the [`Indexer`](/mojo/stdlib/builtin/int/Indexer/) trait. This enables
    `SIMD` scalar integer types and `UInt` to be used for indexing into all of
    the collection types, as well as optimizing away normalization checks for
    `UInt` indexing.

  - The [`ImplicitlyIntable`](/mojo/stdlib/builtin/int/ImplicitlyIntable/) trait
    has been added, allowing types to be implicitly converted to an `Int` by
    implementing the `__as_int__()` method:

    ```mojo
    @value
    struct Foo(ImplicitlyIntable):
        var i: Int

        fn __as_int__(self) -> Int:
            return self.i
    ```

- You can now cast `SIMD` types using constructors:

  ```mojo
  var val = Int8(42)
  var cast = Int32(val)
  ```

  It also works when passing a scalar type to larger vector size:

  ```mojo
  var vector = SIMD[DType.int64, 4](cast) # [42, 42, 42, 42]
  ```

  For values other than scalars the size of the `SIMD` vector needs to be equal:

  ```mojo
  var float_vector = SIMD[DType.float64, 4](vector)
  ```

  [`SIMD.cast()`](/mojo/stdlib/builtin/simd/SIMD#cast) still exists to infer the
  size of new vector:

  ```mojo
  var inferred_size = float_vector.cast[DType.uint64]() # [42, 42, 42, 42]
  ```

- Added [`SIMD.from_bytes()`](/mojo/stdlib/builtin/simd/SIMD/#from_bytes) and
  [`SIMD.as_bytes()`](/mojo/stdlib/builtin/simd/SIMD/#as_bytes) to convert a
  list of bytes to a list of scalars and vice versa, accepting the endianness as
  an argument. Similar to Python `int.from_bytes()` and `int.to_bytes()`
  functions.

- You can now use [`max()`](/mojo/stdlib/builtin/math/max) and
  [`min()`](/mojo/stdlib/builtin/math/min) with variadic number of arguments.

- `bit_ceil()` has been renamed to
  [`next_power_of_two()`](/mojo/stdlib/bit/bit/next_power_of_two), and
  `bit_floor()` to
  [`prev_power_of_two()`](/mojo/stdlib/bit/bit/prev_power_of_two). This is to
  improve readability and clarity in their use.

- Added a new boolean `validate` parameter to
  [`b64decode()`](/mojo/stdlib/base64/base64/b64decode).

- The [`b64encode()`](/mojo/stdlib/base64/base64/b64encode) overload that
  previously took a `List` has been changed to take a
  [`Span`](/mojo/stdlib/memory/span/Span/).

- Removed the `@implicit` decorator from some standard library initializer
  methods that perform allocation. This reduces places where Mojo code could
  implicitly allocate where the user may not be aware.

  Removed `@implicit` from:

  - `String.__init__(out self, StringSlice)`
  - `List.__init__(out self, owned *values: T)`
  - `List.__init__(out self, span: Span[T])`

- Added more aliases in [`sys.ffi`](/mojo/stdlib/sys/ffi/) to round out the
  usual needs for FFI bindings.

### Tooling changes {#25-1-tooling-changes}

- `mblack` (aka [`mojo format`](/mojo/cli/format)) no longer formats non-Mojo
  files. This prevents unexpected formatting of Python files.

- Full struct signature information is now exposed in the documentation
  generator, and in the symbol outline and hover markdown via the Mojo Language
  Server.

- The [`env_get_dtype()`](/mojo/stdlib/sys/param_env/env_get_dtype) function has
  been added to the [`sys.param_env`](/mojo/stdlib/sys/param_env/) module. This
  allows you to get the value of a `DType` from the param environment.

### ❌ Removed

- `StringRef` has been removed. Use
  [`StringSlice`](/mojo/stdlib/collections/string/string_slice/StringSlice/)
  instead.

  - Changed [`sys.argv()`](/mojo/stdlib/sys/arg/argv) to return list of
    `StringSlice`.

  - Added explicit [`Path()`](/mojo/stdlib/pathlib/path/Path/#__init__)
    constructor from `StringSlice`.

- The `Tuple.get[i, T]()` method has been removed. Please use `tup[i]` or
  `rebind[T](tup[i])` as needed instead.

- `StringableCollectionElement` is deprecated. Use
  [`WritableCollectionElement`](/mojo/stdlib/builtin/value/WritableCollectionElement/)
  instead, which still allows you to construct a `String`, but can avoid
  intermediate allocations.

- The `IntLike` trait has been removed and its functionality incorporated into
  the [`Indexer`](/mojo/stdlib/builtin/int/Indexer/) trait.

- The `Type{field1: 42, field2: 17}` syntax for direct initializing register
  passable types has been removed. This was legacy syntax - to upgrade your
  code, add the [`@value`](/mojo/manual/decorators/value) decorator to your
  struct to get a fieldwise initializer and use `Type(field1=42, field2 = 17)`
  instead.

### 🛠️ Fixed

- The Mojo Kernel for Jupyter Notebooks is working again on nightly releases.

- The command `mojo debug --vscode` now sets the current working directory
  properly.

- [Issue #3796](https://github.com/modular/modular/issues/3796) - Compiler crash
  handling `for`-`else` statement.

- [Issue #3540](https://github.com/modular/modular/issues/3540) - Using named
  output slot breaks trait conformance

- [Issue #3617](https://github.com/modular/modular/issues/3617) - Can't generate
  the constructors for a type wrapping `!lit.ref`

- The Mojo Language Server doesn't crash anymore on empty `__init__.mojo` files.
  [Issue #3826](https://github.com/modular/modular/issues/3826).

- [Issue #3935](https://github.com/modular/modular/issues/3935) - Confusing OOM
   error when using `Tuple.get()` incorrectly.

- [Issue #3955](https://github.com/modular/modular/issues/3955) - Unexpected
  copy behavior with `def` arguments in loops

- [Issue #3960](https://github.com/modular/modular/issues/3960) - Infinite `for`
  loop

## v24.6 (2024-12-17)

### ✨ Highlights

Here's a brief summary of some of the major changes in this release, with more
detailed information in the following sections:

- The `inout` and `borrowed` argument conventions have been renamed to `mut`
  and `read`, respectively. A new `out` convention has been added for the `self`
  argument in constructors and for named results. See
  [Language changes](#24-6-language-changes) for details.

- `Lifetime` and related types in the standard library have been renamed to
  [`Origin`](/mojo/stdlib/builtin/type_aliases/Origin) to better clarify that
  parameters of this type indicate where a reference is derived from, not the
  more complicated notion of where a variable is initialized and destroyed. As a
  consequence the `__lifetime_of()` operator is now named `__origin_of()`.

  There are also a number of other origin-related improvements in this release,
  including being able to specify a union of origins by listing multiple values
  in the `__origin_of()` operator or inside the `ref` origin specifier
  (`ref [a, b]`). For details, see [Language changes](#24-6-language-changes).

  For background information and rationale on the name change see
  [the proposal](https://github.com/modular/modular/issues/3623). For more
  information on origins, see
  [Lifetimes, origins and references](/mojo/manual/values/lifetimes) in the Mojo
  Manual.

- Implicit conversions are now opt-in using the
  [`@implicit`](/mojo/manual/decorators/implicit) decorator. See
  [Language changes](#24-6-language-changes) for details.

- The standard library has added several new types, including
  [`Deque`](/mojo/stdlib/collections/deque/Deque) (a double-ended queue) and
  [`OwnedPointer`](/mojo/stdlib/memory/owned_pointer/OwnedPointer) (safe,
  single-owner, non-nullable smart pointer). See
  [Standard library changes](#24-6-standard-library-changes)
  for details.

- The VS Code extension now supports setting data breakpoints and function
  breakpoints, and the Mojo LLDB debugger supports symbol breakpoints, such
  as `b main` or `b my_module::main`.

- We've made a number of improvement to how information is displayed in error
  messages, LSP, and generated API documentation. For details, see
  [Tooling changes](#24-6-tooling-changes).

- And we've added a number of new docs, including a brand new
  [Mojo tutorial](/mojo/manual/get-started), new pages on
  [operators and expressions](/mojo/manual/operators),
  [error handling](/mojo/manual/errors), and
  [pointers](/mojo/manual/pointers/), and many smaller additions and
  improvements.

### Language changes {#24-6-language-changes}

- Argument convention changes:

  - The `inout` and `borrowed` argument conventions have been renamed to `mut`
    (for "mutate") and `read`, respectively. These verbs reflect what the callee
    can do to the argument value passed in by the caller, without requiring the
    programmer to know about advanced features like references.

    For information on Mojo's argument conventions, see
    [Argument conventions](/mojo/manual/values/ownership/#argument-conventions)
    in the Mojo Manual.

  - The argument convention for the `self` argument in the `__init__()`,
    `__copyinit__()`, and `__moveinit__()` methods has been changed from `inout`
    to `out`, reflecting that a constructor method initializes its `self` value
    without reading from it. This also enables spelling the type of an
    initializer correctly, which was not supported before:

    ```mojo
    struct Foo:
        fn __init__(out self): pass

    fn test():
        # This works now
        var fnPtr : fn(out x: Foo)->None = Foo.__init__

        var someFoo : Foo
        fnPtr(someFoo)  # initializes someFoo.
    ```

    The previous `fn __init__(inout self)` syntax is still supported in this
    release of Mojo, but will be removed in the future.  Please migrate to the
    new syntax.

  - Similarly, the spelling of named results has switched to use
    `out` syntax instead of `-> T as name`. Functions may have at most one named
    result or return type specified with the usual `->` syntax. `out` arguments
    may occur anywhere in the argument list, but are typically last (except for
    `__init__` methods, where they are typically first).

    ```mojo
    # This function has type "fn() -> String"
    fn example(out result: String):
      result = "foo"
    ```

    The parser still accepts the old syntax as a synonym for this, but that will
    eventually be deprecated and removed.

    This was [discussed extensively in a public
    proposal](https://github.com/modular/modular/issues/3623). For more
    information, see
    [Named results](/nightly/mojo/manual/functions#named-results) in the Mojo
    Manual.

- Single argument constructors now require the
  [`@implicit`](/mojo/manual/decorators/implicit) decorator to allow for
  implicit conversions. Previously you could define an `__init__` that takes a
  single argument:

  ```mojo
  struct Foo:
      var value: Int

      fn __init__(out self, value: Int):
          self.value = value
  ```

  And this would allow you to pass an `Int` in the position of a `Foo`:

  ```mojo
  fn func(foo: Foo):
      print("implicitly converted Int to Foo:", foo.value)

  fn main():
      func(Int(42))
  ```

  This can result in complicated errors that are difficult to debug. By default
  this implicit behavior is now turned off, so you have to explicitly construct
  `Foo`:

  ```mojo
  fn main():
      func(Foo(42))
  ```

  You can still opt into implicit conversions by adding the `@implicit`
  decorator. For example, to enable implicit conversions from `Int` to `Foo`:

  ```mojo
  struct Foo:
      var value: Int

      @implicit
      fn __init__(out self, value: Int):
          self.value = value
  ```

  For more information see [Constructors and implicit
  conversion](/mojo/manual/lifecycle/life#constructors-and-implicit-conversion)
  in the Mojo Manual.

- Origin-related changes:

  - The `AnyLifetime` type (useful for declaring origin types as parameters) has
    has been renamed to [`Origin`](/mojo/stdlib/builtin/type_aliases/Origin) and
    the `__lifetime_of()` operator renamed to `__origin_of()`.

  - `Origin` is now a complete wrapper around the MLIR origin type.

    - The `Origin.type` alias has been renamed to `_mlir_origin`. In parameter
      lists, you can now write just `Origin[..]`, instead of `Origin[..].type`.

    - `ImmutableOrigin` and `MutableOrigin` are now, respectively, just aliases
      for `Origin[False]` and `Origin[True]`.

    - `Origin` struct values are now supported in the origin specifier of a
      `ref [..]` argument.

    - Added `Origin.cast_from` for casting the mutability of an origin value.

  - `ref` arguments and results now allow for providing a memory value
    directly in the origin specifier, rather than requiring the use of
    `__origin_of()`.  It is still fine to use `__origin_of()` explicitly though,
    and this is required when specifying origins for parameters (e.g. to the
    `Pointer` type). For example, this is now valid without `__origin_of()`:

    ```mojo
    fn return_ref(a: String) -> ref [a] String:
        return a
    ```

  - Various improvements to origin handling and syntax have landed, including
    support for the ternary operator and allowing multiple arguments in a `ref`
    specifier (which are implicitly unions).  This enables expression of simple
    algorithms cleanly:

    ```mojo
    fn my_min[T: Comparable](ref a: T, ref b: T) -> ref [a, b] T:
      return a if a < b else b
    ```

    It is also nice that `my_min` automatically and implicitly propagates the
    mutability of its arguments, so things like `my_min(str1, str2) += "foo"` is
    valid.

  - `ref` function arguments without an origin clause are now treated as
    `ref [_]`, which is more syntactically convenient and consistent:

    ```mojo
    fn takes_and_return_ref(ref a: String) -> ref [a] String:
        return a
    ```

  - The `__type_of(x)` and `__origin_of(x)` operators are much more general now:
    they allow arbitrary expressions inside of them, allow referring to dynamic
    values in parameter contexts, and even allow referring to raising functions
    in non-raising contexts. These operations never evaluate their expression,
    so any side effects that occur in the expression are never evaluated at
    runtime, eliminating concerns about `__type_of(expensive())` being a
    problem.

  - The destructor insertion logic in Mojo is now aware that types that take an
    `MutableAnyOrigin` or `ImmutableAnyOrigin` as part of their signature could
    potentially access any live value that destructor insertion is tracking,
    eliminating a significant usability issue with unsafe APIs like
    [`UnsafePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer).
    Consider a typical example working with strings before this change:

    ```mojo
    var str = String(...)
    var ptr = str.unsafe_ptr()
    some_low_level_api(ptr)
    _ = str^  # OLD HACK: Explicitly keep string alive until here!
    ```

    The `_ = str^` pattern was formerly required because the Mojo compiler has
    no idea what "ptr" might reference. As a consequence, it had no idea that
    `some_low_level_api()` might access `str` and therefore thought it was ok to
    destroy the `String` before the call - this is why the explicit lifetime
    extension was required.

    Mojo now knows that
    [`UnsafePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer) may
    access the `MutableAnyOrigin` origin, and now assumes that any API that uses
    that origin could use live values. In this case, it assumes that
    `some_low_level_api()` might access `str` and because it might be using it,
    it cannot destroy `str` until after the call. The consequence of this is
    that the old hack is no longer needed for these cases!

  - Function types now accept an origin set parameter. This parameter represents
    the origins of values captured by a parameter closure. The compiler
    automatically tags parameter closures with the right set of origins. This
    enables lifetimes and parameter closures to correctly compose.

    ```mojo
    fn call_it[f: fn() capturing [_] -> None]():
        f()

    fn test():
        var msg = String("hello world")

        @parameter
        fn say_hi():
            print(msg)

        call_it[say_hi]()
        # no longer need to write `_ = msg^`!!
    ```

    Note that this only works for higher-order functions which have explicitly
    added `[_]` as the capture origins. By default, the compiler still assumes
    a `capturing` closure does not reference any origins. This will soon change.

- Infer-only parameters may now be explicitly bound with keywords, enabling
  some important patterns in the standard library:

  ```mojo
  struct StringSlice[is_mutable: Bool, //, origin: Origin[is_mutable]]: ...
  alias ImmStringSlice = StringSlice[is_mutable=False]
  # This auto-parameterizes on the origin, but constrains it to being an
  # immutable slice instead of a potentially mutable one.
  fn take_imm_slice(a: ImmStringSlice): ...
  ```

- The flag for turning on asserts has changed, e.g. to enable all checks:

  ```bash
  mojo -D ASSERT=all main.mojo
  ```

  The levels are:

  - `none`: all assertions off
  - `warn`: print assertion errors e.g. for multithreaded tests (previously `-D
    ASSERT_WARNING`)
  - `safe`: the default mode for standard CPU safety assertions
  - `all`: turn on all assertions (previously `-D MOJO_ENABLE_ASSERTIONS`)

  You can now also pass `Stringable` args to format a message, which will have
  no runtime penalty or IR bloat cost when assertions are off. Previously you
  had to:

  ```mojo
  x = -1
  debug_assert(
    x > 0, String.format_sequence(“expected x to be more than 0 but got: ”, x)
  )
  ```

  Which can't be optimized away by the compiler in release builds, you can now
  pass multiple args for a formatted message at no runtime cost:

  ```mojo
  debug_assert(x > 0, “expected x to be more than 0 but got: ”, x)
  ```

- Automatic parameterization of parameters is now supported. Specifying a
  parameterized type with unbound parameters causes them to be implicitly added
  to the function signature as infer-only parameters.

  ```mojo
  fn foo[value: SIMD[DType.int32, _]]():
    pass

  # Equivalent to
  fn foo[size: Int, //, value: SIMD[DType.int32, size]]():
    pass
  ```

- Mojo can now interpret simple LLVM intrinsics in parameter expressions,
  enabling things like `count_leading_zeros` to work at compile time:
  [Issue #933](https://github.com/modular/modular/issues/933).

- Introduced the `@explicit_destroy` annotation, the `__disable_del` keyword,
  the `UnknownDestructibility` trait, and the `ImplicitlyDestructible` keyword,
  for the experimental explicitly destroyed types feature.

- Added associated types; we can now have aliases like `alias T: AnyType`,
  `alias N: Int`, etc. in a trait, and then specify them in structs that conform
  to that trait. For more information, see [Associated aliases for
  generics](/mojo/manual/traits#associated-aliases-for-generics).

### Standard library changes {#24-6-standard-library-changes}

- Introduced a new [`Deque`](/mojo/stdlib/collections/deque/Deque) (double-ended
  queue) collection type, based on a dynamically resizing circular buffer for
  efficient O(1) additions and removals at both ends as well as O(1) direct
  access to all elements.

  The `Deque` supports the full Python `collections.deque` API, ensuring that
  all expected deque operations perform as in Python.

  Enhancements to the standard Python API include `peek()` and `peekleft()`
  methods for non-destructive access to the last and first elements, and
  advanced constructor options (`capacity`, `min_capacity`, and `shrink`) for
  customizing memory allocation and performance. These options allow for
  optimized memory usage and reduced buffer reallocations, providing flexibility
  based on application requirements.

- The `Formatter` struct has been replaced with a
  [`Writer`](/mojo/stdlib/utils/write/Writer) trait to enable buffered IO,
  increasing print and file writing perf to the same speed as C. It's now more
  general purpose and can write any `Span[Byte]`. To align with this the
  `Formattable` trait is now named
  [`Writable`](/mojo/stdlib/utils/write/Writable), and the
  `String.format_sequence()` static method to initialize a new `String` has been
  renamed to
  [`String.write()`](/mojo/stdlib/collections/string/string/String/#write).
  Here's an example of using all of the changes:

  ```mojo
  from memory import Span

  @value
  struct NewString(Writer, Writable):
      var s: String

      # Writer requirement to write a Span of Bytes
      fn write_bytes(inout self, bytes: Span[Byte, _]):
          self.s._iadd[False](bytes)

      # Writer requirement to take multiple args
      fn write[*Ts: Writable](inout self, *args: *Ts):
          @parameter
          fn write_arg[T: Writable](arg: T):
              arg.write_to(self)

          args.each[write_arg]()

      # Also make it Writable to allow `print` to write the inner String
      fn write_to[W: Writer](self, inout writer: W):
          writer.write(self.s)


  @value
  struct Point(Writable):
      var x: Int
      var y: Int

      # Pass multiple args to the Writer. The Int and StringLiteral types call
      # `writer.write_bytes` in their own `write_to` implementations.
      fn write_to[W: Writer](self, inout writer: W):
          writer.write("Point(", self.x, ", ", self.y, ")")

      # Enable conversion to a String using `str(point)`
      fn __str__(self) -> String:
          return String.write(self)


  fn main():
      var point = Point(1, 2)
      var new_string = NewString(str(point))
      new_string.write("\n", Point(3, 4))
      print(new_string)
  ```

  ```output
  Point(1, 2)
  Point(3, 4)
  ```

- The `TypeIdentifiable` trait has been removed in favor of the new
  `get_type_name` utility in the `compile.reflection` module.

- Python interop changes:

  - Introduced
    `TypedPythonObject`
    as a light-weight way to annotate
    [`PythonObject`](/mojo/stdlib/python/python_object/PythonObject) values with
    static type information. This design will likely evolve and change
    significantly.

    - Added `TypedPythonObject[Tuple].__getitem__()` for accessing the elements
      of a Python tuple.

  - Added
    [`Python.add_object()`](/mojo/stdlib/python/python/Python#add_object), to
    add a named `PythonObject` value to a Python 'module' object instance.

  - Added
    [`Python.unsafe_get_python_exception()`](/mojo/stdlib/python/python/Python#unsafe_get_python_exception),
    as an efficient low-level utility to get the Mojo `Error` equivalent of the
    current CPython error state.

  - Add
    [`PythonObject.from_borrowed_ptr()`](/mojo/stdlib/python/python_object/PythonObject#from_borrowed_ptr),
    to simplify the construction of `PythonObject` values from CPython 'borrowed
    reference' pointers.

    The existing `PythonObject.__init__(PyObjectPtr)` should continue to be used
    for the more common case of constructing a `PythonObject` from a
    'strong reference' pointer.

  - Support for multi-dimensional indexing and slicing for `PythonObject`
    (PR [#3549](https://github.com/modular/modular/pull/3549),
    PR [#3583](https://github.com/modular/modular/pull/3583)).

    ```mojo
    var np = Python.import_module("numpy")
    var a = np.array(PythonObject([1,2,3,4,5,6])).reshape(2,3)
    print((a[0, 1])) # 2
    print((a[1][::-1])) # [6 5 4]
    ```

    Note that the syntax, `a[1, ::-1]`, is currently not supported.

  - Added
    [`PythonObject.__contains__()`](/mojo/stdlib/python/python_object/PythonObject#__contains__).
    ([PR #3101](https://github.com/modular/modular/pull/3101))

    Example usage:

    ```mojo
    x = PythonObject([1,2,3])
    if 1 in x:
        print("1 in x")
    ```

- Pointer related changes:

  - The [`UnsafePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer) type
    now has an `origin` parameter that can be used when the `UnsafePointer`
    points to a value with a known origin. This origin is propagated through the
    `ptr[]` indirection operation. This parameter and other `UnsafePointer`
    parameters (other than the type) are now keyword-only.

  - You can now index into `UnsafePointer` using `SIMD` scalar integral types:

    ```mojo
    p = UnsafePointer[Int].alloc(1)
    i = UInt8(1)
    p[i] = 42
    print(p[i])
    ```

  - Added a new [`OwnedPointer`](/mojo/stdlib/memory/owned_pointer/OwnedPointer)
    type as a safe, single-owner, non-nullable smart pointer with similar
    semantics to Rust's
    [`Box<>`](https://doc.rust-lang.org/std/boxed/struct.Box.html) and C++'s
    [`std::unique_ptr`](https://en.cppreference.com/w/cpp/memory/unique_ptr).
    ([PR #3524](https://github.com/modular/modular/pull/3524))

  - `Arc` has been renamed to
    [`ArcPointer`](/mojo/stdlib/memory/arc/ArcPointer), for consistency with
    `OwnedPointer`.

  - [`ArcPointer`](/mojo/stdlib/memory/arc/ArcPointer) now implements
    [`Identifiable`](/mojo/stdlib/builtin/identifiable/Identifiable), and can be
    compared for pointer equivalence using `a is b`.

  - The `Reference` type has been renamed to
    [`Pointer`](/mojo/stdlib/memory/pointer/Pointer): a memory safe complement
    to `UnsafePointer`. This change is motivated by the fact that `Pointer` is
    assignable and requires an explicit dereference with `ptr[]`. Renaming to
    `Pointer` clarifies that "references" means `ref` arguments and results, and
    gives us a model that is more similar to what the C++ community would
    expect.

    For an overview of Mojo's pointer types, see the new
    [Intro to pointers](/mojo/manual/pointers/) page in the Mojo Manual.

  - A new
    [`as_noalias_ptr()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#as_noalias_ptr)
    method as been added to `UnsafePointer`. This method specifies to the
    compiler that the resultant pointer is a distinct identifiable object that
    does not alias any other memory in the local scope.

- Added the [`Floatable`](/mojo/stdlib/builtin/floatable/Floatable) and
  [`FloatableRaising`](/mojo/stdlib/builtin/floatable/FloatableRaising) traits
  to denote types that can be converted to a `Float64` value using the builtin
  `float` function. Made `SIMD` and `FloatLiteral` conform to the `Floatable`
  trait. ([PR #3163](https://github.com/modular/modular/pull/3163))

  ```mojo
  fn foo[F: Floatable](v: F):
    ...

  var f = float(Int32(45))
  ```

- The [`rebind()`](/mojo/stdlib/builtin/rebind/rebind) standard library function
  now works with memory-only types in addition to
  `@register_passable("trivial")` ones, without requiring a copy. For more
  information, see
  [The `rebind()` builtin](/mojo/manual/parameters/#the-rebind-builtin) in the
  Mojo Manual.

- Introduced the [`random.shuffle()`](/mojo/stdlib/random/random/shuffle)
  function for randomizing the elements of a `List`.
  ([PR #3327](https://github.com/modular/modular/pull/3327))

  Example:

  ```mojo
  from random import shuffle

  var l = List[Int](1, 2, 3, 4, 5)
  shuffle(l)
  ```

- The [`Dict.__getitem__()`](/mojo/stdlib/collections/dict/Dict#__getitem__)
  method now returns a reference instead of a copy of the value (or raises).
  This improves the performance of common code that uses `Dict` by allowing
  borrows from the `Dict` elements.

- [`Slice.step`](/mojo/stdlib/builtin/builtin_slice/Slice#fields) is now an
  `Optional[Int]`, matching the optionality of `slice.step` in Python.
  ([PR #3160](https://github.com/modular/modular/pull/3160))

- There is now a [`Byte`](/mojo/stdlib/builtin/simd/#aliases) alias to better
  express intent when working with a pack of bits.
  ([PR #3670](https://github.com/modular/modular/pull/3670)).

- Expanded [`os.path`](/mojo/stdlib/os/path/path/) with new functions:
  - `os.path.expandvars()`: Expands environment variables in a path ([PR #3735](https://github.com/modular/modular/pull/3735)).
  - `os.path.splitroot()`: Split a path into drive, root and tail.
  ([PR #3780](https://github.com/modular/modular/pull/3780)).

- Added a [`reserve()`](/mojo/stdlib/collections/string/string/String#reserve)
  method and new constructor to the `String` struct to allocate additional
  capacity. ([PR #3755](https://github.com/modular/modular/pull/3755)).

- A new
  [`StringLiteral.get[some_stringable]()`](/mojo/stdlib/builtin/string_literal/StringLiteral#get)
  method is available. It allows forming a runtime-constant `StringLiteral` from
  a compile-time-dynamic `Stringable` value.

- [`Span`](/mojo/stdlib/memory/span/Span) has moved from the `utils` module to
  the `memory` module.

- [`Span`](/mojo/stdlib/memory/span/Span) now implements `__reversed__()`. This
  means that one can get a reverse iterator over a `Span` using
  `reversed(my_span)`. Users should currently prefer this method over
  `my_span[::-1]`.

- A new `AsBytes` trait has been added to
  enable taking a `Span[Byte]` from any type that implements `as_bytes()`.
  `String.as_bytes()` and `String.as_bytes_slice()` have been consolidated under
  `String.as_bytes()` to return a `Span[Byte]`. If you require a copy, you can
  convert the `Span` to a `List` with `List(my_string.as_bytes())`.

- [`StringSlice`](/mojo/stdlib/collections/string/string_slice/StringSlice) now
  implements `strip()`, `rstrip()`, and `lstrip()`.

- [`StringRef`](/mojo/stdlib/collections/string/string_slice/StringSlice) now
  implements `split()` which can be used to split a `StringRef` into a
  `List[StringRef]` by a delimiter. ([PR
  #2705](https://github.com/modular/modular/pull/2705))

- [`StringRef`](/mojo/stdlib/collections/string/string_slice/StringSlice) is now
  representable so `repr(StringRef("hello"))` will return `StringRef('hello')`.

- More things have been removed from the auto-exported set of entities in the
  `prelude` module from the Mojo standard library:
  - `UnsafePointer` has been removed. Please explicitly import it via
    `from memory import UnsafePointer`.
  - `StringRef` has been removed. Please explicitly import it via
    `from utils import StringRef`.

- Restored implicit copyability of [`Tuple`](/mojo/stdlib/builtin/tuple/Tuple)
  and `ListLiteral`.

- The
  [aliases for C foreign function interface (FFI)](/mojo/stdlib/sys/ffi/#aliases)
  have been renamed: `C_int` -> `c_int`, `C_long` -> `c_long` and so on.

- `Float32` and `Float64` are now printed and converted to strings with
  roundtrip guarantee and shortest representation:

  ```plaintext
  Value                       Old                       New
  Float64(0.3)                0.29999999999999999       0.3
  Float32(0.3)                0.30000001192092896       0.3
  Float64(0.0001)             0.0001                    0.0001
  Float32(0.0001)             9.9999997473787516e-05    0.0001
  Float64(-0.00001)           -1.0000000000000001e-05   -1e-05
  Float32(-0.00001)           -9.9999997473787516e-06   -1e-05
  Float32(0.00001234)         1.2339999557298142e-05    1.234e-05
  Float32(-0.00000123456)     -1.2345600453045336e-06   -1.23456e-06
  Float64(1.1234567e-320)     1.1235052786429946e-320   1.1235e-320
  Float64(1.234 * 10**16)     12340000000000000.0       1.234e+16
  ```

- The `StaticIntTuple` data structure in the `utils` package has been renamed to
  [`IndexList`](/mojo/stdlib/utils/index_/IndexList). The data structure now
  allows one to specify the index bitwidth of the elements along with whether
  the underlying indices are signed or unsigned.

- Added [`DLHandle.get_symbol()`](/mojo/stdlib/sys/ffi/DLHandle#get_symbol), for
  getting a pointer to a symbol in a dynamic library. This is more general
  purpose than the existing methods for getting function pointers.

### Tooling changes {#24-6-tooling-changes}

- The VS Code Mojo Debugger now has a `buildArgs` JSON debug configuration
  setting that can be used in conjunction with `mojoFile` to define the build
  arguments when compiling the Mojo file.

- The VS Code extension now supports a `Configure Build and Run Args` command
  that helps set the build and run args for actions file `Run Mojo File` and
  `Debug Mojo File`. A corresponding button appears in `Run and Debug` selector
  in the top right corner of a Mojo File.

- The VS Code extension now has the `mojo.run.focusOnTerminalAfterLaunch`
  setting, which controls whether to focus on the terminal used by the
  `Mojo: Run Mojo File` command or on the editor after launch.
  [Issue #3532](https://github.com/modular/modular/issues/3532).

- The VS Code extension now has the `mojo.SDK.additionalSDKs` setting, which
  allows the user to provide a list of MAX SDKs that the extension can use when
  determining a default SDK to use. The user can select the default SDK to use
  with the `Mojo: Select the default MAX SDK` command.

- The VS Code extension now supports setting
  [data breakpoints](https://code.visualstudio.com/docs/editor/debugging#_data-breakpoints)
  as well as
  [function breakpoints](https://code.visualstudio.com/docs/editor/debugging#_function-breakpoints).

- The Mojo LLDB debugger now supports symbol breakpoints, for example, `b main`
  or `b my_module::main`.

- Error messages that include type names no longer include inferred or defaulted
  parameters when they aren't needed.  For example, previously Mojo complained
  about things like:

  ```plaintext
  ... cannot be converted from 'UnsafePointer[UInt, 0, _default_alignment::AnyType](), MutableAnyOrigin]' to 'UnsafePointer[Int, 0, _default_alignment[::AnyType](), MutableAnyOrigin]'
  ```

  it now complains more helpfully that:

  ```plaintext
  ... cannot be converted from 'UnsafePointer[UInt]' to 'UnsafePointer[Int]'
  ```

- Tooling now prints the origins of `ref` arguments and results correctly, and
  prints `self` instead of `self: Self` in methods.

- The Mojo Language Server and generated documentation now print parametric
  result types correctly, e.g. showing `SIMD[type, simd_width]` instead of
  `SIMD[$0, $1]`.

- Generated API documentation now shows the signatures for structs, and
  identifies `@register_passable` and `@register_passable("trivial")` types.

- The VS Code extension now allows cancelling the installation of its private
  MAX SDK.

- The VS Code extension now opens the Run and Debug tab automatically whenever
  a debug session starts.

- The `mojo debug --vscode` command now support the `--init-command` and
  `--stop-on-entry` flags. Execute `mojo debug --help` for more information.

- The Mojo LLDB debugger on VS Code now supports inspecting the raw attributes
  of variables that are handled as synthetic types, e.g. `List` from Mojo or
  `std::vector` from C++.

- The VS Code extension now allows selecting a default SDK when multiple are
  available.

### ❌ Removed

- The `UnsafePointer.bitcast()` overload for `DType` has been removed. Wrap your
  `DType` in a `Scalar[my_dtype]` to call the only overload of `bitcast()` now.

### 🛠️ Fixed

- Lifetime tracking is now fully field sensitive, which makes the uninitialized
  variable checker more precise.

- [Issue #1310](https://github.com/modular/modular/issues/1310) - Mojo permits
  the use of any constructor for implicit conversions

- [Issue #1632](https://github.com/modular/modular/issues/1632) - Mojo produces
  weird error when inout function is used in non mutating function

- [Issue #3444](https://github.com/modular/modular/issues/3444) - Raising init
  causing use of uninitialized variable

- [Issue #3544](https://github.com/modular/modular/issues/3544) - Known
  mutable `ref` argument are not optimized as `noalias` by LLVM.

- [Issue #3559](https://github.com/modular/modular/issues/3559) - VariadicPack
  doesn't extend the lifetimes of the values it references.

- [Issue #3627](https://github.com/modular/modular/issues/3627) - Compiler
  overlooked exclusivity violation caused by `ref [MutableAnyOrigin] T`

- [Issue #3710](https://github.com/modular/modular/issues/3710) - Mojo frees
  memory while reference to it is still in use.

- [Issue #3805](https://github.com/modular/modular/issues/3805) - Crash When
  Initializing !llvm.ptr.

- [Issue #3816](https://github.com/modular/modular/issues/3816) - Ternary
  if-operator doesn't propagate origin information.

- [Issue #3815](https://github.com/modular/modular/issues/3815) -
  [BUG] Mutability not preserved when taking the union of two origins.

- [Issue #3829](https://github.com/modular/modular/issues/3829) - Poor error
  message when invoking a function pointer upon an argument of the wrong origin

- [Issue #3830](https://github.com/modular/modular/issues/3830) - Failures
  emitting register RValues to ref arguments.

- The VS Code extension now auto-updates its private copy of the MAX SDK.

- The variadic initializer for `SIMD` now works in parameter expressions.

- The VS Code extension now downloads its private copy of the MAX SDK in a way
  that prevents `ETXTBSY` errors on Linux.

- The VS Code extension now allows invoking a mojo formatter from SDK
  installations that contain white spaces in their path.

### Special thanks

Special thanks to our community contributors:
[@soraos](https://github.com/soraros), [@jjvraw](https://github.com/jjvraw),
[@bgreni](https://github.com/bgreni),
[@thatstoasty](https://github.com/thatstoasty),
[@szbergeron](https://github.com/szbergeron),
[@rd4com](https://github.com/rd4com),
[@fknfilewalker](https://github.com/fknfilewalker),
[@gabrieldemarmiesse](https://github.com/gabrieldemarmiesse),
[@avitkauskas](https://github.com/avitkauskas), and
[@martinvuyk](https://github.com/martinvuyk).

## v24.5 (2024-09-13)

### ✨ Highlights

Here's a brief summary of some of the major changes in this release, with more
detailed information in the following sections:

- Mojo now supports Python 3.12 interoperability.

- The set of automatically imported entities (types, aliases, functions) into
  users' Mojo programs has been dramatically reduced. This can break existing
  user code as users will need to explicitly import what they're using for cases
  previously automatically included before.

- [`print()`](/mojo/stdlib/builtin/io/print) now requires that its arguments
  conform to the [`Formattable`](/mojo/stdlib/utils/write/Writable) trait.
  This enables efficient stream-based writing by default, avoiding unnecessary
  intermediate String heap allocations.

- The new builtin [`input()`](/mojo/stdlib/builtin/io/input) function prints an
  optional prompt and reads a line from standard input, in the same way as
  Python.

- Mojo now allows implicit definitions of variables within a `fn` in the same
  way that has been allowed in a `def`. The `var` keyword is still allowed, but
  is now optional.

- Mojo now diagnoses "argument exclusivity" violations due to aliasing
  references. Mojo requires references (including implicit references due to
  `borrowed`/`inout` arguments) to be uniquely referenced (non-aliased) if
  mutable. This is a warning in the 24.5 release, but will be upgraded to an
  error in subsequent releases.

- Mojo now supports "conditional conformances" where some methods on a struct
  have additional trait requirements that the struct itself doesn't.

- `DTypePointer`, `LegacyPointer`, and `Pointer` have been removed. Use
  [`UnsafePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer) instead.
  Functions that previously took a `DTypePointer` now take an equivalent
  `UnsafePointer`. For more information on using pointers, see [Unsafe
  pointers](/mojo/manual/pointers/unsafe-pointers) in the Mojo Manual.

- There are many new standard library APIs, with new features for strings,
  collections, and interacting with the filesystem and environment. Changes are
  listed in the standard library section.

- The VS Code extension now supports a vendored MAX SDK for VS Code, which is
  automatically downloaded by the extension and it's used for all Mojo features,
  including the Mojo Language Server, the Mojo debugger, the Mojo formatter, and
  more.

- [`mojo test`](/mojo/cli/test) now uses the Mojo compiler for running unit
  tests. This will resolve compilation issues that sometimes appeared, and will
  also improve overall test execution times.

### Language changes

- Mojo now allows implicit definitions of variables within a `fn` in the same
  way that has been allowed in a `def`.  The `var` keyword is still allowed and
  still denotes the declaration of a new variable with a scope (in both `def`
  and `fn`).  Relaxing this makes `fn` and `def` more similar, but they still
  differ in other important ways.

- Mojo now diagnoses "argument exclusivity" violations due to aliasing
  references. Mojo requires references (including implicit references due to
  `borrowed`/`inout` arguments) to be uniquely referenced (non-aliased) if
  mutable. This is important for code safety, because it allows the compiler
  (and readers of code) to understand where and when a value is mutated. It is
  also useful for performance optimization because it allows the compiler to
  know that accesses through immutable references cannot change behind the
  scenes. Here is an invalid example:

  ```mojo
  fn take_two_strings(a: String, inout b: String):
     # Mojo knows 'a' and 'b' cannot be the same string.
     b += a

  fn invalid_access():
    var my_string = String()

    # warning: passing `my_string` inout is invalid since it is also passed
    # borrowed.
    take_two_strings(my_string, my_string)
  ```

  This is similar to [Swift exclusivity
  checking](https://swift.org/blog/swift-5-exclusivity/) and the [Rust
  language](https://doc.rust-lang.org/beta/book/ch04-02-references-and-borrowing.html)
  sometimes known as "aliasing xor mutability". That said, the Mojo
  implementation details are somewhat different because lifetimes are embedded
  in types.

  This is a warning in the 24.5 release, but will be upgraded to an error in
  subsequent releases.

  :::note

  Argument exclusivity is not enforced for register-passable types. They are
  passed by copy, so they don't form aliases.

  :::

- Mojo now supports "conditional conformances" where some methods on a struct
  have additional trait requirements that the struct itself doesn't. This is
  expressed through an explicitly declared `self` type:

  ```mojo
  struct GenericThing[Type: AnyType]:  # Works with anything
    # Sugar for 'fn normal_method[Type: AnyType](self: GenericThing[Type]):'
    fn normal_method(self): ...

    # Just redeclare the requirements with more specific types:
    fn needs_move[Type: Movable](self: GenericThing[Type], owned val: Type):
      var tmp = val^  # Ok to move 'val' since it is Movable
      ...
  fn usage_example():
    var a = GenericThing[Int]()
    a.normal_method() # Ok, Int conforms to AnyType
    a.needs_move(42)  # Ok, Int is movable

    var b = GenericThing[NonMovable]()
    b.normal_method() # Ok, NonMovable conforms to AnyType

      # error: argument type 'NonMovable' does not conform to trait 'Movable'
    b.needs_move(NonMovable())
  ```

  Conditional conformance works with dunder methods and other things as well.

- As a specific form of "conditional conformances", initializers in a struct
  may indicate specific parameter bindings to use in the type of their `self`
  argument. For example:

  ```mojo
  @value
  struct MyStruct[size: Int]:
      fn __init__(inout self: MyStruct[0]): pass
      fn __init__(inout self: MyStruct[1], a: Int): pass
      fn __init__(inout self: MyStruct[2], a: Int, b: Int): pass

  def test(x: Int):
      a = MyStruct()      # Infers size=0 from 'self' type.
      b = MyStruct(x)     # Infers size=1 from 'self' type.
      c = MyStruct(x, x)  # Infers size=2 from 'self' type.
  ```

- Mojo now supports named result bindings. Named result bindings are useful for
  directly emplacing function results into the output slot of a function. This
  feature provides more flexibility and guarantees around emplacing the result
  of a function compared to "guaranteed" named return value optimization (NRVO).
  If a `@register_passable` result is bound to a name, the result value is made
  accessible as a mutable reference.

  ```mojo
  fn efficiently_return_string(b: Bool) -> String as output:
      if b:
          output = "emplaced!"
          mutate(output)
          return
      return "regular return"
  ```

  If we used a temporary for `output` instead, we would need to move into the
  result slot, which wouldn't work if the result type was non-movable.

  In a function with a named result, `return` may be used with no operand to
  signal an exit from the function, or it can be used normally to specify the
  return value of the function. The compiler will error if the result is not
  initialized on all normal exit paths from the function.

- `__setitem__()` now works with variadic argument lists such as:

  ```mojo
  struct YourType:
      fn __setitem__(inout self, *indices: Int, val: Int): ...
  ```

  The Mojo compiler now always passes the "new value" being set using the last
  keyword argument of the `__setitem__()`, e.g. turning `yourType[1, 2] = 3`
  into `yourType.__setitem__(1, 2, val=3)`. This fixes [Issue
  #248](https://github.com/modular/modular/issues/248).

- Mojo context managers used in regions of code that may raise no longer need to
  define a "conditional" exit function in the form of
  `fn __exit__(self, e: Error) -> Bool`. This function allows the context
  manager to conditionally intercept and handle the error and allow the function
  to continue executing. This is useful for some applications, but in many cases
  the conditional exit would delegate to the unconditional exit function
  `fn __exit__(self)`.

  Concretely, this enables defining `with` regions that unconditionally
  propagate inner errors, allowing code like:

  ```mojo
  def might_raise() -> Int:
      ...

  def foo() -> Int:
      with ContextMgr():
          return might_raise()
      # no longer complains about missing return

  def bar():
      var x: Int
      with ContextMgr():
          x = might_raise()
      print(x) # no longer complains about 'x' being uninitialized
  ```

- `async` functions now support memory-only results (like `String`, `List`,
  etc.) and `raises`. Accordingly, both
  [`Coroutine`](/mojo/stdlib/builtin/coroutine/Coroutine) and
  [`RaisingCoroutine`](/mojo/stdlib/builtin/coroutine/RaisingCoroutine) have
  been changed to accept `AnyType` instead of `AnyTrivialRegType`. This means
  the result types of `async` functions do not need to be `Movable`.

  ```mojo
  async fn raise_or_string(c: Bool) raises -> String:
      if c:
          raise "whoops!"
      return "hello world!"
  ```

  Note that `async` functions do not yet support indirect calls, `ref` results,
  and constructors.

- The [`Reference`](/mojo/stdlib/memory/pointer/Pointer) type (and many
  iterators) now use [infer-only
  parameters](/mojo/manual/parameters/#infer-only-parameters) to represent the
  mutability of their lifetime, simplifying the interface.

- The environment variable `MOJO_PYTHON` can be pointed to an executable to pin
  Mojo to a specific version:

  ```sh
  export MOJO_PYTHON="/usr/bin/python3.11"
  ```

  Or a virtual environment to always have access to those Python modules:

  ```sh
  export MOJO_PYTHON="~/venv/bin/python"
  ```

  `MOJO_PYTHON_LIBRARY` still exists for environments with a dynamic `libpython`
  but no Python executable.

- The pointer aliasing semantics of Mojo have changed. Initially, Mojo adopted a
  C-like set of semantics around pointer aliasing and derivation. However, the C
  semantics bring a lot of history and baggage that are not needed in Mojo and
  which complicate compiler optimizations. The language overall provides a
  stronger set of invariants around pointer aliasing with lifetimes and
  exclusive mutable references to values, etc.

  It is now forbidden to convert a non-pointer-typed value derived from a
  Mojo-allocated pointer, such as an integer address, to a pointer-typed value.
  "Derived" means there is overlap in the bits of the non-pointer-typed value
  with the original pointer value. Accordingly, the
  [`UnsafePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer)
  constructor that took an `address` keyword argument has been removed.

  It is still possible to make this conversion in certain cases where it is
  absolutely necessary, such as interoperating with other languages like Python.
  In this case, the compiler makes two assumptions: any pointer derived from a
  non-pointer-typed value does not alias any Mojo-derived pointer and that any
  external function calls have arbitrary memory effects.

- `await` on a coroutine now consumes it. This strengthens the invariant that
  coroutines can be awaited only once.

### Standard library changes

- [`builtin`](/mojo/stdlib/builtin/) package:

  - The set of automatically imported entities (types, aliases, functions) into
    users' Mojo programs has been dramatically reduced. Before, with the way the
    `builtin` module was handled, all of the entities in the following modules
    would be automatically included:

    `memory`, `sys`, `os`, `utils`, `python`, `bit`, `random`, `math`,
    `builtin`, `collections`

    Now, only the explicitly enumerated entities in `prelude/__init__.mojo` are
    the ones automatically imported into users' Mojo programs. This will break a
    lot of user code as users will need to explicitly import what they're using
    for cases previously commonly included before (such as
    [`Optional`](/mojo/stdlib/collections/optional/Optional),
    [`Variant`](/mojo/stdlib/utils/variant/Variant), and functions such as
    [`abort()`](/mojo/stdlib/os/os/abort),
    [`alignof()`](/mojo/stdlib/sys/info/alignof),
    [`bitcast()`](/mojo/stdlib/memory/unsafe/bitcast),
    [`bitwidthof()`](/mojo/stdlib/sys/info/bitwidthof),
    [`external_call()`](/mojo/stdlib/sys/ffi/external_call),
    [`simdwidthof()`](/mojo/stdlib/sys/info/simdwidthof), and
    [`sizeof()`](/mojo/stdlib/sys/info/sizeof)).

  - Some types from the `builtin` module have been moved to different modules
    for clarity which is made possible now that we have a `prelude` module that
    can re-export symbols from modules other than `builtin`.

    In particular, the `builtin.string` module has been moved to
    [`collections.string`](/mojo/stdlib/collections/string/).

- Input and output:

  - Added the builtin [`input()`](/mojo/stdlib/builtin/io/input) function, which
    behaves the same as Python.
    ([PR #3392](https://github.com/modular/modular/pull/3392))

    ```mojo
    name = input("Enter your name: ")
    print("Hello, " + name + "!")
    ```

    If the user enters "Mojo" it returns "Hello, Mojo!"

    There is a known issue when running the `input()` function with JIT
    compilation (see issue
    [#3479](https://github.com/modular/modular/issues/3479)).

  - [`print()`](/mojo/stdlib/builtin/io/print) now requires that its arguments
    conform to the [`Formattable`](/mojo/stdlib/utils/write/Writable) trait.
    This enables efficient stream-based writing by default, avoiding unnecessary
    intermediate String heap allocations.

    Previously, `print()` required types conform to
    [`Stringable`](/mojo/stdlib/builtin/str/Stringable). This meant that to
    execute a call like `print(a, b, c)`, at least three separate String heap
    allocations were down, to hold the formatted values of `a`, `b`, and `c`
    respectively. The total number of allocations could be much higher if, for
    example, `a.__str__()` was implemented to concatenate together the fields of
    `a`, like in the following example:

    ```mojo
    struct Point(Stringable):
        var x: Float64
        var y: Float64

        fn __str__(self) -> String:
            # Performs 3 allocations: 1 each for str(..) of each of the fields,
            # and then the final returned `String` allocation.
            return "(" + str(self.x) + ", " + str(self.y) + ")"
    ```

    A type like the one above can transition to additionally implementing
    `Formattable` with the following changes:

    ```mojo
    struct Point(Stringable, Formattable):
        var x: Float64
        var y: Float64

        fn __str__(self) -> String:
            return String.format_sequence(self)

        fn format_to(self, inout writer: Formatter):
            writer.write("(", self.x, ", ", self.y, ")")
    ```

    In the example above,
    [`String.format_sequence()`](/mojo/stdlib/collections/string/string/String#format_sequence)
    is used to construct a `String` from a type that implements `Formattable`.
    This pattern of implementing a type's `Stringable` implementation in terms
    of its `Formattable` implementation minimizes boilerplate and duplicated
    code, while retaining backwards compatibility with the requirements of the
    commonly used `str()` function.

    <!-- TODO(MOCO-891): Remove this warning when error is improved. -->

    :::note

    The error shown when passing a type that does not implement `Formattable` to
    `print()` is currently not entirely descriptive of the underlying cause:

    ```shell
    error: invalid call to 'print': callee with non-empty variadic pack argument expects 0 positional operands, but 1 was specified
       print(point)
       ~~~~~^~~~~~~
    ```

    If you see the above error, ensure that all argument types implement
    `Formattable`.

    :::

  - [`debug_assert()`](/mojo/stdlib/builtin/debug_assert/debug_assert) now also
    requires that its `message` argument conform to `Formattable`.

  - Added
    [`TemporaryDirectory`](/mojo/stdlib/tempfile/tempfile/TemporaryDirectory) in
    module `tempfile`.
    ([PR 2743](https://github.com/modular/modular/pull/2743))

  - Added
    [`NamedTemporaryFile`](/mojo/stdlib/tempfile/tempfile/NamedTemporaryFile) in
    module `tempfile`.
    ([PR 2762](https://github.com/modular/modular/pull/2762))

- [`String`](/mojo/stdlib/collections/string/string) and friends:

  - The `builtin.string` module has been moved to
    [`collections.string`](/mojo/stdlib/collections/string/).

  - Added the
    [`String.format()`](/mojo/stdlib/collections/string/string/String#format)
    method. ([PR #2771](https://github.com/modular/modular/pull/2771))

    Supports automatic and manual indexing of `*args`.

    Examples:

    ```mojo
    print(
      String("{1} Welcome to {0} {1}").format("mojo", "🔥")
    )
    # 🔥 Wecome to mojo 🔥
    ```

    ```mojo
    print(String("{} {} {}").format(True, 1.125, 2))
    #True 1.125 2
    ```

  - [`String.format()`](/mojo/stdlib/collections/string/string/String#format)
    now supports conversion flags `!s` and `!r`, allowing for `str()` and
    `repr()` conversions within format strings. ([PR
    #3279](https://github.com/modular/modular/pull/3279))

    Example:

    ```mojo
    String("{} {!r}").format("Mojo", "Mojo")
    # "Mojo 'Mojo'"

    String("{0!s} {0!r}").format("Mojo")
    # "Mojo 'Mojo'"
    ```

  - The `String` class now has
    [`rjust()`](/mojo/stdlib/collections/string/string/String#rjust),
    [`ljust()`](/mojo/stdlib/collections/string/string/String#ljust), and
    [`center()`](/mojo/stdlib/collections/string/string/String#center) methods
    to return a justified string based on width and fillchar. ([PR
    #3278](https://github.com/modular/modular/pull/3278))

  - The [`atol()`](/mojo/stdlib/collections/string/string/atol) function now
    correctly supports leading underscores, (e.g.`atol("0x_ff", 0)`), when the
    appropriate base is specified or inferred (base 0). non-base-10 integer
    literals as per Python's [Integer
    Literals](<https://docs.python.org/3/reference/lexical_analysis.html#integers>).
    ([PR #3180](https://github.com/modular/modular/pull/3180))

  - Added the
    [`unsafe_cstr_ptr()`](/mojo/stdlib/collections/string/string/String#unsafe_cstr_ptr)
    method to `String` and `StringLiteral`, which returns an
    `UnsafePointer[c_char]` for convenient interoperability with C APIs.

  - Added the `byte_length()` method to
    [`String`](/mojo/stdlib/collections/string/string/String#byte_length),
    [`StringSlice`](/mojo/stdlib/collections/string/string_slice/StringSlice#byte_length),
    and
    [`StringLiteral`](/mojo/stdlib/builtin/string_literal/StringLiteral#byte_length)
    and deprecated their private `_byte_length()` methods. Added a warning to
    the
    [`String.__len__()`](/mojo/stdlib/collections/string/string/String#__len__)
    method that it will return the length in Unicode codepoints in the future
    and
    [`StringSlice.__len__()`](/mojo/stdlib/collections/string/string_slice/StringSlice#__len__)
    now does return the Unicode codepoints length. ([PR
    #2960](https://github.com/modular/modular/pull/2960))

  - Added a new
    [`StaticString`](/mojo/stdlib/collections/string/string_slice/#aliases) type
    alias. This can be used in place of
    [`StringLiteral`](/mojo/stdlib/builtin/string_literal/StringLiteral) for
    runtime string arguments.

  - Added a
    [`StringSlice`](/mojo/stdlib/collections/string/string_slice/StringSlice#__init__)
    initializer that accepts a `StringLiteral`.

  - The `StringRef` constructors from `DTypePointer.int8` have been changed to
    take a `UnsafePointer[c_char]`, reflecting their use for compatibility with
    C APIs.

  - Continued the transition to `UnsafePointer` and unsigned byte type for
    strings:

    - [`String.unsafe_ptr()`](/mojo/stdlib/collections/string/string/String#unsafe_ptr)
      now returns an `UnsafePointer[UInt8]` (was `UnsafePointer[Int8]`)

    - [`StringLiteral.unsafe_ptr()`](/mojo/stdlib/builtin/string_literal/StringLiteral#unsafe_ptr)
      now returns an `UnsafePointer[UInt8]` (was `UnsafePointer[Int8]`)

- [`UnsafePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer) and other
  reference type changes:

  - `DTypePointer`, `LegacyPointer`, and `Pointer` have been removed. Use
    [`UnsafePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer) instead.
    For more information on using pointers, see [Unsafe
    pointers](/mojo/manual/pointers/unsafe-pointers) in the Mojo Manual.

    Functions that previously took a `DTypePointer` now take an equivalent
    `UnsafePointer`. A quick rule for conversion from `DTypePointer` to
    `UnsafePointer` is:

    ```mojo
    DTypePointer[type] -> UnsafePointer[Scalar[type]]
    ```

    There could be places that you have code of the form:

    ```mojo
    fn f(ptr: DTypePointer):
    ```

    which is equivalent to `DTypePointer[*_]`. In this case you would have to
    add an infer-only `type` parameter to the function:

    ```mojo
    fn f[type: DType, //](ptr: UnsafePointer[Scalar[type]]):
    ```

    because we can’t have an unbound parameter inside the struct.

    There could also be places where you use
    `DTypePointer[Scalar[DType.invalid/index]]`, and it would be natural to
    change these to `UnsafePointer[NoneType/Int]`. But since these are not an
    `UnsafePointer` that stores a `Scalar`, you might have to `rebind/bitcast`
    to appropriate types.

  - The `DTypePointer`
    [`load()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#load) and
    [`store()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#store) methods
    have been moved to `UnsafePointer`.

  - `UnsafePointer` now supports
    [`strided_load()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#strided_load),
    [`strided_store()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#strided_store),
    [`gather()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#gather), and
    [`scatter()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#scatter) when
    the underlying type is `Scalar[DType]`.

  - The global functions for working with `UnsafePointer` have transitioned to
    being methods through the use of conditional conformances:

    - `destroy_pointee(p)` => [`p.destroy_pointee()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#destroy_pointee)
    - `move_from_pointee(p)` => [`p.take_pointee()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#take_pointee)
    - `initialize_pointee_move(p, value)` => [`p.init_pointee_move(value)`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#init_pointee_move)
    - `initialize_pointee_copy(p, value)` => [`p.init_pointee_copy(value)`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#init_pointee_copy)
    - `move_pointee(src=p1, dst=p2)` => [`p.move_pointee_into(p2)`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#move_pointee_into)

  - The `UnsafePointer.offset()` method is deprecated and will be removed in a
    future release. Use [pointer
    arithmetic](/mojo/manual/pointers#storing-multiple-values) instead.

    ```mojo
    new_ptr = ptr.offset(1)
    ```

    Becomes:

    ```mojo
    new_ptr = ptr + 1
    ```

  - `UnsafePointer` now has an
    [`alignment`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#parameters)
    parameter to specify the static alignment of the pointer. Consequently,
    [`UnsafePointer.alloc()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#alloc)
    no longer takes in an alignment parameter, and the alignment should be
    specified in the type.

    ```mojo
    UnsafePointer[type].alloc[alignment](x) # now becomes
    UnsafePointer[type, alignment].alloc(x)
    ```

  - `UnsafePointer` has a new [`exclusive: Bool =
    False`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#parameters)
    parameter. Setting this parameter to true tells the compiler that the user
    knows this pointer and all those derived from it have exclusive access to
    the underlying memory allocation. The compiler is not guaranteed to do
    anything with this information.

  - It is no longer possible to cast (implicitly or explicitly) from `Reference`
    to `UnsafePointer`. Instead of `UnsafePointer(someRef)` please use the
    [`UnsafePointer.address_of(someRef[])`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#address_of)
    which makes the code explicit that the `UnsafePointer` gets the address of
    what the reference points to.

- Python interoperability changes:

  - Mojo now supports Python 3.12 interoperability.

  - Creating a nested
    [`PythonObject`](/mojo/stdlib/python/python_object/PythonObject) from a list
    or tuple of Python objects is possible now:

    ```mojo
    var np = Python.import_module("numpy")
    var a = np.array([1, 2, 3])
    var b = np.array([4, 5, 6])
    var arrays = PythonObject([a, b])
    assert_equal(len(arrays), 2)
    ```

    Also allowing more convenient call syntax:

    ```mojo
    var stacked = np.hstack((a, b))
    assert_equal(str(stacked), "[1 2 3 4 5 6]")
    ```

    ([PR #3264](https://github.com/modular/modular/pull/3264))

  - Accessing local Python modules with
    [`Python.add_to_path(".")`](/mojo/stdlib/python/python/Python#add_to_path)
    is no longer required. It now behaves the same as Python. You can access
    modules in the same folder as the target file:

    - `mojo run /tmp/main.mojo` can access `/tmp/mymodule.py`

    - `mojo build main.mojo -o ~/myexe && ~/myexe` can access `~/mymodule.py`

- Collections:

  - [`List`](/mojo/stdlib/collections/list/List) values are now equality
    comparable with `==` and `!=` when their element type is equality
    comparable. ([PR #3195](https://github.com/modular/modular/pull/3195))

  - [`Optional`](/mojo/stdlib/collections/optional/Optional) values are now
    equality comparable with `==` and `!=` when their element type is equality
    comparable.

  - Added a new [`Counter`](/mojo/stdlib/collections/counter/Counter)
    dictionary-like type, matching most of the features of the Python one.
    ([PR #2910](https://github.com/modular/modular/pull/2910))

  - [`Dict`](/mojo/stdlib/collections/dict/Dict) now implements
    [`setdefault()`](/mojo/stdlib/collections/dict/Dict#setdefault), which gets
    a value from the dictionary by key, or sets it to a default if it doesn't
    exist.
    ([PR #2803](https://github.com/modular/modular/pull/2803))

  - `Dict` now supports
    [`popitem()`](/mojo/stdlib/collections/dict/Dict#popitem), which removes and
    returns the last item in the `Dict`.
    ([PR #2701](https://github.com/modular/modular/pull/2701))

  - Added a [`Dict.__init__()`](/mojo/stdlib/collections/dict/Dict#__init__)
    overload to specify initial capacity.
    ([PR #3171](https://github.com/modular/modular/pull/3171))

    The capacity has to be a power of two and greater than or equal to 8.

    It allows for faster initialization by skipping incremental growth steps.

    Example:

    ```mojo
    var dictionary = Dict[Int,Int](power_of_two_initial_capacity = 1024)
    # Insert (2/3 of 1024) entries
    ```

  - `ListLiteral` now supports `__contains__()`.
    ([PR #3251](https://github.com/modular/modular/pull/3251))

- Filesystem and environment utilities:

  - [`Path.home()`](/mojo/stdlib/pathlib/path/Path#home) has been added to
    return a path of the user's home directory.

  - [`os.path.expanduser()`](/mojo/stdlib/os/path/path/expanduser) and
    [`pathlib.Path.exapanduser()`](/mojo/stdlib/pathlib/path/Path#expanduser)
    have been added to allow expanding a prefixed `~` in a `String` or `Path`
    with the user's home path:

    ```mojo
    import os
    print(os.path.expanduser("~/.modular"))
    # /Users/username/.modular
    print(os.path.expanduser("~root/folder"))
    # /var/root/folder (on macos)
    # /root/folder     (on linux)
    ```

  - [`os.path.split()`](/mojo/stdlib/os/path/path/split) has been added for
    splitting a path into `head, tail`:

    ```mojo
    import os
    head, tail = os.path.split("/this/is/head/tail")
    print("head:", head)
    print("tail:", tail)
    # head: /this/is/head
    # tail: tail
    ```

  - [`os.makedirs()`](/mojo/stdlib/os/os/makedirs) and
    [`os.removedirs()`](/mojo/stdlib/os/os/removedirs) have been added for
    creating and removing nested directories:

    ```mojo
    import os
    path = os.path.join("dir1", "dir2", "dir3")
    os.path.makedirs(path, exist_ok=True)
    os.path.removedirs(path)
    ```

  - The [`pwd`](/mojo/stdlib/pwd/pwd/) module has been added for accessing user
    information in `/etc/passwd` on POSIX systems. This follows the same logic
    as Python:

    ```mojo
    import pwd
    import os
    current_user = pwd.getpwuid(os.getuid())
    print(current_user)

    # pwd.struct_passwd(pw_name='jack', pw_passwd='********', pw_uid=501,
    # pw_gid=20, pw_gecos='Jack Clayton', pw_dir='/Users/jack',
    # pw_shell='/bin/zsh')

    print(current_user.pw_uid)

    # 501

    root = pwd.getpwnam("root")
    print(root)

    # pwd.struct_passwd(pw_name='root', pw_passwd='*', pw_uid=0, pw_gid=0,
    # pw_gecos='System Administrator', pw_dir='/var/root', pw_shell='/bin/zsh')
    ```

- Other new traits and related features:

  - Added the
    [`ExplicitlyCopyable`](/mojo/stdlib/builtin/value/ExplicitlyCopyable) trait
    to mark types that can be copied explicitly, but which might not be
    implicitly copyable.

    This supports work to transition the standard library collection types away
    from implicit copyability, which can lead to unintended expensive copies.

  - Added the [`Identifiable`](/mojo/stdlib/builtin/identifiable/Identifiable)
    trait, used to describe types that implement the `__is__()` and
    `__isnot__()` trait methods.
    ([PR #2807](https://github.com/modular/modular/pull/2807))

  - Types conforming to [`Boolable`](/mojo/stdlib/builtin/bool/Boolable) (that
    is, those implementing `__bool__()`) no longer implicitly convert to `Bool`.
    A new [`ImplicitlyBoolable`](/mojo/stdlib/builtin/bool/ImplicitlyBoolable)
    trait is introduced for types where this behavior is desired.

- Miscellaneous:

  - [`NoneType`](/mojo/stdlib/builtin/none/NoneType) is now a normal standard
    library type, and not an alias for a raw MLIR type.

    Function signatures written as `fn() -> NoneType` should transition to
    being written as `fn() -> None`.

  - Mojo now has a [`UInt`](/mojo/stdlib/builtin/uint/UInt) type for modeling
    unsigned (scalar) integers with a platform-dependent width. `UInt`
    implements most arithmetic operations that make sense for integers, with the
    notable exception of `__neg__()`. Builtin functions such as `min()`/`max()`,
    as well as `math` functions like `ceildiv()`, `align_down()`, and
    `align_up()` are also implemented for `UInt`.

  - Now that we have a `UInt` type, use this to represent the return type of a
    hash. In general, hashes should be an unsigned integer, and can also lead to
    improved performance in certain cases.

  - Added the [`c_char`](/mojo/stdlib/sys/ffi/#aliases) type alias in `sys.ffi`.

  - [`sort()`](/mojo/stdlib/builtin/sort/sort) now supports a `stable`
    parameter. It can be called by

    ```mojo
    sort[cmp_fn, stable=True](list)
    ```

    The algorithm requires $$O(N)$$ auxiliary memory. If extra memory allocation
    fails, the program crashes.

  - `sort()` no longer takes `LegacyPointer` since that type is now removed.

  - Added the [`oct()`](/mojo/stdlib/builtin/format_int/oct) builtin function
    for formatting an integer in octal.
    ([PR #2914](https://github.com/modular/modular/pull/2914))

  - Added the [`assert_is()`](/mojo/stdlib/testing/testing/assert_is) and
    [`assert_is_not()`](/mojo/stdlib/testing/testing/assert_is_not) test
    functions to the `testing` module.

  - The [`math`](/mojo/stdlib/math/constants/) package now includes the `pi`,
    `e`, and `tau` constants (Closes Issue
    [#2135](https://github.com/modular/modular/issues/2135)).

  - The [`ulp`](/mojo/stdlib/math/math/ulp) function from `numerics` has been
    moved to the `math` module.

  - `bit` module now supports
    [`bit_reverse()`](/mojo/stdlib/bit/bit/bit_reverse),
    [`byte_swap()`](/mojo/stdlib/bit/bit/byte_swap), and
    [`pop_count()`](/mojo/stdlib/bit/bit/pop_count) for the `Int` type.
    ([PR #3150](https://github.com/modular/modular/pull/3150))

  - A few `bit` functions have been renamed for clarity:

    - `countl_zero()` ->
      [`count_leading_zeros()`](/mojo/stdlib/bit/bit/count_leading_zeros)

    - `countr_zero()` ->
      [`count_trailing_zeros()`](/mojo/stdlib/bit/bit/count_trailing_zeros)

  - [`Slice`](/mojo/stdlib/builtin/builtin_slice/Slice) now uses
    `OptionalReg[Int]` for `start` and `end` and implements a constructor which
    accepts optional values. `Slice._has_end()` has also been removed since a
    Slice with no end is now represented by an empty `Slice.end` option.
    ([PR #2495](https://github.com/modular/modular/pull/2495))

    ```mojo
      var s = Slice(1, None, 2)
      print(s.start.value()) # must retrieve the value from the optional
    ```

  - The `rank` argument for
    [`algorithm.elementwise()`](/mojo/stdlib/algorithm/functional/elementwise)
    is no longer required and is only inferred.

  - The `time.now()` function has been deprecated. Please use
    [`time.perf_counter()`](/mojo/stdlib/time/time/perf_counter) or
    [`time.perf_counter_ns`](/mojo/stdlib/time/time/perf_counter_ns) instead.

  - [`SIMD`](/mojo/stdlib/builtin/simd/SIMD) construction from `Bool` has been
    restricted to `DType.bool` data type.

### Tooling changes

- [`mojo test`](/mojo/cli/test) new features and changes:

  - `mojo test` now uses the Mojo compiler for running unit tests. This will
    resolve compilation issues that sometimes appeared, and will also improve
    overall test times, since we will only compile unit tests once before
    executing all of them.

    These changes do not apply to doctests, due to their different semantics.

  - The `mojo test` command now accepts a `--filter` option that will narrow the
    set of tests collected and executed. The filter string is a POSIX extended
    regular expression.

  - The `mojo test` command now supports using the same compilation options as
    `mojo build`.

  - You can now debug unit tests using `mojo test` by passing the `--debug`
    flag. Most debug flags are supported; run `mojo test --help` for a full
    listing.

    Debugging doctests is not currently supported.

- Mojo debugger new features and changes:

  - The `mojo debug --rpc` command has been renamed to [`mojo debug
      --vscode`](/mojo/cli/debug#debug-server-options), which is now able to
      manage multiple VS Code windows.

  - The Mojo debugger now supports a `break-on-raise` command that indicated the
      debugger to stop at any `raise` statements. A similar features has been
      added to the debugger on VS Code.

  - The Mojo debugger now hides the artificial function arguments `__result__`
      and `__error__` created by the compiler for Mojo code.

- VS Code support changes:

  - The VS Code extension now supports a vendored MAX SDK for VS Code, which is
    automatically downloaded by the extension and it's used for all Mojo
    features, including the Mojo Language Server, the Mojo debugger, the Mojo
    formatter, and more.

  - A proxy has been added to the Mojo Language Server on VS Code that handles
    crashes more gracefully.

- The Mojo Language Server no longer sets `.` as a commit character for
  auto-completion.

### ❌ Removed

- Support for the legacy `fn __init__(...) -> Self:` form has been removed from
  the compiler, please switch to using `fn __init__(inout self, ...):` instead.

- The builtin `tensor` module has been removed. Identical functionality is
  available in `max.tensor`, but it is generally
  recommended to use structs from the [`buffer`](/mojo/stdlib/buffer/buffer)
  module when possible instead.

- Removed `String.unsafe_uint8_ptr()`. `String.unsafe_ptr()` now returns the
  same thing.

- Removed `StringLiteral.unsafe_uint8_ptr()` and `StringLiteral.as_uint8_ptr()`.

- Removed `SIMD.splat(value: Scalar[type])`. Use the constructor for `SIMD`
  instead.

- Removed the `SIMD.{add,mul,sub}_with_overflow()` methods.

- Removed the `SIMD.min()` and `SIMD.max()` methods. Identical functionality is
  available using the builtin [`min()`](/mojo/stdlib/builtin/math/min) and
  [`max()`](/mojo/stdlib/builtin/math/max) functions.

- Removed the Mojo Language Server warnings for unused function arguments.

- `Run Mojo File in Dedicated Terminal` action has been removed, and the
  action `Run Mojo File` will always open a dedicated terminal for each mojo
  file to guarantee a correct environment.

### 🛠️ Fixed

- Fixed a crash in the Mojo Language Server when importing the current file.

- Fixed crash when specifying variadic keyword arguments without a type
  expression in `def` functions, e.g.:

  ```mojo
  def foo(**kwargs): ...  # now works
  ```

- Mojo now prints `ref` arguments and results in generated documentation
  correctly.

- [#1734](https://github.com/modular/modular/issues/1734) - Calling
  `__copyinit__` on self causes crash.

- [#3142](https://github.com/modular/modular/issues/3142) - [QoI] Confusing
  `__setitem__` method is failing with a "must be mutable" error.

- [#248](https://github.com/modular/modular/issues/248) - [Feature] Enable
  `__setitem__` to take variadic arguments

- [#3065](https://github.com/modular/modular/issues/3065) - Fix incorrect behavior
  of `SIMD.__int__` on unsigned types

- [#3045](https://github.com/modular/modular/issues/3045) - Disable implicit SIMD
  conversion routes through `Bool`

- [#3126](https://github.com/modular/modular/issues/3126) - [BUG] List doesn't
  work at compile time.

- [#3237](https://github.com/modular/modular/issues/3237) - [BUG] Difference
  between `__getitem__` and `[.]` operator.

- [#3336](https://github.com/modular/modular/issues/3336) - Fix outdated
  references to `let` in REPL documentation.

- The VS Code extension no longer caches the information of the selected
  MAX SDK, which was causing issues upon changes in the SDK.

- The Mojo debugger now stops showing spurious warnings when parsing closures.

### Special thanks

Special thanks to our community contributors:
[@jjvraw](https://github.com/jjvraw),
[@artemiogr97](https://github.com/artemiogr97),
[@martinvuyk](https://github.com/martinvuyk),
[@jayzhan211](https://github.com/jayzhan211),
[@bgreni](https://github.com/bgreni), [@mzaks](https://github.com/mzaks),
[@msaelices](https://github.com/msaelices),
[@rd4com](https://github.com/rd4com), [@jiex-liu](https://github.com/jiex-liu),
[@kszucs](https://github.com/kszucs),
[@thatstoasty](https://github.com/thatstoasty)

## v24.4 (2024-06-07)

### ✨ Highlights

Big themes for this release:

- Improvements to the performance and ease-of-use for `def` functions.

- Continued unification of standard library APIs around the `UnsafePointer`
  type.

- Many quality-of-life improvements for the standard library collection types.

- Significant performance improvements when inserting into a `Dict`. Performance
  on this metric is still not where we'd like it to be, but it is much improved.

- A new `@parameter for` mechanism for expressing compile-time loops, which
  replaces the earlier (and less reliable) `@unroll` decorator.

- New Mojo Manual pages on [Control flow](/mojo/manual/control-flow),
  [Testing](/mojo/tools/testing) and using
  [unsafe pointers](/mojo/manual/pointers/unsafe-pointers).

### Language changes

- Mojo has changed how `def` function arguments are processed.  Previously, by
  default, arguments to a `def` were treated according to the `owned`
  convention, which makes a copy of the value, enabling that value to be mutable
  in the callee.

  This could lead to major performance issues because of the proliferation of
  unnecessary copies. It also required you to declare non-copyable types as
  `borrowed` explicitly.  Now Mojo takes a different approach: `def` functions
  take arguments as `borrowed` by default (consistent with `fn` functions) but
  will make a local copy of the value **only if the argument is mutated** in the
  body of the function.

  This improves consistency, performance, and ease of use.

- Implicit variable definitions in a `def` function are more flexible: you can
  now implicitly declare variables as the result of a tuple return, using
  `a,b,c = foo()`. For example:

  ```mojo
  def return_two(i: Int) -> (Int, Int):
    return i, i+1

  a, b = return_two(5)
  ```

  Implicit variable declarations can also now shadow global immutable symbols
  (such as module names and built-ins) without getting a compiler error.
  For example:

  ```mojo
  slice = foo()
  ```

- Mojo functions can return an auto-dereferenced reference to storage with a
  new `ref` keyword in the result type specifier.  For example:

  ```mojo
  @value
  struct Pair:
      var first: Int
      var second: Int

      fn get_first_ref(inout self) -> ref [self] Int:
          return self.first

  fn show_mutation():
      var somePair = Pair(5, 6)
      somePair.get_first_ref() = 1
    ```

  This approach provides a general way to return an "automatically dereferenced"
  reference of a given type. Notably, this eliminates the need for
  `__refitem__()` to exist.  `__refitem__()` has thus been removed and replaced
  with `__getitem__()` that returns a reference.

- Mojo added support for *infer-only parameters*. Infer-only parameters must
  appear at the beginning of the parameter list and cannot be explicitly
  specified by the user. They are declared to the left of a `//` marker, much
  like positional-only parameters. This allows programmers to define functions
  with dependent parameters to be called without the caller specifying all the
  necessary parameters. For example:

  ```mojo
  fn parameter_simd[dt: DType, //, value: Scalar[dt]]():
      print(value)

  fn call_it():
      parameter_simd[Int32(42)]()
  ```

  In the above example, `Int32(42)` is passed directly into `value`, the first
  parameter that isn't infer-only. `dt` is inferred from the parameter itself
  to be `DType.int32`.

  This also works with structs. For example:

  ```mojo
  struct ScalarContainer[dt: DType, //, value: Scalar[dt]]:
      pass

  fn foo(x: ScalarContainer[Int32(0)]): # 'dt' is inferred as `DType.int32`
      pass
  ```

  This should make working with dependent parameters more ergonomic. See
  [Infer-only parameters](/mojo/manual/parameters/#infer-only-parameters) in the
  Mojo Manual.

- Mojo now allows functions overloaded on parameters to be resolved when forming
  references to, but not calling, those functions. For example, the following
  now works:

  ```mojo
  fn overloaded_parameters[value: Int32]():
      pass

  fn overloaded_parameters[value: Float32]():
      pass

  fn form_reference():
      alias ref = overloaded_parameters[Int32()] # works!
  ```

- Mojo now supports adding a `@deprecated` decorator on structs, functions,
  traits, aliases, and global variables. The decorator marks the attached
  declaration as deprecated and causes a warning to be emitted when the
  deprecated declaration is referenced in user code. The decorator requires a
  deprecation message, specified as a string literal.

  ```mojo
  @deprecated("Foo is deprecated, use Bar instead")
  struct Foo:
      pass

  fn outdated_api(x: Foo): # warning: Foo is deprecated, use Bar instead
      pass

  @deprecated("use another function!")
  fn bar():
      pass

  fn techdebt():
      bar() # warning: use another function!
  ```

- Mojo has introduced
  [`@parameter for`](/mojo/manual/decorators/parameter#parametric-for-statement),
  a new feature for compile-time programming. `@parameter for` defines a for
  loop where the sequence and the induction values in the sequence must be
  parameter values. For example:

  ```mojo
  fn parameter_for[max: Int]():
      @parameter
      for i in range(max)
          @parameter
          if i == 10:
              print("found 10!")
  ```

  Currently, `@parameter for` requires the sequence's `__iter__()` method to
  return a `_StridedRangeIterator`, meaning the induction variables must be
  `Int`. The intention is to lift these restrictions in the future.

- The `is_mutable` parameter of `Reference` and `AnyLifetime` is now a `Bool`,
  not a low-level `__mlir_type.i1` value.

  This improves the ergonomics of spelling out a
  `Reference` type explicitly.

- Mojo will now link to a Python dynamic library based on the Python on top of
  your search path: `PATH`. This enables you to activate a virtual environment
  like `conda` and have access to Python modules installed in that environment
  without setting `MOJO_PYTHON_LIBRARY`. Previously Mojo would find a
  `libpython` dynamic library on installation and put the path in
  `.modular/modular.cfg`, which could result in version conflicts if you
  activated a virtual environment of a different Python version.

- `AnyRegType` has been renamed to `AnyTrivialRegType` and Mojo now forbids
  binding non-trivial register-passable types to `AnyTrivialRegType`. This
  closes a major safety hole in the language. Please use `AnyType` for generic
  code going forward.

- The `let` keyword has been completely removed from the language. We previously
  removed `let` declarations but still provided an error message to users. Now,
  it is completely gone from the grammar.

### Standard library changes

- New traits and related features:

  - Added built-in [`repr()`](/mojo/stdlib/builtin/repr/repr) function and
   [`Representable`](/mojo/stdlib/builtin/repr/Representable) trait.
    ([PR #2361](https://github.com/modular/modular/pull/2361))

  - Added the [`Indexer`](/mojo/stdlib/builtin/int/Indexer) trait to denote
    types that implement the `__index__()` method which allows these types to be
    accepted in common `__getitem__()` and `__setitem__()` implementations, as
    well as allow a new built-in
    [`index()`](/mojo/stdlib/builtin/int/index-function)
    function to be called on them. Most standard library containers can now be
    indexed by any type that implements `Indexer`. For example:

    ```mojo
    @value
    struct AlwaysZero(Indexer):
        fn __index__(self) -> Int:
            return 0

    struct MyList:
        var data: List[Int]

        fn __init__(inout self):
            self.data = List[Int](1, 2, 3, 4)

        fn __getitem__[T: Indexer](self, idx: T) -> Int:
            return self.data[index(idx)]

    print(MyList()[AlwaysZero()])  # prints `1`
    ```

    Types conforming to the `Indexer` trait are implicitly convertible to Int.
    This means you can write generic APIs that take `Int` instead of making them
    take a generic type that conforms to `Indexer`. For example:

    ```mojo
    @value
    struct AlwaysZero(Indexer):
        fn __index__(self) -> Int:
            return 0

    @value
    struct Incrementer:
        fn __getitem__(self, idx: Int) -> Int:
            return idx + 1

    var a = Incrementer()
    print(a[AlwaysZero()])  # works and prints 1
    ```

    ([PR #2685](https://github.com/modular/modular/pull/2685))

  - Added traits allowing user-defined types to be supported by various
    built-in and math functions.

    | Function         | Trait            | Required method |
    |------------------|------------------|-----------------|
    | [`abs()`](/mojo/stdlib/builtin/math/abs) | [`Absable`](/mojo/stdlib/builtin/math/Absable) | `__abs__()` |
    | [`pow()`](/mojo/stdlib/builtin/math/pow) | [`Powable`](/mojo/stdlib/builtin/math/Powable) | `__pow__()` |
    | [`round()`](/mojo/stdlib/builtin/math/round) | [`Roundable`](/mojo/stdlib/builtin/math/Roundable) | `__round__()` |
    | [`math.ceil`](/mojo/stdlib/math/math/ceil)    | `math.Ceilable`  | `__ceil__()`    |
    | [`math.ceildiv`](/mojo/stdlib/math/math/ceildiv) | `math.CeilDivable` <br/> `math.CeilDivableRaising` | `__ceildiv__()` |
    | [`math.floor`](/mojo/stdlib/math/math/floor)   | `math.Floorable` | `__floor__()`   |
    | [`math.trunc`](/mojo/stdlib/math/math/trunc)   | `Truncable` | `__trunc__()`   |

    Notes:

    - Conforming to the `Powable` trait also means that the type can be used
      with the power operator (`**`).

    - For `ceildiv()`, structs can conform to either the `CeilDivable` trait
      or `CeilDivableRaising` trait.

    - Due to ongoing refactoring, the traits `Ceilable`, `CeilDivable`,
      `Floorable`, and `Truncable` do not appear in the API reference. They
      should be imported from the `math` module, except for `Truncable` which
      is (temporarily) available as a built-in trait and does not need to be
      imported.

    Example:

    ```mojo
    from math import sqrt

    @value
    struct Complex2(Absable, Roundable):
        var re: Float64
        var im: Float64

        fn __abs__(self) -> Self:
            return Self(sqrt(self.re * self.re + self.im * self.im), 0.0)

        fn __round__(self) -> Self:
            return Self(round(self.re, 0), round(self.im, 0))

        fn __round__(self, ndigits: Int) -> Self:
            return Self(round(self.re, ndigits), round(self.im, ndigits))

    ```

- Benchmarking:

  - The [`bencher`](/mojo/stdlib/benchmark/bencher/) module as part of the
    `benchmark` package is now public and documented. This module provides
    types such as `Bencher` which provides the ability to execute a `Benchmark`
    and allows for benchmarking configuration via the `BenchmarkConfig` struct.

- [`String`](/mojo/stdlib/collections/string/string) and friends:

  - **Breaking.** Implicit conversion to `String` is now removed for builtin
    classes/types. Use `str()` explicitly to convert to `String`.

  - Added
    [`String.isspace()`](/mojo/stdlib/collections/string/string/String#isspace)
    method conformant with Python's universal separators. This replaces the
    `isspace()` free function from the `string` module. (If you need the old
    function, it is temporarily available as `_isspace()`. It now takes a
    `UInt8` but is otherwise unchanged.)

  - [`String.split()`](/mojo/stdlib/collections/string/string/String#split) now
    defaults to whitespace and has Pythonic behavior in that it removes all
    adjacent whitespace by default.

  - [`String.strip()`](/mojo/stdlib/collections/string/string/String#strip),
    [`lstrip()`](/mojo/stdlib/collections/string/string/String#lstrip) and
    [`rstrip()`](/mojo/stdlib/collections/string/string/String#rstrip) can now
    remove custom characters other than whitespace. In addition, there are now
    several useful aliases for whitespace, ASCII lower/uppercase, and so on.
    ([PR #2555](https://github.com/modular/modular/pull/2555))

  - `String` now has a
    [`splitlines()`](/mojo/stdlib/collections/string/string/String#splitlines)
    method, which allows splitting strings at line boundaries. This method
    supports [universal
    newlines](https://docs.python.org/3/glossary.html#term-universal-newlines)
    and provides an option to retain or remove the line break characters. ([PR
    #2810](https://github.com/modular/modular/pull/2810))

  - `InlinedString` has been renamed to
    [`InlineString`](/mojo/stdlib/collections/string/inline_string/InlineString)
    to be consistent with other types.

  - [`StringRef`](/mojo/stdlib/collections/string/string_slice/StringSlice) now
    implements
    [`strip()`](/mojo/stdlib/collections/string/string_slice/StringSlice#strip),
    which can be used to remove leading and trailing whitespace. ([PR
    #2683](https://github.com/modular/modular/pull/2683))

  - `StringRef` now implements
    [`startswith()`](/mojo/stdlib/collections/string/string_slice/StringSlice#startswith)
    and
    [`endswith()`](/mojo/stdlib/collections/string/string_slice/StringSlice#endswith).
      ([PR #2710](https://github.com/modular/modular/pull/2710))

  - Added a new
    [`StringSlice`](/mojo/stdlib/collections/string/string_slice/StringSlice)
    type, to replace uses of the unsafe `StringRef` type in standard library
    code.

    `StringSlice` is a non-owning reference to encoded string data. Unlike
    `StringRef`, a `StringSlice` is safely tied to the lifetime of the data it
    points to.

    - Added new
      [`as_string_slice()`](/mojo/stdlib/collections/string/string/String#as_string_slice)
      methods to `String` and `StringLiteral`.
    - Added `StringSlice` initializer from an `UnsafePointer` and a length in
      bytes.

  - Added a new
    [`as_bytes_slice()`](/mojo/stdlib/collections/string/string/String#as_bytes_slice)
    method to `String` and `StringLiteral`, which returns a `Span` of the bytes
    owned by the string.

  - Continued transition to
    [`UnsafePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer) and
    unsigned byte type for strings:
    - Renamed `String._as_ptr()` to
      [`String.unsafe_ptr()`](/mojo/stdlib/collections/string/string/String#unsafe_ptr),
      and changed return type to `UnsafePointer` (was `DTypePointer`).
    - Renamed `StringLiteral.data()` to
      [`StringLiteral.unsafe_ptr()`](/mojo/stdlib/builtin/string_literal/StringLiteral#unsafe_ptr),
      and changed return type to `UnsafePointer` (was `DTypePointer`).
    - `InlineString.as_ptr()` has been renamed to
      [`unsafe_ptr()`](/mojo/stdlib/collections/string/inline_string/InlineString#unsafe_ptr)
      and now returns an `UnsafePointer[UInt8]` (was
      `DTypePointer[DType.int8]`).
    - `StringRef.data` is now an `UnsafePointer` (was `DTypePointer`) and
      [`StringRef.unsafe_ptr()`](/mojo/stdlib/collections/string/string_slice/StringSlice#unsafe_ptr)
      now returns an `UnsafePointer[UInt8]` (was `DTypePointer[DType.int8]`).

- Other built-ins:

  - The `Slice.__len__()` function has been removed and
    [`Slice`](/mojo/stdlib/builtin/builtin_slice/Slice) no longer conforms
    to the `Sized` trait. This clarifies the ambiguity of the semantics: the
    length of a slice always depends on the length of the object being sliced.
    Users that need the existing functionality can use the
    [`Slice.unsafe_indices()`](/mojo/stdlib/builtin/builtin_slice/Slice#indices)
    method. This makes it explicit that this implementation does not check if
    the slice bounds are concrete or within any given object's length.

  - Added a built-in [`sort()`](/mojo/stdlib/builtin/sort/sort) function for
    lists of elements that conform to the
    [`ComparableCollectionElement`](/mojo/stdlib/builtin/value/ComparableCollectionElement)
    trait.([PR #2609](https://github.com/modular/modular/pull/2609))

  - `int()` can now take a string and a
    specified base to parse an integer from a
    string: `int("ff", 16)` returns `255`. Additionally, if a base of zero is
    specified, the string will be parsed as if it was an integer literal, with
    the base determined by whether the string contains the prefix `"0x"`,
    `"0o"`, or `"0b"`.
    ([PR #2273](https://github.com/modular/modular/pull/2273),
    fixes [#2274](https://github.com/modular/modular/issues/2274))

  - Added the [`bin()`](/mojo/stdlib/builtin/format_int/bin) built-in function
    to convert integral types into their binary
    string representation.
    ([PR #2603](https://github.com/modular/modular/pull/2603))

  - Added the [`atof()`](/mojo/stdlib/collections/string/string/atof) built-in
    function, which can convert a `String` to a `float64`. ([PR
    #2649](https://github.com/modular/modular/pull/2649))

  - You can now use the built-in [`any()`](/mojo/stdlib/builtin/bool/any) and
    [`all()`](/mojo/stdlib/builtin/bool/all) functions to check for truthy
    elements in a collection. Because `SIMD.__bool__()` is now constrained to
    `size=1`, You must explicitly use these to get the truthy value of a SIMD
    vector with more than one element. This avoids common bugs around implicit
    conversion of `SIMD` to `Bool`.
    ([PR #2600](https://github.com/modular/modular/pull/2600))

    For example:

    ```mojo
      fn truthy_simd():
          var vec = SIMD[DType.int32, 4](0, 1, 2, 3)
          if any(vec):
              print("any elements are truthy")
          if all(vec):
              print("all elements are truthy")
    ```

  - `object` now implements all the bitwise
    operators.
    ([PR #2324](https://github.com/modular/modular/pull/2324))

  - [`Tuple`](/mojo/stdlib/builtin/tuple/Tuple) now supports `__contains__()`.
    ([PR #2709](https://github.com/modular/modular/pull/2709)) For example:

    ```mojo
    var x = Tuple(1, 2, True)
    if 1 in x:
        print("x contains 1")
    ```

  - `ListLiteral` and `Tuple`
    now only require that element types be `Movable`. Consequently,
    `ListLiteral` and `Tuple` are themselves no longer `Copyable`.

  - Added new `ImmutableStaticLifetime` and `MutableStaticLifetime` helpers.

- [`UnsafePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer) and
  others:

  - Added new [`memcpy()`](/mojo/stdlib/memory/memory/memcpy) overload for
    `UnsafePointer[Scalar[_]]` pointers.

  - Removed the `get_null()` method from `UnsafePointer` and other pointer
    types. Please use the default constructor instead: `UnsafePointer[T]()`.

  - Many functions returning a pointer type have been unified to have a public
    API function of `unsafe_ptr()`.

  - The `Tensor.data()` method has been renamed to `unsafe_ptr()`. The return
    type is still a `DTypePointer[T]`.

- Collections:

  - [`List`](/mojo/stdlib/collections/list/List) now has an
    [`index()`](/mojo/stdlib/collections/list/List#index) method that allows you
    to find the (first) location of an element in a `List` of
    `EqualityComparable` types. For example:

    ```mojo
    var my_list = List[Int](2, 3, 5, 7, 3)
    print(my_list.index(3))  # prints 1
    ```

  - `List` can now be converted to a `String` with a simplified syntax:

    ```mojo
    var my_list = List[Int](2, 3)
    print(my_list.__str__())  # prints [2, 3]
    ```

    Note that `List` doesn't conform to the `Stringable` trait yet so you cannot
    use `str(my_list)` yet.
      ([PR #2673](https://github.com/modular/modular/pull/2673))

  - `List` has a simplified syntax to call the
    [`count()`](/mojo/stdlib/collections/list/List#count) method:
    `my_list.count(x)`.
    ([PR #2675](https://github.com/modular/modular/pull/2675))

  - `List()` now supports `__contains__()`, so you can now use lists with the
    `in` operator:

    ```mojo
    if x in my_list:
    ```

    ([PR #2667](https://github.com/modular/modular/pull/2667))

  - `List` now has an
    [`unsafe_get()`](/mojo/stdlib/collections/list/List#unsafe_get) to get the
    reference to an element without bounds check or wraparound for negative
    indices. Note that this method is unsafe. Use with caution.
    [PR #2800](https://github.com/modular/modular/pull/2800)

  - Added a [`fromkeys()`](/mojo/stdlib/collections/dict/Dict#fromkeys) method
    to `Dict` to return a `Dict` with the specified keys and values.
    ([PR 2622](https://github.com/modular/modular/pull/2622))

  - Added a [`clear()`](/mojo/stdlib/collections/dict/Dict#clear) method  to
    `Dict`. ([PR 2627](https://github.com/modular/modular/pull/2627))

  - `Dict` now supports [`reversed()`](/mojo/stdlib/builtin/reversed/reversed)
    for its `items()` and `values()` iterators.
    ([PR #2340](https://github.com/modular/modular/pull/2340))

  - `Dict` now has a simplified conversion to `String` with `my_dict.__str__()`.
    Note that `Dict` does not conform to the `Stringable` trait so
    `str(my_dict)` is not possible yet.
    ([PR #2674](https://github.com/modular/modular/pull/2674))

  - `Dict` now implements [`get(key)`](/mojo/stdlib/collections/dict/Dict#get)
    and `get(key, default)` functions.
    ([PR #2519](https://github.com/modular/modular/pull/2519))

  - Added a temporary `__get_ref(key)` method to `Dict`, allowing you to get a
    `Reference` to a dictionary value.

  - Added a new
    [`InlineList`](/mojo/stdlib/collections/inline_array/InlineArray) type, a
    stack-allocated list with a static maximum size. ([PR
    2587#](https://github.com/modular/modular/pull/2587))
      ([PR #2703](https://github.com/modular/modular/pull/2703))

  - Added a new [`Span`](/mojo/stdlib/memory/span/Span) type for taking slices
    of contiguous collections. ([PR
    #2595](https://github.com/modular/modular/pull/2595))

- [`os`](/mojo/stdlib/os/os/) module:

  - The `os` module now provides functionality for adding and removing
    directories using [`mkdir()`](/mojo/stdlib/os/os/mkdir) and
    [`rmdir()`](/mojo/stdlib/os/os/rmdir).
    ([PR #2430](https://github.com/modular/modular/pull/2430))

  - Added the [`os.path.getsize()`](/mojo/stdlib/os/path/path/getsize) function,
    which gives the size in bytes of the file identified by the path.
    ([PR 2626](https://github.com/modular/modular/pull/2626))

  - Added [`os.path.join()`](/mojo/stdlib/os/path/path/join) function.
    ([PR 2792](https://github.com/modular/modular/pull/2792))

  - Added a new [`tempfile`](/mojo/stdlib/tempfile/tempfile/) module, with
    `gettempdir()` and `mkdtemp()` functions.
    ([PR 2742](https://github.com/modular/modular/pull/2742))

- [`SIMD`](/mojo/stdlib/builtin/simd/SIMD) type:

  - Added [`SIMD.shuffle()`](/mojo/stdlib/builtin/simd/SIMD#shuffle) with
    `IndexList` mask.
    ([PR #2315](https://github.com/modular/modular/pull/2315))

  - [`SIMD.__bool__()`](/mojo/stdlib/builtin/simd/SIMD#__bool__) is constrained
    such that it only works when `size` is `1`. For SIMD vectors with more than
    one element, use [`any()`](/mojo/stdlib/builtin/bool/any) or
    [`all()`](/mojo/stdlib/builtin/bool/all).
    ([PR #2502](https://github.com/modular/modular/pull/2502))

  - The [`SIMD.reduce_or()`](/mojo/stdlib/builtin/simd/SIMD#reduce_or) and
    [`SIMD.reduce_and()`](/mojo/stdlib/builtin/simd/SIMD#reduce_and) methods are
    now bitwise operations, and support integer types.
    ([PR #2671](https://github.com/modular/modular/pull/2671))

  - Added [`SIMD.__repr__()`](/mojo/stdlib/builtin/simd/SIMD#__repr__) to get
    the verbose string representation of `SIMD` types.
    ([PR #2728](https://github.com/modular/modular/pull/2728))

- [`math`](/mojo/stdlib/math/math/) package:

  - The `math.bit` module has been moved to a new top-level
    [`bit`](/mojo/stdlib/bit/bit/) module. The following functions in this
    module have been renamed:
    - `ctlz` -> `countl_zero`
    - `cttz` -> `countr_zero`
    - `bit_length` -> `bit_width`
    - `ctpop` -> `pop_count`
    - `bswap` -> `byte_swap`
    - `bitreverse` -> `bit_reverse`

  - The `math.rotate_bits_left()` and `math.rotate_bits_right()` functions have
    been moved to the `bit` module.

  - The `is_power_of_2()` function in the `math` module is now called
    `is_power_of_two()` and located in the `bit` module.

  - The `abs()`, `round()`, `min()`, `max()`, `pow()`, and `divmod()` functions
    have moved from `math` to `builtin`, so you no longer need to import these
    functions.

  - The `math.tgamma()` function has been renamed to
    [`math.gamma()`](/mojo/stdlib/math/math/gamma) to conform with Python's
    naming.

  - The implementation of the following functions have been moved from the
    `math` module to the new [`utils.numerics`](/mojo/stdlib/utils/numerics/)
    module: `isfinite()`, `isinf()`, `isnan()`, `nan()`, `nextafter()`, and
    `ulp()`. The functions continue to be exposed in the `math` module.

  - [`math.gcd()`](/mojo/stdlib/math/math/gcd) now works on negative inputs, and
    like Python's implementation, accepts a variadic list of integers. New
    overloads for a `List` or `Span`of integers are also added.
    ([PR #2777](https://github.com/modular/modular/pull/2777))

- Async and coroutines:

  - [`Coroutine`](/mojo/stdlib/builtin/coroutine/Coroutine) now requires a
    lifetime parameter. This parameter is set automatically by the parser when
    calling an async function. It contains the lifetimes of all the arguments
    and any lifetime accesses by the arguments. This ensures that argument
    captures by async functions keep the arguments alive as long as the
    coroutine is alive.

  - Async function calls are no longer allowed to borrow non-trivial
    register-passable types. Because async functions capture their arguments but
    register-passable types don't have lifetimes (yet), Mojo is not able to
    correctly track the reference, making this unsafe. To cover this safety gap,
    Mojo has temporarily disallowed binding non-trivial register-passable types
    to borrowed arguments in async functions.

- Miscellaneous:

  - Added an [`InlineArray`](/mojo/stdlib/collections/inline_array/InlineArray)
    type that works on memory-only types. Compare with the existing
    [`StaticTuple`](/mojo/stdlib/utils/static_tuple/StaticTuple) type, which is
    conceptually an array type, but only works on `AnyTrivialRegType`. ([PR
    #2294](https://github.com/modular/modular/pull/2294))

  - The [`base64`](/mojo/stdlib/base64/) package now includes encoding and
    decoding support for both the Base64 and Base16 encoding schemes.
    ([PR #2364](https://github.com/modular/modular/pull/2364))
    ([PR #2584](https://github.com/modular/modular/pull/2584))

  - The `take()` function in [`Variant`](/mojo/stdlib/utils/variant/Variant) and
    [`Optional`](/mojo/stdlib/collections/optional/Optional) has been renamed to
    `unsafe_take()`.

  - The `get()` function in `Variant` has been replaced by `__getitem__()`. That
    is, `v.get[T]()` should be replaced with `v[T]`.

  - Various functions in the `algorithm` module are now built-in functions. This
    includes `sort()`, `swap()`, and `partition()`. `swap()` and `partition()`
    will likely shuffle around as we're reworking our built-in `sort()` function
    and optimizing it.

- `infinity` and `NaN` are now correctly handled in
  [`testing.assert_almost_equal()`](/mojo/stdlib/testing/testing/assert_almost_equal)
  and  an `inf` function  has been added to `utils/numerics.mojo`.
  ([PR #2375](https://github.com/modular/modular/pull/2375))

### Tooling changes

- Invoking `mojo package my-package -o my-dir` on the command line, where
  `my-package` is a Mojo package source directory, and `my-dir` is an existing
  directory, now outputs a Mojo package to `my-dir/my-package.mojopkg`.
  Previously, this had to be spelled out, as in `-o my-dir/my-package.mojopkg`.

- The Mojo Language Server now reports a warning when a local variable is
  unused.

- Several `mojo` subcommands now support a `--diagnostic-format` option that
  changes the format with which errors, warnings, and other diagnostics are
  printed. By specifying `--diagnostic-format json` on the command line, errors
  and other diagnostics will be output in a structured
  [JSON Lines](https://jsonlines.org) format that is easier for machines to
  parse.

  The full list of subcommands that support `--diagnostic-format` is as follows:
  `mojo build`, `mojo doc`, `mojo run`, `mojo package`, and `mojo test`.
  Further, the `mojo test --json` option has been subsumed into this new option;
  for the same behavior, run `mojo test --diagnostic-format json`.

  Note that the format of the JSON output may change; we don't currently
  guarantee its stability across releases of Mojo.

- A new `--validate-doc-strings` option has been added to `mojo` to emit errors
  on invalid doc strings instead of warnings.

- The `--warn-missing-doc-strings` flag for `mojo` has been renamed to
  `--diagnose-missing-doc-strings`.

- A new decorator, `@doc_private`, was added that can be used to hide a
  declaration from being generated in the output of `mojo doc`. It also removes
  the requirement that the declaration has documentation (for example, when used
  with `--diagnose-missing-doc-strings`).

- Debugger users can now set breakpoints on function calls in O0 builds even if
  the call has been inlined by the compiler.

- The Mojo Language Server now supports renaming local variables.

### Other changes

#### ❌ Removed

- The `@unroll` decorator has been deprecated and removed. The decorator was
  supposed to guarantee that a decorated loop would be unrolled, or else the
  compiler would error. In practice, this guarantee was eroded over time, as
  a compiler-based approach cannot be as robust as the Mojo parameter system.
  In addition, the `@unroll` decorator did not make the loop induction variables
  parameter values, limiting its usefulness. Please see `@parameter for` for a
  replacement!

- The method `object.print()` has been removed. Since `object` now conforms to
  the `Stringable` trait, you can use `print(my_object)` instead.

- The following functions have been removed from the math module:
  - `clamp()`; use the new `SIMD.clamp()` method instead.
  - `round_half_down()` and `round_half_up()`; these can be trivially
    implemented using the `ceil()` and `floor()` functions.
  - `add()`, `sub()`, `mul()`, `div()`, `mod()`, `greater()`, `greater_equal()`,
    `less()`, `less_equal()`, `equal()`, `not_equal()`, `logical_and()`,
    `logical_xor()`, and `logical_not()`; Instead, users should rely directly on
    the corresponding operators (`+`, `-`, `*`, `/`, `%`, `>`, `>=`, `<`, `<=`,
     `==`, `!=`, `&`, `^`, and `~`).
  - `identity()` and `reciprocal()`; users can implement these trivially.
  - `select()`; removed in favor of using `SIMD.select()` directly.
  - `is_even()` and `is_odd()`; these can be trivially implemented using bitwise
    `&` with `1`.
  - `roundeven()`; the new `SIMD.roundeven()` method now provides the identical
    functionality.
  - `div_ceil()`; use the new `ceildiv()` function.
  - `rotate_left()` and `rotate_right()`; the same functionality is available in
    the builtin `SIMD.rotate_{left,right}()` methods for `SIMD` types, and the
    `bit.rotate_bits_{left,right})()` methods for `Int`.
  - An overload of `math.pow()` taking an integer parameter exponent.
  - `align_down_residual()`; it can be trivially implemented using
    `align_down()`.
  - `all_true()`, `any_true()`, and `none_true()`; use `SIMD.reduce_and()` and
    `SIMD.reduce_or()` directly.
  - `reduce_bit_count()`; use the new `SIMD.reduce_bit_count()` directly.
  - `rint()` and `nearbyint()`; use `round()` or `SIMD.roundeven()` as
     appropriate.

- The `EvaluationMethod` has been removed from `math.polynomial` and Estrin's
  method is no longer available. This method was limited to degree 10 or less,
  underutilized, and its performance unclear. In the future, this might be
  reintroduced with an improved implementation if needed, when better
  performance benchmarking infrastructure is available. The default behavior of
  `math.polynomial.polynomial_evaluate()` is unchanged (Horner's method).

- The `math.bit.select()` and `math.bit.bit_and()` functions have been removed.
  The same functionality is available in the builtin `SIMD.select` and
  `SIMD.__and__()` methods, respectively.

- The `math.limit` module has been removed. The same functionality is available
  as follows:
  - `math.limit.inf()`: use `utils.numerics.max_or_inf()`
  - `math.limit.neginf()`: use `utils.numerics.min_or_neg_inf()`
  - `math.limit.max_finite()`: use `utils.numerics.max_finite()`
  - `math.limit.min_finite()`: use `utils.numerics.min_finite()`

- The `tensor.random` module has been removed. The same functionality is now
  accessible via the [`Tensor.rand()`](/max/api/mojo/tensor/tensor/Tensor/#rand)
  and [`Tensor.randn()`](/max/api/mojo/tensor/tensor/Tensor/#randn) static
  methods.

- The builtin `SIMD` struct no longer conforms to `Indexer`; users must
  explicitly cast `Scalar` values using `int`.

#### 🛠️ Fixed

- [#1837](https://github.com/modular/modular/issues/1837) Fix self-referential
  variant crashing the compiler.
- [#2363](https://github.com/modular/modular/issues/2363) Fix LSP crashing on
  simple trait definitions.
- [#1787](https://github.com/modular/modular/issues/1787) Fix error when using
  `//` on `FloatLiteral` in alias expression.
- Made several improvements to dictionary performance. Dicts with integer keys
  are most heavily affected, but large dicts and dicts with large values
  will also see large improvements.
- [#2692](https://github.com/modular/modular/issues/2692) Fix `assert_raises`
  to include calling location.

### Special thanks

Special thanks to our community contributors:

[@rd4com](https://github.com/rd4com),
[@toiletsandpaper](https://github.com/toiletsandpaper),
[@helehex](https://github.com/helehex),
[@artemiogr97](https://github.com/artemiogr97),
[@mikowals](https://github.com/mikowals),
[@kernhanda](https://github.com/kernhanda), [@lsh](https://github.com/lsh),
@LJ-9801,
[@YichengDWu](https://github.com/YichengDWu),
[@gabrieldemarmiesse](https://github.com/gabrieldemarmiesse),
[@fknfilewalker](https://github.com/fknfilewalker),
[@jayzhan211](https://github.com/jayzhan211),
[@martinvuyk](https://github.com/martinvuyk),
[@ChristopherLR](https://github.com/ChristopherLR),
[@mzaks](https://github.com/mzaks), [@bgreni](https://github.com/bgreni),
[@Brian-M-J](https://github.com/Brian-M-J),
[@leandrolcampos](https://github.com/leandrolcampos)

## v24.3 (2024-05-02)

### ✨ Highlights

- `AnyPointer` was renamed to
  [`UnsafePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer) and is now
  Mojo's preferred unsafe pointer type.  It has several enhancements, including:

  - The element type can now be any type: it doesn't require `Movable`.

  - Because of this, the `take_value()`, `emplace_value()`, and `move_into()`
    methods have been changed to top-level functions and renamed. The new
    functions are:

    - [`initialize_pointee_copy`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#init_pointee_copy)
    - [`initialize_pointee_move`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#init_pointee_move)
    - [`move_from_pointee()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#take_pointee)
    - [`move_pointee`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#move_pointee_into)

  - A new
    [`destroy_pointee()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#destroy_pointee)
    function runs the destructor on the pointee.

  - `UnsafePointer` can be initialized directly from a `Reference` with
    `UnsafePointer(someRef)` and can convert to a reference with
    `yourPointer[]`. Both infer element type and address space. Note that when
    you convert a pointer to a reference, there's no way for Mojo to track the
    lifetime of the original value. So the resulting reference is no safer than
    the original pointer.

- All of the pointer types received some cleanup to make them more consistent,
  for example the `unsafe.bitcast()` global function is now a consistent
  [`bitcast()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#bitcast) method
  on the pointers, which can convert element type and address space.

- Improvements to variadic arguments support.

  - Heterogeneous variadic pack arguments now work reliably even with memory
    types, and have a more convenient API to use, as defined by the
    [`VariadicPack`](/mojo/stdlib/builtin/variadics/VariadicPack) type. For
    example, a simplified version of `print` can be implemented like this:

    ```mojo
    fn print[T: Stringable, *Ts: Stringable](first: T, *rest: *Ts):
        print_string(str(first))

        @parameter
        fn print_elt[T: Stringable](a: T):
            print_string(" ")
            print_string(a)
        rest.each[print_elt]()
    ```

  - Mojo now supports declaring functions that have both optional and variadic
    arguments, both positional and keyword-only. For example, this now works:

    ```mojo
    fn variadic_arg_after_default(
      a: Int, b: Int = 3, *args: Int, c: Int, d: Int = 1, **kwargs: Int
    ): ...
    ```

    Positional variadic parameters also work in the presence of optional
    parameters. That is:

    ```mojo
    fn variadic_param_after_default[e: Int, f: Int = 2, *params: Int]():
      pass
    ```

    Note that variadic keyword parameters are not supported yet.

  For more information, see
  [Variadic arguments](/mojo/manual/functions#variadic-arguments) in the Mojo
  Manual.

- The `mojo build` and `mojo run` commands now support a `-g` option. This
  shorter alias is equivalent to writing `--debug-level full`. This option is
  also available in the `mojo debug` command, but is already the default.

- Many new standard library APIs have been filled in, including many community
  contributions. Changes are listed in the standard library section.

- The Mojo Manual has a new page on [Types](/mojo/manual/types).

### Language changes

- Certain dunder methods that take indices
  (`__getitem__()`, `__setitem__()`, and `__refitem__()`) or names
  (`__getattr__()` and `__setattr__()`) can now take the index or name
  as a parameter value instead of an argument value.  This is enabled when you
  define one of these methods with no argument other than `self` (for a getter)
  or `self` and the set value (for a setter).

  This enables types that can only be subscripted into with parameters, as well
  as things like the following example, which passes the attribute name as a
  parameter so that attribute names can be checked at compile time.

  ```mojo
  struct RGB:
     fn __getattr__[name: StringLiteral](self) -> Int:
         @parameter
         if name == "r":   return ...
         elif name == "g": return ...
         else:
             constrained[name == "b", "can only access with r, g, or b members"]()
             return ...

  var rgb = RGB()
  print(rgb.b) # Works
  print(rgb.q) # Compile error
  ```

- Mojo now allows users to capture the source location of code and call location
  of functions dynamically using the `__source_location()` and
  `__call_location()` functions. For example:

  ```mojo
  from builtin._location import __call_location

  @always_inline
  fn my_assert(cond: Bool, msg: String):
      if not cond:
        var call_loc = __call_location()
        print("In", call_loc.file_name, "on line", str(call_loc.line) + ":", msg)

  fn main():
      my_assert(False, "always fails")  # some_file.mojo, line 193
  ```

  This prints "`In /path/to/some_file.mojo on line 193: always fails`".
  Note that `__call_location()` only works in `@always_inline` or
  `@always_inline("nodebug")` functions. It gives incorrect results if placed in
  an `@always_inline` function that's called *from* an
  `@always_inline("nodebug")` function.

  This feature is still evolving and for the time being you need to explicitly
  import these APIs, as shown above. In the future, these will probably be
  built-in functions and not require an import statement.

  Neither `__source_location()` nor `__call_location()` work when called in a
  parameter context. For example:

  ```mojo
  from builtin._location import __call_location

  @always_inline
  fn mystery_location() -> String:
      var loc = __call_location()
      return str(loc.file_name)

  def main():
      alias doesnt_work = mystery_location() # <unknown location in parameter context>
  ```

### Standard library changes

#### ⭐️ New

- [`List`](/mojo/stdlib/collections/list/List) has several new methods:

  - `pop(index)` for removing an element at a particular index.
    By default, `List.pop()` removes the last element in the list.
    (@LJ-9801, fixes
    [#2017](https://github.com/modular/modular/issues/2017))

  - `resize(new_size)` for resizing the list without the need to
    specify an additional value.
    ([@mikowals](https://github.com/mikowals), fixes
    [#2133](https://github.com/modular/modular/issues/2133))

  - `insert(index, value)` for inserting a value at a specified index
    into the `List`. ([@whym1here](https://github.com/whym1here), fixes
    [#2134](https://github.com/modular/modular/issues/2134))

  - A new constructor `List(ptr, size, capacity)` to to avoid needing to
    do a deep copy of an existing contiguous memory allocation when constructing
    a new `List`. ([@StandinKP](https://github.com/StandinKP), fixes
    [#2170](https://github.com/modular/modular/issues/2170))

- [`Dict`](/mojo/stdlib/collections/dict/Dict) now has a `update()` method to
  update keys/values from another `Dict`.
  ([@gabrieldemarmiesse](https://github.com/gabrieldemarmiesse))

- [`Set`](/mojo/stdlib/collections/set/Set) now has named methods for set
  operations:
  - `difference()` mapping to `-`
  - `difference_update()` mapping to `-=`
  - `intersection_update()` mapping to `&=`
  - `update()` mapping to `|=`

  ([@arvindavoudi](https://github.com/arvindavoudi))

- `Dict`, `List`, and `Set` all conform to the `Boolable` trait. The collections
  evaluate to `True` if they contain any elements, `False` otherwise:

  ```mojo
  def list_names(names: List[String]):
      if names:
          for name in names:
              print(name[])
      else:
          print("No names to list.")
  ```

  ([@gabrieldemarmiesse](https://github.com/gabrieldemarmiesse))

- Added [`reversed()`](/mojo/stdlib/builtin/reversed/reversed) function for
  creating reversed iterators. Several range types, `List`, and `Dict` now
  support iterating in reverse.

  ```mojo
  var numbers = List(1, 2, 3, 4, 5)
  for number in reversed(numbers):
      print(number)
  ```

  ([@helehex](https://github.com/helehex) and
  [@jayzhan211](https://github.com/jayzhan211), contributes towards
  [#2325](https://github.com/modular/modular/issues/2325))

- [`Optional`](/mojo/stdlib/collections/optional/Optional) now implements
  `__is__` and `__isnot__` methods so that you can compare an `Optional` with
  `None`. For example:

  ```mojo
  var opt = Optional(1)
  if opt is not None:
      print(opt.value()[])
  ```

  ([@gabrieldemarmiesse](https://github.com/gabrieldemarmiesse))

- [`Tuple`](/mojo/stdlib/builtin/tuple/Tuple) now works with memory-only element
  types like `String` and allows you to directly index into it with a parameter
  expression.  This means you can now simply use `x = tup[1]` like Python
  instead of `x = tup.get[1, Int]()`. You can also assign into tuple elements
  now as well with `tup[1] = x`.

  ```mojo
  var tuple = ("Green", 9.3)
  var name = tuple[0]
  var value = tuple[1]
  ```

  Note that because the subscript must be a parameter expression, you can't
  iterate through a `Tuple` using an ordinary `for` loop.

- The `Reference` type has several
  changes, including:

  - It has moved to the `memory.reference` module instead of `memory.unsafe`.
  - `Reference` now has an
    [`unsafe_bitcast()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#bitcast)
    method, similar to the pointer types.

  - Several unsafe methods were removed, including `offset()`,
    `destroy_element_unsafe()` and `emplace_ref_unsafe()`. This is because
    `Reference` is a safe type—use `UnsafePointer` to do unsafe operations.

- [`Bool`](/mojo/stdlib/builtin/bool/Bool) can now be implicitly converted from
  any type conforming to the [`Boolable`](/mojo/stdlib/builtin/bool/Boolable)
  trait. This means that you no longer need to write code like this:

  ```mojo
  @value
  struct MyBoolable:
    fn __bool__(self) -> Bool: ...

  fn takes_boolable[T: Boolable](cond: T): ...

  takes_boolable(MyBoolable())
  ```

  Instead, you can simply write:

  ```mojo
  fn takes_bool(cond: Bool): ...

  takes_bool(MyBoolable())
  ```

  Note that calls to `takes_bool()` will perform the implicit conversion, so in
  some cases is it still better to explicitly declare a type parameter, e.g.:

  ```mojo
  fn takes_two_boolables[T: Boolable](a: T, b: T):
    # Short circuit means `b.__bool__()` might not be evaluated.
    if a.__bool__() and b.__bool__():
      ...
  ```

- [`PythonObject`](/mojo/stdlib/python/python_object/PythonObject) now conforms
  to the [`KeyElement`](/mojo/stdlib/collections/dict/#keyelement) trait, meaning
  that it can be used as key type for
  [`Dict`](/mojo/stdlib/collections/dict/Dict). This allows you to easily build
  and interact with Python dictionaries in Mojo:

  ```mojo
  def main():
      d = PythonObject(Dict[PythonObject, PythonObject]())
      d["foo"] = 12
      d[7] = "bar"
      d["foo"] = [1, 2, "something else"]
      print(d)  # prints `{'foo': [1, 2, 'something else'], 7: 'bar'}`
  ```

- [`FileHandle.seek()`](/mojo/stdlib/builtin/file/FileHandle#seek) now has a
  `whence` argument that defaults to `os.SEEK_SET` to seek from the beginning of
  the file. You can now set to `os.SEEK_CUR` to offset by the current
  `FileHandle` seek position:

  ```mojo
  var f = open("/tmp/example.txt")
  # Skip 32 bytes
  f.seek(os.SEEK_CUR, 32)
  ```

  Or `os.SEEK_END` to offset from the end of file:

  ```mojo
  # Start from 32 bytes before the end of the file
  f.seek(os.SEEK_END, -32)
  ```

- [`FileHandle.read()`](/mojo/stdlib/builtin/file/FileHandle#read) can now
  read straight into a
  [`DTypePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer):

  ```mojo
  var file = open("/tmp/example.txt", "r")

  # Allocate and load 8 elements
  var ptr = DTypePointer[DType.float32].alloc(8)
  var bytes = file.read(ptr, 8)
  print("bytes read", bytes)
  print(ptr.load[width=8]())
  ```

- The `sys` module now contains an `exit()` function that would exit a Mojo
  program with the specified error code.

  ```mojo
  from sys import exit

  exit(0)
  ```

- The constructors for [`Tensor`](/max/api/mojo/tensor/tensor/Tensor) have been
  changed to be more consistent. As a result, constructors take the shape as the
  first argument (instead of the second) when constructing a tensor with pointer
  data.

  If you pass a single scalar value to the `Tensor` constructor, it now
  broadcasts the value to all elements in the tensor. For example,
  `Tensor[DType.float32](TensorShape(2,2), 0)` constructs a `2x2` tensor
  initialized with all zeros. This provides an easy way to fill in the data of a
  tensor.

- [`String`](/mojo/stdlib/collections/string/string/String) now has
  `removeprefix()` and `removesuffix()` methods.
  ([@gabrieldemarmiesse](https://github.com/gabrieldemarmiesse))

- The [`ord`](/mojo/stdlib/collections/string/string/ord) and
  [`chr`](/mojo/stdlib/collections/string/string/chr) functions have been
  improved to accept any Unicode character. ([@mzaks](https://github.com/mzaks),
  contributes towards [#1616](https://github.com/modular/modular/issues/1616))

- [`atol()`](/mojo/stdlib/collections/string/string/atol) now handles
  whitespace. The `atol()`function is used internally by `String.__int__()`, so
  `int(String( " 10 "))` now returns `10` instead of raising an error.
  ([@artemiogr97](https://github.com/artemiogr97))

- [`SIMD`](/mojo/stdlib/builtin/simd/SIMD) now implements the `__rmod__()`
  method. ([@bgreni](https://github.com/bgreni), fixes
  [#1482](https://github.com/modular/modular/issues/1482))

- [`bool(None)`](/mojo/stdlib/builtin/bool/bool-function) is now implemented.
  ([@zhoujingya](https://github.com/zhoujingya))

- The [`DTypePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer) type
  now implements `gather()` for gathering a `SIMD` vector from offsets of a
  current pointer. Similarly, support for `scatter()` was added to scatter a
  `SIMD` vector into offsets of the current pointer.
  ([@leandrolcampos](https://github.com/leandrolcampos))

- The [`len()`](/mojo/stdlib/builtin/len/len) function now handles a
  [`range()`](/mojo/stdlib/builtin/range/range) specified with a negative end
  value, so that things like `len(range(-1))` work correctly.
  ([@soraros](https://github.com/soraros))

- [`debug_assert()`](/mojo/stdlib/builtin/debug_assert/debug_assert) now prints
  its location (filename, line, and column where it was called) in its error
  message. Similarly, the `assert` helpers in the
  [`testing`](/mojo/stdlib/testing/testing/) module now include location
  information in their messages.

- The
  [`testing.assert_equal[SIMD]()`](/mojo/stdlib/testing/testing/assert_equal)
  function now raises if any of the elements mismatch in the two `SIMD`
  arguments being compared.
  ([@gabrieldemarmiesse](https://github.com/gabrieldemarmiesse))

- The
  [`testing.assert_almost_equal()`](/mojo/stdlib/testing/testing/assert_almost_equal)
  and [`math.isclose()`](/mojo/stdlib/math/math/isclose) functions now have an
  `equal_nan` flag. When set to `True`, then NaNs are considered equal.

- The `object` type now supports the
  division, modulo, and left and right shift operators, including the in-place
  and reverse variants.
  (@LJ-9801, fixes
  [#2224](https://github.com/modular/modular/issues/2224))

- Added checked arithmetic operations for `SIMD` integers.

  `SIMD` integer types (including the sized integer scalars like `Int64`) can
  now perform checked additions, subtractions, and multiplications using the
  following new methods:

  - `add_with_overflow()`
  - `sub_with_overflow()`
  - `mul_with_overflow()`

  Checked arithmetic allows the caller to determine if an operation exceeded
  the numeric limits of the type. For example:

  ```mojo
  var simd = SIMD[DType.int8, 4](7, 11, 13, 17)
  var product: SIMD[DType.int8, 4]
  var overflow: SIMD[DType.bool, 4]
  (product, overflow) = simd.mul_with_overflow(simd)
  for i in range(len(product)):
    if overflow[i]:
            print("<overflow>")
        else:
            print(product[i])
  ```

  ([@lsh](https://github.com/lsh))

- Added [`os.remove()`](/mojo/stdlib/os/os/remove) and
  [`os.unlink()`](/mojo/stdlib/os/os/unlink) for deleting files.
  ([@artemiogr97](https://github.com/artemiogr97), fixes
  [#2306](https://github.com/modular/modular/issues/2306))

#### 🦋 Changed

- The [`parallel_memcpy()`](/mojo/stdlib/algorithm/memory/parallel_memcpy)
  function has moved from the `buffer` package to the `algorithm` package.
  Please update your imports accordingly.

- [`Optional.value()`](/mojo/stdlib/collections/optional/Optional#value) now
  returns a reference instead of a copy of the contained value.

  To perform a copy manually, dereference the result:

  ```mojo
  var result = Optional(123)

  var value = result.value()[]
  ```

  ([@lsh](https://github.com/lsh), fixes
  [#2179](https://github.com/modular/modular/issues/2179))

- Per the accepted community proposal, [Standardize the representation of byte
sequence as a sequence of unsigned 8-bit
integers](https://github.com/modular/modular/blob/main/mojo/proposals/byte-as-uint8.md),
began transition to using `UInt8` by changing the data pointer of `Error` to
`DTypePointer[DType.uint8]`.
([@gabrieldemarmiesse](https://github.com/gabrieldemarmiesse), contributes
towards [#2317](https://github.com/modular/modular/issues/2317))

- Continued transition to `UnsafePointer` from the legacy `Pointer` type
  in various standard library APIs and internals.
  ([@gabrieldemarmiesse](https://github.com/gabrieldemarmiesse))

### Tooling changes

- The behavior of `mojo build` when invoked without an output `-o` argument has
  changed slightly: `mojo build ./test-dir/program.mojo` now outputs an
  executable to the path `./program`, whereas before it would output to the path
  `./test-dir/program`.

- The `mojo package` command no longer supports the `-D` flag. All compilation
  environment flags should be provided at the point of package use (e.g.
  `mojo run` or `mojo build`).

- The REPL no longer allows type level variable declarations to be
  uninitialized, e.g. it will reject `var s: String`.  This is because it does
  not do proper lifetime tracking (yet!) across cells, and so such code would
  lead to a crash.  You can work around this by initializing to a dummy value
  and overwriting later.  This limitation only applies to top level variables,
  variables in functions work as they always have.

### Other changes

#### Low-level language changes

- A low-level `__get_mvalue_as_litref(x)` builtin was added to give access to
  the underlying memory representation as a `!lit.ref` value without checking
  initialization status of the underlying value. This is useful in very
  low-level logic but isn't designed for general usability and will likely
  change in the future.

- Properties can now be specified on inline MLIR ops:

  ```mojo
  _ = __mlir_op.`kgen.source_loc`[
      _type = (
          __mlir_type.index, __mlir_type.index, __mlir_type.`!kgen.string`
      ),
      _properties = __mlir_attr.`{inlineCount = 1 : i64}`,
  ]()
  ```

  As the example shows above, the protected `_properties` attribute can be
  passed during op construction, with an MLIR `DictionaryAttr` value.

#### ❌ Removed

- Support for "register only" variadic packs has been removed. Instead of
  `AnyRegType`, please upgrade your code to `AnyType` in examples like this:

  ```mojo
  fn your_function[*Types: AnyRegType](*args: *Ts): ...
  ```

  This move gives you access to a nicer API and has the benefit of being memory
  safe and correct for non-trivial types.  If you need specific APIs on the
  types, please use the correct trait instead of `AnyType`.

- `List.pop_back()` has been removed.  Use `List.pop()` instead which defaults
  to popping the last element in the list.

- `SIMD.to_int(value)` has been removed.  Use `int(value)` instead.

- The `__get_lvalue_as_address(x)` magic function has been removed.  To get a
  reference to a value use `Reference(x)` and if you need an unsafe pointer, you
  can use `UnsafePointer.address_of(x)`.

#### 🛠️ Fixed

- [#516](https://github.com/modular/modular/issues/516) and
  [#1817](https://github.com/modular/modular/issues/1817) and many others, e.g.
  "Can't create a function that returns two strings."

- [#1178](https://github.com/modular/modular/issues/1178) (os/kern) failure (5).

- [#1609](https://github.com/modular/modular/issues/1609) alias with
  `DynamicVector[Tuple[Int]]` fails.

- [#1987](https://github.com/modular/modular/issues/1987) Defining `main`
  in a Mojo package is an error, for now. This is not intended to work yet,
  erroring for now will help to prevent accidental undefined behavior.

- [#1215](https://github.com/modular/modular/issues/1215) and
  [#1949](https://github.com/modular/modular/issues/1949) The Mojo LSP server no
  longer cuts off hover previews for functions with functional arguments,
  parameters, or results.

- [#1901](https://github.com/modular/modular/issues/1901) Fixed Mojo LSP and
  documentation generation handling of inout arguments.

- [#1913](https://github.com/modular/modular/issues/1913) - `0__` no longer
  crashes the Mojo parser.

- [#1924](https://github.com/modular/modular/issues/1924) JIT debugging on Mac
  has been fixed.

- [#1941](https://github.com/modular/modular/issues/1941) Mojo variadic arguments
  don't work with non-trivial register-only types.

- [#1963](https://github.com/modular/modular/issues/1963) `a!=0` is now parsed
  and formatted correctly by `mojo format`.

- [#1676](https://github.com/modular/modular/issues/1676) Fix a crash related to
  `@value` decorator and structs with empty body.

- [#1917](https://github.com/modular/modular/issues/1917) Fix a crash after
  syntax error during tuple creation.

- [#2006](https://github.com/modular/modular/issues/2006) The Mojo LSP now
  properly supports signature types with named arguments and parameters.

- [#2007](https://github.com/modular/modular/issues/2007) and
  [#1997](https://github.com/modular/modular/issues/1997) The Mojo LSP no longer
  crashes on certain types of closures.

- [#1675](https://github.com/modular/modular/issues/1675) Ensure `@value`
  decorator fails gracefully after duplicate field error.

- [#2068](https://github.com/modular/modular/issues/2068)
  Fix `SIMD.reduce()` for size_out == 2.
  ([@soraros](https://github.com/soraros))

## v24.2.1 (2024-04-11)

This release doesn't include any changes to Mojo.

## v24.2 (2024-03-28)

### 🔥 Legendary

- The Mojo standard library is now open source! Check out the
  [README](https://github.com/modular/modular/blob/main/mojo/stdlib/README.md)
  for everything you need to get started.

- Structs and other nominal types are now allowed to implicitly conform to
  traits. A struct implicitly conforms to a trait if it implements all the
  requirements for the trait. For example, any struct that implements the
  `__str__()` method implicitly conforms to `Stringable`, and is usable with
  the `str()` built-in function.

  ```mojo
  @value
  struct Foo:
      fn __str__(self) -> String:
          return "foo!"

  fn main():
      print(str(Foo())) # prints 'foo!'
  ```

  We still strongly encourage you to explicitly list the traits a struct
  conforms to when possible:

  ```mojo
  @value
  struct Foo(Stringable): ...
  ```

  Not only is this useful for documentation and for communicating intentions,
  but in the future, explicit conformance will be useful for features like
  default methods and extensions.

- Mojo's Python interoperability now supports passing keyword arguments to
  Python functions:

  ```mojo
  from python import Python

  def main():
      plt = Python.import_module("matplotlib.pyplot")
      plt.plot((5, 10), (10, 15), color="red")
      plt.show()
  ```

### Language changes

#### ⭐️ New

- Mojo now has support for variadic keyword arguments, often referred to as
  `**kwargs`. This means you can now declare and call functions like this:

  ```mojo
  fn print_nicely(**kwargs: Int) raises:
    for key in kwargs.keys():
        print(key[], "=", kwargs[key[]])

   # prints:
   # `a = 7`
   # `y = 8`
  print_nicely(a=7, y=8)
  ```

  For more details (and a list of current limitations), see [Variadic keyword
  arguments](/mojo/manual/functions#variadic-keyword-arguments) in the Mojo
  manual.

#### 🦋 Changed or removed

- `let` declarations now produce a compile time error instead of a warning,
  our next step in [removing let
  declarations](https://github.com/modular/modular/blob/main/mojo/proposals/remove-let-decls.md).
  The compiler still recognizes the `let` keyword for now in order to produce
  a good error message, but that will be removed in subsequent releases.

- Mojo now warns about unused values in both `def` and `fn` declarations,
  instead of completely disabling the warning in `def`s.  It never warns about
  unused `object` or `PythonObject` values, tying the warning to these types
  instead of the kind of function they are unused in.  This will help catch API
  usage bugs in `def`s and make imported Python APIs more ergonomic in `fn`s.

- For the time being, dynamic type values will be disabled in the language. For
  example, the following will now fail with an error:

  ```mojo
  var t = Int  # dynamic type values not allowed

  struct SomeType: ...

  takes_type(SomeType)  # dynamic type values not allowed
  ```

  We want to take a step back and (re)design type valued variables,
  existentials, and other dynamic features. This does not affect type valued
  **parameters**, so the following works as before:

  ```mojo
  alias t = Int  # still 🔥

  struct SomeType: ...

  takes_type[SomeType]()  # already 🔥

  >fn uses_trait[T: SomeTrait](value: T): ... # still 🔥
  ```

- The `*_` expression in parameter expressions is now required to occur at the
  end of a positional parameter list, instead of being allowed in the middle.

  ```mojo
  # No longer supported
  alias FirstUnbound = SomeStruct[*_, 42]
  alias MidUnbound   = SomeStruct[7, *_, 6]
  # Still supported
  alias LastUnbound  = SomeStruct[42, *_]
  ```

  We narrowed this because we want to encourage type designers
  to get the order of parameters right, and want to extend `*_` to support
  keyword parameters as well in the future.

### Standard library changes

#### ⭐️ New

- `DynamicVector` has been renamed to
  [`List`](/mojo/stdlib/collections/list/List), and has moved from the
  `collections.vector` module to the `collections.list` module. In addition:

  - You can now construct a `List` from a variadic number of values. For
    example:

    ```mojo
    var numbers = List[Int](1, 2, 3)
    ```

  - `List` and
    [`InlinedFixedVector`](/mojo/stdlib/collections/inline_array/InlineArray)
    types now support negative indexing. This means that you can write `vec[-1]`
    which is equivalent to `vec[len(vec)-1]`.

  - `List.push_back()` has been removed.  Please use the `append()` function
    instead.

- The [`print()`](/mojo/stdlib/builtin/io/print) function now takes `sep` and
  `end` keyword arguments. This means that you can write:

  ```mojo
  print("Hello", "Mojo", sep=", ", end="!!!\n") # prints Hello, Mojo!!!
  ```

  `sep` defaults to the empty string and `end` defaults to "\n".

  Also, the `print_no_newline()` function has been removed.  Please use
  `print(end="")` instead.

- The [`FloatLiteral`](/mojo/stdlib/builtin/float_literal/FloatLiteral) type is
  now an infinite-precision nonmaterializable type. This means you can do
  compile-time calculations using `FloatLiteral` without rounding errors. When
  materialized at runtime, a `FloatLiteral` value is converted to a
  [`Float64`](/mojo/stdlib/builtin/simd).

  ```mojo
  # third is an infinite-precision FloatLiteral value
  alias third = 1.0 / 3.0
  # t is a Float64
  var t = third
  ```

- String types all conform to the
  [`IntableRaising`](/mojo/stdlib/builtin/int/IntableRaising) trait. This means
  that you can now call `int("123")` to get the integer `123`. If the integer
  cannot be parsed from the string, then an error is raised.

- The `Tensor` type now has `argmax()` and `argmin()` functions to compute the
  position of the max or min value. Note: this should return a `Tensor[Int]` but
  currently the output tensor is the same type as the input tensor. This will be
  fixed in a future release.

- Added a new
  [`collections.OptionalReg`](/mojo/stdlib/collections/optional/OptionalReg)
  type, a register-passable alternative to
  [`Optional`](/mojo/stdlib/collections/optional/Optional).

- The [`ulp()`](/mojo/stdlib/utils/numerics/ulp) function has been added to the
  `math` module. This allows you to get the units of least precision (or units
  of last place) of a floating point value.

#### 🦋 Changed

- The `simd_load()`, `simd_store()`, `aligned_simd_load()`, and
  `aligned_simd_store()` methods on
  [`DTypePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer),
  [`Buffer`](/mojo/stdlib/buffer/buffer/NDBuffer), and
  [`NDBuffer`](/mojo/stdlib/buffer/buffer/NDBuffer) have been merged into
  a more expressive set of `load()` and `store()` methods with keyword-only
  `width` and `alignment` parameters:

  ```mojo
  # Doesn't work
  my_simd = my_buffer.simd_load[simd_width](index)
  # Works
  my_simd = my_buffer.load[width=simd_width](index)
  # Doesn't work
  my_buffer.aligned_simd_store[width, alignment](my_simd)
  # Works
  my_buffer.store[width=width, alignment=alignment](my_simd)
  ```

- The
  [`EqualityComparable`](/mojo/stdlib/builtin/equality_comparable/EqualityComparable)
  trait now requires the `__ne__()` method for conformance in addition to the
  previously required `__eq__()` method.

- Many types now declare conformance to `EqualityComparable` trait.

- [`StaticTuple`](/mojo/stdlib/utils/static_tuple/StaticTuple) parameter order
  has changed to `StaticTuple[type, size]` for consistency with `SIMD` and
  similar collection types.

- The signature of the
  [`elementwise()`](/mojo/stdlib/algorithm/functional/elementwise) function has
  been changed. The new order is is `function`, `simd_width`, and then `rank`.
  As a result, the rank parameter can now be inferred and one can call
  `elementwise()` without it:

  ```mojo
  elementwise[func, simd_width](shape)
  ```

- `PythonObject` is now register-passable.

- `PythonObject.__iter__()` now works correctly on more types of iterable Python
  objects. Attempting to iterate over non-iterable objects will now raise an
  exception instead of behaving as if iterating over an empty sequence.
  `__iter__()` also now borrows `self` rather than requiring `inout`, allowing
  code like:

  ```mojo
  for value in my_dict.values():
    ...
  ```

#### 🚚 Moved

- We took the opportunity to rehome some modules into their correct package
  as we were going through the process of open-sourcing the Mojo standard
  library.  Specifically, the following are some breaking changes worth
  calling out.  Please update your import statements accordingly.

  - [`Buffer`](/mojo/stdlib/buffer/buffer/NDBuffer),
    [`NDBuffer`](/mojo/stdlib/buffer/buffer/NDBuffer), and friends have moved
    from the `memory` package into a new `buffer` package.

    ```mojo
    from buffer import Buffer, NDBuffer
    ```

  - `utils.list`, including the [`Dim`](/mojo/stdlib/buffer/dimlist/Dim) and
    [`DimList`](/mojo/stdlib/buffer/dimlist/DimList) types, has moved to
    the `buffer` package.

    ```mojo
    from buffer import Dim, DimList
    ```

  - The [`parallel_memcpy()`](/mojo/stdlib/algorithm/memory/parallel_memcpy)
    function has moved from the `memory` package into the `buffer` package.

    ```mojo
    from buffer import parallel_memcpy
    ```

  - The [`rand()`](/max/api/mojo/tensor/tensor/Tensor/#rand) and
    [`randn()`](/max/api/mojo/tensor/tensor/Tensor/#randn) functions from the
    `random` package that return a `Tensor` have moved to the `tensor` package.
    Note that the overloads that write to a `DTypePointer` remain in the
    `random` package.

    If you happen to be using both versions in the same source file, you can
    import them both using the `import as` syntax:

    ```mojo
    from tensor import rand
    from random import rand as rand_dt
    ```

  - The `trap()` function has been renamed to
    [`abort()`](/mojo/stdlib/os/os/abort).  It also has moved from the `debug`
    module to the `os` module.

    ```mojo
    from os import abort
    ```

  - The [`isinf()`](/mojo/stdlib/utils/numerics/isfinite) and
    [`isfinite()`](/mojo/stdlib/utils/numerics/isfinite) methods have been moved
    from `math.limits` to the `math` module.

    ```mojo
    from math import ininf, isfinite
    ```

### Tooling changes

#### ⭐️ New

- Docstring code blocks can now use `%#` to hide lines of code from
  documentation generation.

  For example:

  ```mojo
  var value = 5
  %# print(value)
  ```

  Will generate documentation of the form:

  ```mojo
  var value = 5
  ```

  Hidden lines are processed as if they were normal code lines during test
  execution. This allows for writing additional code within a docstring
  example that is only used to ensure the example is runnable/testable.

- The Mojo LSP server now allow you to specify additional search paths to use
  when resolving imported modules in a document. You can specify search paths
  on the command line, using the `-I` option, or you can add them to the
  `mojo.lsp.includeDirs` setting in the VS Code extension.

### Other changes

#### ❌ Removed

- The `__get_address_as_lvalue` magic function has been removed.  You can now
  get an LValue from a `Pointer` or `Reference` by using the dereference
  operator (`[]`):

  ```mojo
  var ptr: Pointer[MyRecord]
  ...
  # Doesn't work
  __get_address_as_lvalue(ptr.value) = MyRecord(3, 5)
  # Works
  ptr[] = MyRecord(3, 5)
  ```

- The type parameter for the `memcpy` function is now automatically inferred.
  This means that calls to `memcpy` of the form `memcpy[Dtype.xyz](...)` will
  no longer work and the user would have to change the code to `memcpy(...)`.

- The [`memcpy()`](/mojo/stdlib/memory/memory/memcpy) overload that worked on
  [`Buffer`](/mojo/stdlib/buffer/buffer/NDBuffer) types has been removed in
  favor of just overloads for
  [`Pointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer) and
  [`DTypePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer):

  ```mojo
  # Doesn't work
  memcpy(destBuffer, srcBuffer, count)
  # Works
  memcpy(destBuffer.data, srcBuffer.data, count)
  ```

- The functions `max_or_inf()`, `min_or_neginf()` have been removed from
  `math.limit`. These functions were only used by the SIMD type.

- As mentioned previously, the `print_no_newline()` function has been removed.
  Please use `print(end="")` instead.

#### 🛠️ Fixed

- [#1362](https://github.com/modular/modular/issues/1362) - Parameter inference
  now recursively matches function types.
- [#951](https://github.com/modular/modular/issues/951) - Functions that were
  both `async` and `@always_inline` incorrectly errored.
- [#1858](https://github.com/modular/modular/issues/1858) - Trait with parametric
  methods regression.
- [#1892](https://github.com/modular/modular/issues/1892) - Forbid unsupported
  decorators on traits.
- [#1735](https://github.com/modular/modular/issues/1735) - Trait-typed values
  are incorrectly considered equal.
- [#1909](https://github.com/modular/modular/issues/1909) - Crash due to nested
  import in unreachable block.
- [#1921](https://github.com/modular/modular/issues/1921) - Parser crashes
  binding `Reference` to lvalue with subtype lifetime.
- [#1945](https://github.com/modular/modular/issues/1945) - `Optional[T].or_else()`
  should return `T` instead of `Optional[T]`.
- [#1940](https://github.com/modular/modular/issues/1940) - Constrain
  `math.copysign` to floating point or integral types.
- [#1838](https://github.com/modular/modular/issues/1838) - Variadic `print`
  does not work when specifying `end=""`
- [#1826](https://github.com/modular/modular/issues/1826) - The `SIMD.reduce`
  methods correctly handle edge cases where `size_out >= size`.

## v24.1.1 (2024-03-18)

This release includes installer improvements and enhanced error reporting for
installation issues. Otherwise it is functionally identical to Mojo 24.1.

## v24.1 (2024-02-29)

### 🔥 Legendary

- Mojo is now bundled with [the MAX platform](/max)!

  As such, the Mojo package version now matches the MAX version, which follows
  a `YY.MAJOR.MINOR` version scheme. Because this is our first release in 2024,
  that makes this version `24.1`.

- Mojo debugging support is here! The Mojo VS Code extension includes debugger
  support. For details, see [Debugging](/mojo/tools/debugging) in the Mojo
  Manual.

### ⭐️ New

- We now have a [`Set`](/mojo/stdlib/collections/set/Set) type in our
  collections! `Set` is backed by a `Dict`, so it has fast add, remove, and `in`
  checks, and requires member elements to conform to the `KeyElement` trait.

  ```mojo
  from collections import Set

  var set = Set[Int](1, 2, 3)
  print(len(set))  # 3
  set.add(4)

  for element in set:
      print(element[])

  set -= Set[Int](3, 4, 5)
  print(set == Set[Int](1, 2))  # True
  print(set | Set[Int](0, 1) == Set[Int](0, 1, 2))  # True
  let element = set.pop()
  print(len(set))  # 1
  ```

- Mojo now supports the `x in y` expression as syntax sugar for
  `y.__contains__(x)` as well as `x not in y`.

- Mojo now has support for keyword-only arguments and parameters. For example:

  ```mojo
  fn my_product(a: Int, b: Int = 1, *, c: Int, d: Int = 2):
      print(a * b * c * d)

  my_product(3, c=5)     # prints '30'
  my_product(3, 5, d=7)  # error: missing 1 required keyword-only argument: 'c'
  ```

  This includes support for declaring signatures that use both variadic and
  keyword-only arguments/parameters. For example, the following is now possible:

  ```mojo
  fn prod_with_offset(*args: Int, offset: Int = 0) -> Int:
      var res = 1
      for i in range(len(args)):
          res *= args[i]
      return res + offset

  print(prod_with_offset(2, 3, 4, 10))         # prints 240
  print(prod_with_offset(2, 3, 4, offset=10))  # prints 34
  ```

  Note that variadic keyword-only arguments/parameters (for example, `**kwargs`)
  are not supported yet. That is, the following is not allowed:

  ```mojo
  fn variadic_kw_only(a: Int, **kwargs): ...
  ```

  For more information, see
  [Positional-only and keyword-only arguments](/mojo/manual/functions#positional-only-and-keyword-only-arguments)
  in the Mojo Manual.

- The `print()` function now accepts a keyword-only argument for the `end`
  which is useful for controlling whether a newline is printed or not
  after printing the elements.  By default, `end` defaults to "\n" as before.

- The Mojo SDK can now be installed on AWS Graviton instances.

- A new version of the [Mojo
  Playground](https://developer.modular.com/playground) is available. The new
  playground is a simple interactive editor for Mojo code, similar to the Rust
  Playground or Go Playground. The old JupyterLab based playground will remain
  online until March 20th.

- The Mojo LSP server will now generate fixits for populating empty
  documentation strings:

  ```mojo
  fn foo(arg: Int):
      """""" # Unexpected empty documentation string
  ```

  Applying the fixit from above will generate:

  ```mojo
  fn foo(arg: Int):
      """[summary].

      Args:
          arg: [description].
      """
  ```

- Added new `*_` syntax that allows users to explicitly unbind any number of
  positional parameters. For example:

  ```mojo
  struct StructWithDefault[a: Int, b: Int, c: Int = 8, d: Int = 9]: pass

  alias all_unbound = StructWithDefault[*_]
  # equivalent to
  alias all_unbound = StructWithDefault[_, _, _, _]

  alias first_bound = StructWithDefault[5, *_]
  # equivalent to
  alias first_bound = StructWithDefault[5, _, _, _]

  alias last_bound = StructWithDefault[*_, 6]
  # equivalent to
  alias last_bound = StructWithDefault[_, _, _, 6]

  alias mid_unbound = StructWithDefault[3, *_, 4]
  # equivalent to
  alias mid_unbound = StructWithDefault[3, _, _, 4]
  ```

  As demonstrated above, this syntax can be used to explicitly unbind an
  arbitrary number of parameters, at the beginning, at the end, or in the
  middle of the operand list. Since these unbound parameters must be explicitly
  specified at some point, default values for these parameters are not applied.
  For example:

  ```mojo
  alias last_bound = StructWithDefault[*_, 6]
  # When using last_bound, you must specify a, b, and c. last_bound
  # doesn't have a default value for `c`.
  var s = last_bound[1, 2, 3]()
  ```

  For more information see the Mojo Manual sections on
  [partially-bound types](/mojo/manual/parameters/#fully-bound-partially-bound-and-unbound-types)
  and
  [automatic parameterization of functions](/mojo/manual/parameters/#automatic-parameterization-of-functions).

- [`DynamicVector`](/mojo/stdlib/collections/list/List) now supports iteration.
  Iteration values are instances of `Reference` and require dereferencing:

  ```mojo
  var v: DynamicVector[String]()
  v.append("Alice")
  v.append("Bob")
  v.append("Charlie")
  for x in v:
      x[] = str("Hello, ") + x[]
  for x in v:
      print(x[])
  ```

- `DynamicVector` now has
  [`reverse()`](/mojo/stdlib/collections/list/List#reverse) and
  [`extend()`](/mojo/stdlib/collections/list/List#extend) methods.

- The `mojo package` command now produces compilation agnostic packages.
  Compilation options such as O0, or --debug-level, are no longer needed or
  accepted. As a result, packages are now smaller, and extremely portable.

- Initializers for `@register_passable` values can (and should!) now be
  specified with `inout self` arguments just like memory-only types:

  ```mojo
  @register_passable
  struct YourPair:
      var a: Int
      var b: Int
      fn __init__(inout self):
          self.a = 42
          self.b = 17
      fn __copyinit__(inout self, existing: Self):
          self.a = existing.a
          self.b = existing.b
  ```

  This form makes the language more consistent, more similar to Python, and
  easier to implement advanced features for.  There is also no performance
  impact of using this new form: the compiler arranges to automatically return
  the value in a register without requiring you to worry about it.

  The older `-> Self` syntax is still supported in this release, but will be
  removed in a subsequent one, so please migrate your code.  One thing to watch
  out for: a given struct should use one style or the other, mixing some of
  each won't work well.

- The `inout self` initializer form is **required** for initializers of
  `@register_passable` types that may raise errors:

  ```mojo
  @register_passable
  struct RaisingCtor:
      fn __init__(inout self) raises:
          raise
  ```

- `async` functions that may raise errors have been temporarily disabled in this
  build. The implementation of Mojo async is undergoing a rework 🚧.

- The standard library `slice` type has been renamed to
  [`Slice`](/mojo/stdlib/builtin/builtin_slice/Slice), and a `slice`
  function has been introduced.  This makes Mojo closer to Python and makes the
  `Slice` type follow the naming conventions of other types like `Int`.

- "Slice" syntax in subscripts is no longer hard coded to the builtin `slice`
  type: it now works with any type accepted by a container's `__getitem__()`
  method. For example:

  ```mojo
  @value
  struct UnusualSlice:
      var a: Int
      var b: Float64
      var c: String

  struct YourContainer:
      fn __getitem__(self, slice: UnusualSlice) -> T: ...
  ```

  Given this implementation, you can subscript into an instance of
  `YourContainer` like `yc[42:3.14:"🔥"]` and the three values are passed to the
  `UnusualSlice` constructor.

- The `__refitem__()` accessor method may now return a `Reference` instead of
  having to return an MLIR internal reference type.

- Added [`AnyPointer.move_into()`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer#move_pointee_into)
  method, for moving a value from one pointer memory location to another.

- Added built-in [`hex()`](/mojo/stdlib/builtin/format_int/hex) function, which
  can be used to format any value whose type implements the
  [`Intable`](/mojo/stdlib/builtin/int/Intable) trait as a hexadecimal string.

- [`PythonObject`](/mojo/stdlib/python/python_object/PythonObject) now
  implements `__is__` and `__isnot__` so that you can use expressions of the
  form `x is y` and `x is not y` with `PythonObject`.

- [`PythonObject`](/mojo/stdlib/python/python_object/PythonObject) now conforms
  to the `SizedRaising` trait. This means the built-in
  [`len()`](/mojo/stdlib/builtin/len/len) function now works on `PythonObject`.

- The `os` package now contains the [`stat()`](/mojo/stdlib/os/fstat/stat)
  and [`lstat()`](/mojo/stdlib/os/fstat/lstat) functions.

- A new [`os.path`](/mojo/stdlib/os/path/path) package now allows you to query
  properties on paths.

- The `os` package now has a
  [`PathLike`](/mojo/stdlib/os/pathlike/PathLike) trait. A struct conforms
  to the `PathLike` trait by implementing the `__fspath__()` function.

- The [`pathlib.Path`](/mojo/stdlib/pathlib/path/Path) now has functions to
  query properties of the path.

- The [`listdir()`](/mojo/stdlib/pathlib/path/Path#listdir) method now exists on
  [`pathlib.Path`](/mojo/stdlib/pathlib/path) and also exists in the `os`
  module to work on `PathLike` structs. For example, the following sample
  lists all the directories in the `/tmp` directory:

  ```mojo
  from pathlib import Path

  fn walktree(top: Path, inout files: DynamicVector[Path]):
      try:
          var ls = top.listdir()
          for i in range(len(ls)):
              var child = top / ls[i]
              if child.is_dir():
                  walktree(child, files)
              elif child.is_file():
                  files.append(child)
              else:
                  print("Skipping '" + str(child) + "'")
      except:
          return

  fn main():
      var files = DynamicVector[Path]()

      walktree(Path("/tmp"), files)

      for i in range(len(files)):
          print(files[i])
  ```

- The [`find()`](/mojo/stdlib/builtin/string_literal/StringLiteral#find),
  [`rfind()`](/mojo/stdlib/builtin/string_literal/StringLiteral#rfind),
  [`count()`](/mojo/stdlib/collections/string/string_slice/StringSlice#count), and
  [`__contains__()`](/mojo/stdlib/builtin/string_literal/StringLiteral#__contains__)
  methods now work on string literals. This means that you can write:

  ```mojo
  if "Mojo" in "Hello Mojo":
      ...
  ```

- Breakpoints can now be inserted programmatically within the code using the
  builtin [`breakpoint()`](/mojo/stdlib/builtin/breakpoint/breakpoint) function.

  Note: on Graviton instances, the debugger might not be able to resume after
  hitting this kind of breakpoint.

- Added a builtin [`Boolable`](/mojo/stdlib/builtin/bool/Boolable) trait that
  describes a type that can be represented as a boolean value. To conform to the
  trait, a type must implement the `__bool__()` method.

- Modules within packages can now use purely relative `from` imports:

  ```mojo
  from . import another_module
  ```

- Trivial types, like MLIR types and function types, can now be bound implicitly
  to traits that require copy constructors or move constructors, such as
  [`Movable`](/mojo/stdlib/builtin/value/Movable),
  [`Copyable`](/mojo/stdlib/builtin/value/Copyable), and
  [`CollectionElement`](/mojo/stdlib/builtin/value/CollectionElement).

- A new magic `__origin_of(expr)` call will yield the lifetime of a memory
  value.  We hope and expect that this will eventually be replaced by
  `Reference(expr).lifetime` as the parameter system evolves, but this is
  important in the meantime for use in function signatures.

- A new magic `__type_of(expr)` call will yield the type of a value. This allows
  one to refer to types of other variables. For example:

  ```mojo
  fn my_function(x: Int, y: __type_of(x)) -> Int:
      let z: __type_of(x) = y
      return z
  ```

### 🦋 Changed

- As another step towards [removing let
  declarations](https://github.com/modular/modular/blob/main/mojo/proposals/remove-let-decls.md)
  we have removed support for let declarations inside the compiler.  To ease
  migration, we parse `let` declarations as a `var` declaration so your code
  won't break.  We emit a warning about this, but please switch your code to
  using `var` explicitly, because this migration support will be removed in a
  subsequent update.

  ```mojo
  fn test():
      # treated as a var, but please update your code!
      let x = 42  # warning: 'let' is being removed, please use 'var' instead
      x = 9
  ```

- It is no longer possible to explicitly specify implicit argument parameters in
  [automatically parameterized
  functions](/mojo/manual/parameters/#automatic-parameterization-of-functions).
  This ability was an oversight and this is now an error:

  ```mojo
  fn autoparameterized(x: SIMD):
      pass

  autoparameterized[DType.int32, 1](3) # error: too many parameters
  ```

- `vectorize_unroll` has been removed, and
  [`vectorize`](/mojo/stdlib/algorithm/functional/vectorize) now has a parameter
  named `unroll_factor` with a default value of 1. Increasing `unroll_factor`
  may improve performance at the cost of binary size. See the
  [loop unrolling blog here](https://www.modular.com/blog/what-is-loop-unrolling-how-you-can-speed-up-mojo)
  for more details.

- The `vectorize` signatures have changed with the closure `func` moved to the
  first parameter:

  ```mojo
  vectorize[func, width, unroll_factor = 1](size)
  vectorize[func, width, size, unroll_factor = 1]()
  ```

  The doc string has been updated with examples demonstrating the difference
  between the two signatures.

- The `unroll` signatures have changed with the closure `func` moved to the
  first parameter:

  ```mojo
  unroll[func, unroll_count]()
  ```

- The signature of the [`NDBuffer`](/mojo/stdlib/buffer/buffer/NDBuffer) and
  [`Buffer`](/mojo/stdlib/buffer/buffer/NDBuffer) types have changed. Now, both
  take the type as the first parameter and no longer require the shape
  parameter. This allows you to use these types and have sensible defaults.
  For example:

  ```mojo
  NDBuffer[DType.float32, 3]
  ```

  is equivalent to

  ```mojo
  NDBuffer[DType.float32, 3, DimList.create_unknown[3]()]
  ```

  Users can still specify the static shape (if known) to the type:

  ```mojo
  NDBuffer[DType.float32, 3, DimList(128, 128, 3)]
  ```

- The error message for missing function arguments is improved: instead of
  describing the number of arguments (e.g. `callee expects at least 3 arguments,
  but 1 was specified`) the missing arguments are now described by
  name (e.g. `missing 2 required positional arguments: 'b', 'c'`).

- The [`CollectionElement`](/mojo/stdlib/builtin/value/CollectionElement) trait
  is now a built-in trait and has been removed from `collections.vector`.

- The `DynamicVector(capacity: Int)` constructor has been changed to take
  `capacity` as a keyword-only argument to prevent implicit conversion from
  `Int`.

- [`Variant.get[T]()`](/mojo/stdlib/utils/variant/Variant#__getitem__) now
  returns a `Reference` to the value rather than a copy.

- The [`String`](/mojo/stdlib/collections/string/string/String) methods `tolower()`
  and `toupper()` have been renamed to `str.lower()` and `str.upper()`.

- The `ref` and `mutref` identifiers are no longer reserved as Mojo keywords.
We originally thought about using those as language sugar for references, but
we believe that generic language features combined with the
[`Reference`](/mojo/stdlib/memory/pointer/Pointer) type will provide a good
experience without dedicated sugar.

### 🛠️ Fixed

- [#435](https://github.com/modular/modular/issues/435)
  Structs with Self type don't always work.
- [#1540](https://github.com/modular/modular/issues/1540)
  Crash in register_passable self referencing struct.
- [#1664](https://github.com/modular/modular/issues/1664) - Improve error
  message when `StaticTuple` is constructed with a negative size for
  the number of elements.
- [#1679](https://github.com/modular/modular/issues/1679) - crash on SIMD of zero
  elements.
- Various crashes on invalid code:
  [#1230](https://github.com/modular/modular/issues/1230),
  [#1699](https://github.com/modular/modular/issues/1699),
  [#1708](https://github.com/modular/modular/issues/1708)
- [#1223](https://github.com/modular/modular/issues/1223) - Crash when parametric
  function is passed as (runtime) argument. The parser now errors out instead.
- [#1530](https://github.com/modular/modular/issues/1530) - Crash during
  diagnostic emission for parameter deduction failure.
- [#1538](https://github.com/modular/modular/issues/1538) and [#1607](
  https://github.com/modular/modular/issues/1607) - Crash when returning type
  value instead of instance of expected type. This is a common mistake and the
  error now includes a hint to point users to the problem.
- [#1613](https://github.com/modular/modular/issues/1613) - Wrong type name in
  error for incorrect `self` argument type in trait method declaration.
- [#1670](https://github.com/modular/modular/issues/1670) - Crash on implicit
  conversion in a global variable declaration.
- [#1741](https://github.com/modular/modular/issues/1741) - Mojo documentation
  generation doesn't show `inout`/`owned` on variadic arguments.
- [#1621](https://github.com/modular/modular/issues/1621) - VS Code does not
  highlight `raises` and `capturing` in functional type expressions.
- [#1617](https://github.com/modular/modular/issues/1617) - VS Code does not
  highlight `fn` in specific contexts.
- [#1740](https://github.com/modular/modular/issues/1740) - LSP shows unrelated
  info when hovering over a struct.
- [#1238](https://github.com/modular/modular/issues/1238) - File shadows Mojo
  package path.
- [#1429](https://github.com/modular/modular/issues/1429) - Crash when using
  nested import statement.
- [#1322](https://github.com/modular/modular/issues/1322) - Crash when missing
  types in variadic argument.
- [#1314](https://github.com/modular/modular/issues/1314) - Typecheck error when
  binding alias to parametric function with default argument.
- [#1248](https://github.com/modular/modular/issues/1248) - Crash when importing
  from file the same name as another file in the search path.
- [#1354](https://github.com/modular/modular/issues/1354) - Crash when importing
  from local package.
- [#1488](https://github.com/modular/modular/issues/1488) - Crash when setting
  generic element field.
- [#1476](https://github.com/modular/modular/issues/1476) - Crash in interpreter
  when calling functions in parameter context.
- [#1537](https://github.com/modular/modular/issues/1537) - Crash when copying
  parameter value.
- [#1546](https://github.com/modular/modular/issues/1546) - Modify nested vector
  element crashes parser.
- [#1558](https://github.com/modular/modular/issues/1558) - Invalid import causes
  parser to crash.
- [#1562](https://github.com/modular/modular/issues/1562) - Crash when calling
  parametric type member function.
- [#1577](https://github.com/modular/modular/issues/1577) - Crash when using
  unresolved package as a variable.
- [#1579](https://github.com/modular/modular/issues/1579) - Member access into
  type instances causes a crash.
- [#1602](https://github.com/modular/modular/issues/1602) - Interpreter failure
  when constructing strings at compile time.
- [#1696](https://github.com/modular/modular/issues/1696) - Fixed an issue that
  caused syntax highlighting to occasionally fail.
- [#1549](https://github.com/modular/modular/issues/1549) - Fixed an issue when
  the shift amount is out of range in `SIMD.shift_left` and `SIMD.shift_right`.

## v0.7.0 (2024-01-25)

### ⭐️ New

- A new Mojo-native dictionary type,
  [`Dict`](/mojo/stdlib/collections/dict) for storing key-value pairs.
  `Dict` stores values that conform to the
  [`CollectionElement`](/mojo/stdlib/builtin/value/CollectionElement)
  trait. Keys need to conform to the new
  [`KeyElement`](/mojo/stdlib/collections/dict/#keyelement) trait, which is
  not yet implemented by other standard library types. In the short term, you
  can create your own wrapper types to use as keys. For example, the following
  sample defines a `StringKey` type and uses it to create a dictionary that maps
  strings to `Int` values:

  ```mojo
  from collections.dict import Dict, KeyElement

  @value
  struct StringKey(KeyElement):
      var s: String

      fn __init__(inout self, owned s: String):
          self.s = s ^

      fn __init__(inout self, s: StringLiteral):
          self.s = String(s)

      fn __hash__(self) -> Int:
          return hash(self.s)

      fn __eq__(self, other: Self) -> Bool:
          return self.s == other.s

  fn main() raises:
      var d = Dict[StringKey, Int]()
      d["cats"] = 1
      d["dogs"] = 2
      print(len(d))         # prints 2
      print(d["cats"])      # prints 1
      print(d.pop("dogs"))  # prints 2
      print(len(d))         # prints 1
  ```

  We plan to add `KeyElement` conformance to standard library types in
  subsequent releases.

- Users can opt-in to assertions used in the standard library code by
  specifying `-D MOJO_ENABLE_ASSERTIONS` when invoking `mojo` to
  compile your source file(s).  In the case that an assertion is fired,
  the assertion message will be printed along with the stack trace
  before the program exits.  By default, assertions are *not enabled*
  in the standard library right now for performance reasons.

- The Mojo Language Server now implements the References request. IDEs use
  this to provide support for **Go to References** and **Find All References**.
  A current limitation is that references outside of the current document are
  not supported, which will be addressed in the future.

- The [`sys.info`](/mojo/stdlib/sys/info) module now includes
  `num_physical_cores()`, `num_logical_cores()`, and `num_performance_cores()`
  functions.

- Homogeneous variadic arguments consisting of memory-only types, such as
  `String` are more powerful and easier to use. These arguments are projected
  into a
  [`VariadicListMem`](/mojo/stdlib/builtin/variadics/VariadicListMem).

  (Previous releases made it easier to use variadic lists of register-passable
  types, like `Int`.)

  Subscripting into a `VariadicListMem` now returns the element instead of an
  obscure internal type. In addition, we now support `inout` and `owned`
  variadic arguments:

  ```mojo
  fn make_worldly(inout *strs: String):
      # This "just works" as you'd expect!
      for i in range(len(strs)):
          strs[i] += " world"
  fn main():
      var s1: String = "hello"
      var s2: String = "konnichiwa"
      var s3: String = "bonjour"
      make_worldly(s1, s2, s3)
      print(s1)  # hello world
      print(s2)  # konnichiwa world
      print(s3)  # bonjour world
  ```

  (Previous releases made it easier to use variadic lists, but subscripting into
  a `VariadicListMem` returned a low-level pointer, which required the user to
  call `__get_address_as_lvalue()` to access the element.)

  Note that subscripting the variadic list works nicely as above, but iterating
  over the variadic list directly with a `for` loop produces a `Reference`
  (described below) instead of the desired value, so an extra subscript is
  required; We intend to fix this in the future.

  ```mojo
  fn make_worldly(inout *strs: String):
      # Requires extra [] to dereference the reference for now.
      for i in strs:
          i[] += " world"
  ```

  Heterogeneous variadic arguments have not yet been moved to the new model, but
  will in future updates.

  Note that for variadic arguments of register-passable types like `Int`, the
  variadic list contains values, not references, so the dereference operator
  (`[]`) is not required. This code continues to work as it did previously:

  ```mojo
  fn print_ints(*nums: Int):
      for num in nums:
          print(num)
      print(len(nums))
  ```

- Mojo now has a prototype version of a safe
  [`Reference`](/mojo/stdlib/memory/pointer/Pointer) type. The compiler's
  lifetime tracking pass can reason about references to safely extend local
  variable lifetime, and check indirect access safety.  The `Reference` type
  is brand new (and currently has no syntactic sugar) so it must be explicitly
  dereferenced with an empty subscript: `ref[]` provides access to the
  underlying value.

  ```mojo
  fn main():
      var a: String = "hello"
      var b: String = " references"

      var aref = Reference(a)
      aref[] += b
      print(a)  # prints "hello references"

      aref[] += b
      # ^last use of b, it is destroyed here.

      print(aref[]) # prints "hello references references"
      # ^last use of a, it is destroyed here.
  ```

  While the `Reference` type has the same in-memory representation as a C
  pointer or the Mojo `Pointer` type, it also tracks a symbolic "lifetime" value
  so the compiler can reason about the potentially accessed set of values.  This
  lifetime is part of the static type of the reference, so it propagates through
  generic algorithms and abstractions built around it.

  The `Reference` type can form references to both mutable and immutable memory
  objects, e.g. those on the stack or borrowed/inout/owned function arguments.
  It is fully parametric over mutability, eliminating the [problems with code
  duplication due to mutability
  specifiers](https://duckki.github.io/2024/01/01/inferred-mutability.html) and
  provides the base for unified user-level types. For example, it could be
  used to implement an array slice object that handles both mutable and
  immutable array slices.

  While this is a major step forward for the lifetimes system in Mojo, it is
  still *very* early and awkward to use.  Notably, there is no syntactic sugar
  for using references, such as automatic dereferencing. Several aspects of it
  need to be more baked. It is getting exercised by variadic memory arguments,
  which is why they are starting to behave better now.

  Note: the safe `Reference` type and the unsafe pointer types are defined in
  the same module, currently named `memory.unsafe`. We expect to restructure
  this module in a future release.

- Mojo now allows types to implement `__refattr__()` and `__refitem__()` to
  enable attribute and subscript syntax with computed accessors that return
  references. For common situations where these address a value in memory this
  provides a more convenient and significantly more performant alternative to
  implementing the traditional get/set pairs.  Note: this may be changed in the
  future when references auto-dereference—at that point we may switch to just
  returning a reference from `__getattr__()`.
- Parametric closures can now capture register passable typed values by copy
  using the `__copy_capture` decorator. For example, the following code will
  print `5`, not `2`.

  ```mojo
  fn foo(x: Int):
      var z = x

      @__copy_capture(z)
      @parameter
      fn formatter() -> Int:
          return z
      z = 2
      print(formatter())

  fn main():
      foo(5)
  ```

- String now implements KeyElement and may be used as a key in Dict.
- More robust support for structs with fields of self referencing types.
  For example, the following code will work and print `0`:

  ```mojo
  struct Foo(CollectionElement):
      var vec: DynamicVector[Self]

      fn __init__(inout self: Self):
          self.vec = DynamicVector[Self]()

      fn __moveinit__(inout self: Self, owned existing: Self):
          self.vec = existing.vec ^

      fn __copyinit__(inout self: Self, existing: Self):
          self.vec = existing.vec

  fn main():
      var foo = Foo()
      print(len(foo.vec))
  ```

### ❌ Removed

- The `__takeinit__` special constructor form has been removed from the
  language.  This "non-destructive move" operation was previously wired into the
  `x^` transfer operator, but had unpredictable behavior that wasn't consistent.
  Now that Mojo has traits, it is better to model this as an explicit `.take()`
  operation on a type, which would transfer out the contents of the type without
  ending its lifetime. For example, for a type that holds a pointer, `take()`
  might return a new instance pointing to the same data, and null out its own
  internal pointer.

  This change makes it clear when a lifetime is ended versus when the
  contents of an LValue are explicitly taken.

- The current implementation of autotuning has been deprecated, as Mojo's
  autotuning implementation is undergoing a redesign. Tutorials around the
  current implementation have also been removed as they are being rewritten.

  Consequently, the `autotune()`, `autotune_fork()`, and `search()` functions
  have been removed from the standard library.

- The `_OldDynamicVector` type that worked only on register passable element
  types has been removed.  Please migrate uses to
  [`DynamicVector`](/mojo/stdlib/collections/list/List) which
  works on both register passable and memory types.

- The `UnsafeFixedVector` in `utils.vector` has been removed. We recommend using
  either [`DynamicVector`](/mojo/stdlib/collections/list/List)
  or [`InlinedFixedVector`](/mojo/stdlib/collections/inline_array/InlineArray)
  instead.

- The `@adaptive` decorator has been removed from the language. Any uses of the
  decorator in a non-search context can be replaced with `@parameter if`. For
  example:

  ```mojo
  @adaptive
  fn foo[a: Bool]():
      constrained[a]()
      body1()

  @adaptive
  fn foo[a: Bool]():
      constrained[not a]()
      body2()
  ```

  Can be rewritten as:

  ```mojo
  fn foo[a: Bool]():
      @parameter
      if a:
          body1()
      else:
          body2()
  ```

  Consequently, the special `__adaptive_set` attribute has been removed as well.

- Result parameters have been removed from Mojo. Result parameter declarations
  in function parameter lists are no longer allowed, nor are forward alias
  declarations. This includes removing the `param_return` statement.

- The `@noncapturing` and `@closure` decorators have been removed due to
  refinements and improvements to the closure model. See below for more details!

### 🦋 Changed

- The Mojo closure model has been refined to be more straightforward and safe.
  Mojo has two closure types: parameter closures and runtime closures. Parameter
  closures can be used in higher-order functions and are the backbone of
  functions like `vectorize` and `parallelize`. They are always denoted by
  `@parameter` and have type `fn() capturing -> T` (where `T` is the return
  type).

  On the other hand, runtime closures are always dynamic values, capture values
  by invoking their copy constructor, and retain ownership of their capture
  state. You can define a runtime closure by writing a nested function that
  captures values:

  ```mojo
  fn outer(b: Bool, x: String) -> fn() escaping -> None:
      fn closure():
          print(x) # 'x' is captured by calling String.__copyinit__

      fn bare_function():
          print("hello") # nothing is captured

      if b:
          # closure can be safely returned because it owns its state
          return closure^

      # function pointers can be converted to runtime closures
      return bare_function
  ```

  The type of runtime closures are of the form `fn() escaping -> T`. You
  can pass equivalent function pointers as runtime closures.

  Stay tuned for capture list syntax for move capture and capture by reference,
  and a more unified closure model!

- The `@unroll(n)` decorator can now take a parameter expression for
  the unroll factor, i.e. `n` can be a parameter expression that is
  of integer type.

- The `cpython` module in the `python` package has been moved to be an internal
  module, i.e, `_cpython`.

- `AnyType` and `Destructable` have been unified into a single trait, `AnyType`.
  Every nominal type (i.e. all structs) now automatically conform to `AnyType`.

- Previously, the `mojo package` command would output a Mojo package that
  included both partly-compiled Mojo code, as well as fully-compiled machine
  code for a specific computer architecture -- the architecture of the machine
  being used to invoke the `mojo package` command.

  Now, `mojo package` only includes partly-compiled Mojo code. It is only fully
  compiled for the specific computer architecture being used at the point that
  the package is first `import`-ed. As a result, Mojo packages are smaller and
  more portable.

- The `simd_width` and `dtype` parameters of `polynomial_evaluate` have been
  switched. Based on the request in
  [#1587](https://github.com/modular/modular/issues/1587), the
  `polynomial_evaluate` function has also been extended so that the
  `coefficients` parameter can take either a either a
  [`StaticTuple`](/mojo/stdlib/utils/static_tuple/StaticTuple) or a
  [`VariadicList`](/mojo/stdlib/builtin/variadics/VariadicList).

- As a tiny step towards removing `let` declarations, this release removes the
  warning: `'var' was never mutated, consider switching to a 'let'`.

### 🛠️ Fixed

- [#1595](https://github.com/modular/modular/issues/1595) - Improve error message
  when trying to materialize `IntLiteral` in runtime code.
- Raising an error from the initializer of a memory-only type now works
  correctly in the presence of complex control flow.  Previously Mojo could run
  the destructor on `self` before it was initialized when exiting with an
  error.
- [#1096](https://github.com/modular/modular/issues/1096) - Improve warning
  messages for dead code in conditionals like `or` expressions.
- [#1419](https://github.com/modular/modular/issues/1419) - Fix assertion failure
  with uninitialized lattice values.
- [#1402](https://github.com/modular/modular/issues/1402) - Fix movable trait not
  detected on recursive struct implemented with `AnyPointer`.
- [#1399](https://github.com/modular/modular/issues/1399) - Fix parser crash when
  a parameter type in a struct that implements a trait is misspelled.
- [#1152](https://github.com/modular/modular/issues/1152) - Allow mutable `self`
  argument when overloading operators using dunder methods.
- [#1493](https://github.com/modular/modular/issues/1493) - Fix crash in
  `DynamicVector` copy constructor in certain situations.
- [#1316](https://github.com/modular/modular/issues/1316) - The `benchmark.keep`
  function now properly handles vector types.
- [#1505](https://github.com/modular/modular/issues/1505) - The `simd.shuffle`
  operation now works on 64 element permutations.
- [#1355](https://github.com/modular/modular/issues/1355) - Fix `String.find()`
  returning wrong value when starting index is non-zero.
- [#1367](https://github.com/modular/modular/issues/1367) - Fix `String.replace()`
  returning incorrect results for multi-character search strings.
- [#1535](https://github.com/modular/modular/issues/1535) - Invalid error `field
  'w.x.y' destroyed out of the middle of a value, preventing the overall value
  from being destroyed`.
- [#1475](https://github.com/modular/modular/issues/1475) - Assertion failure in
  nested loop.
- [#1591](https://github.com/modular/modular/issues/1591) - Assertion failure
  when using `AnyType` struct member.
- [#1503](https://github.com/modular/modular/issues/1503) - Rename the mojo build
  of LLDB to `mojo-lldb`, to prevent name collisions with the system's LLDB.
- [#1542](https://github.com/modular/modular/issues/1542) - `@unroll` does not
  accept alias as unroll factor.
- [#1443](https://github.com/modular/modular/issues/1443) - Compiler crash on
  variadic list of traits.
- [#1604](https://github.com/modular/modular/issues/1604) - Variable of trivial
  type not destroyed by transferring ownership.
- [#1341](https://github.com/modular/modular/issues/1341) - Segmentation fault
  when passing closures around.
- [#217](https://github.com/modular/modular/issues/217) - Closure state is
  stack allocated.

## v0.6.1 (2023-12-18)

### ⭐️ New

- The Mojo REPL now provides limited support for the `%cd` magic command.

  This command automatically maintains an internal stack of directories you
  visit during the REPL session. Usage:

  - `%cd 'dir'`: change to directory `dir` and push it on the directory stack.
  - `%cd -`: pop the directory stack and change to the last visited directory.

- Structs decorated with `@value` now automatically conform to the
  [`Movable`](/mojo/stdlib/builtin/value/Movable)
  and [`Copyable`](/mojo/stdlib/builtin/value/Copyable) built-in traits.

- [`String`](/mojo/stdlib/collections/string/string/String) now has new
  [`toupper()`](/mojo/stdlib/collections/string/string/String#upper) and
  [`tolower()`](/mojo/stdlib/collections/string/string/String#lower) methods analogous,
  respectively, to Python's `str.toupper()` and `str.tolower()`.

- Added a [`hash()`](/mojo/stdlib/hashlib/hash/hash) built-in function and
  [`Hashable`](/mojo/stdlib/hashlib/hash/Hashable) trait for types
  implementing the `__hash__()` method. Future releases will add `Hashable`
  support to Standard Library types. In the meantime, the `hash` module includes
  a version of the `hash()` function that works on arbitrary byte strings. To
  generate hashes for [`SIMD`](/mojo/stdlib/builtin/simd/SIMD) types, you
  use the internal `_hash_simd()` function:

  ```mojo
  from builtin.hash import _hash_simd

  fn gen_simd_hash():
      let vector = SIMD[DType.int64, 4](1, 2, 3, 4)
      let hash = _hash_simd(vector)
  ```

- Several standard library types now conform to the
  [`CollectionElement`](/mojo/stdlib/builtin/value/CollectionElement)
  trait.  These types include [`Bool`](/mojo/stdlib/builtin/bool/Bool),
  [`StringLiteral`](/mojo/stdlib/builtin/string_literal/StringLiteral),
  [`DynamicVector`](/mojo/stdlib/collections/list/List),
  [`Tensor`](/max/api/mojo/tensor/tensor/Tensor),
  [`TensorShape`](/max/api/mojo/tensor/tensor_shape/TensorShape),
  and [`TensorSpec`](/max/api/mojo/tensor/tensor_spec/TensorSpec).

### 🦋 Changed

- `utils.vector` has been moved to a new `collections` package to make
  space for new collections. This means that if you had previous code
  that did `from utils.vector import DynamicVector`, it now needs to
  be `from collections.vector import DynamicVector` due to the move.

- The special destructor method `__del__()` has been changed to enforce
  that it cannot raise an error. Raising destructors are not supported properly
  at the moment.

### 🛠️ Fixed

- [#1421](https://github.com/modular/modular/issues/1421) - Fixed a crash when
  using Tuples in the REPL.

- [#222](https://github.com/modular/modular/issues/222) - Generate an error
  for obviously self recursive functions.

- [#1408](https://github.com/modular/modular/issues/1408) - Fix overload
  resolution when candidates can return generic types.

- [#1413](https://github.com/modular/modular/issues/1413) and
  [#1395](https://github.com/modular/modular/issues/1395) - Do not crash when
  re-declaring a builtin declaration.

- [#1307](https://github.com/modular/modular/issues/1307) - Fix compatibility of
  function signatures that only differ in default argument values.

- [#1380](https://github.com/modular/modular/issues/1380) - Fix printing
  of empty `String`.

## v0.6.0 (2023-12-04)

### 🔥 Legendary

- Traits have arrived!

  You can now define a *trait*, which consists of a required set of method
  prototypes. A struct can *conform to* the trait by implementing these methods.
  This lets you write generic functions that work on any structs that conform to
  a given trait.

  The following section gives a brief overview of traits—see the
  [Mojo Manual](/mojo/manual/traits) and this
  [traits blog post](https://modul.ar/traits-blog) for more details!

  Traits are declared with the `trait` keyword. The bodies of traits should
  contain method signatures declared with `...` as their bodies. Default
  method implementations are not supported yet.

  ```mojo
  trait SomeTrait:
      fn required_method(self, x: Int): ...
  ```

  The trait can be implemented on a struct by inheriting from it.

  ```mojo
  struct SomeStruct(SomeTrait):
      fn required_method(self, x: Int):
          print("hello traits", x)
  ```

  You can then write a generic functions that accepts any type that conforms to
  the trait. You do this by creating a parameterized function with a
  trait-typed parameter:

  ```mojo
  fn fun_with_traits[T: SomeTrait](x: T):
      x.required_method(42)
  ```

  Which can be invoked with instances of types that conform to the trait:

  ```mojo
  var thing = SomeStruct()
  # Infer the parameter `T`!
  fun_with_traits(thing)
  ```

  Traits can also inherit from other traits, which simply requires that
  implementers of the child trait also conform to all parent traits.

  ```mojo
  trait Parent:
      fn parent_func(self): ...

  trait Child(Parent):
      fn child_func(self): ...
  ```

  Then, both child and parent trait methods can be invoked on instances of
  the trait `Child`. As well, an instance of the child trait can be converted to
  an instance of the parent trait.

  ```mojo
  fn the_parents[T: Parent](x: T):
      x.parent_func()

  fn the_children[T: Child](x: T):
      x.child_func()
      x.parent_func()
      # Upcast `x` from instance of `Child` to `Parent`.
      the_parents(x)
  ```

  For more information, see the [Traits page](/mojo/manual/traits)
  in the Mojo Manual.

- A fundamental `Destructable` trait has been added to the language. This is a
  core trait that every trait automatically conforms to. This enables
  destruction of generic types and generic collections.

  **Note:** We're aware that this trait might be better spelled `Destructible`.
  We're planning on removing it in the future and moving its functionality to
  `AnyType` so that any type that doesn't provide its own destructor will have
  a default, no-op destructor.

- We've added some traits to the standard library, you can implement these on
  your own types:

  - [`Destructable`](/mojo/stdlib/builtin/anytype/AnyType)
  - [`Copyable`](/mojo/stdlib/builtin/value/Copyable)
  - [`Movable`](/mojo/stdlib/builtin/value/Movable)
  - [`Stringable`](/mojo/stdlib/builtin/str/Stringable)
  - [`Intable`](/mojo/stdlib/builtin/int/Intable)
  - [`Sized`](/mojo/stdlib/builtin/len/Sized)
  - [`CollectionElement`](/mojo/stdlib/builtin/value/CollectionElement)

- We added built-in [`len()`](/mojo/stdlib/builtin/len/len), `str()`, and
  `int()` functions, which work with types that implement the `Sized`,
  `Stringable`, and `Intable` traits, respectively.

- [`DynamicVector`](/mojo/stdlib/collections/list/List) is now a
  proper generic collection that can use any type that implements the `Movable`
  and `Copyable` traits. This means you can now write, for example,
  `DynamicVector[String]`. Also, `DynamicVector` now invokes its element
  destructors upon destruction, so `_del_old` has been deleted.

- `print` now works on any types that implement `Stringable` by invoking their
  `__str__` method:

  ```mojo
  @value
  struct BoxedInt(Stringable):
      var value: Int

      fn __str__(self) -> String:
          return self.value

  print(BoxedInt(11), "hello traits!", BoxedInt(42))
  ```

### ⭐️ New

- The [Mojo Manual](/mojo/manual/) is an all-new, complete Mojo user guide.
  It doesn't include *everything* about Mojo yet, but it includes a lot,
  and more than the original programming
  manual (now deprecated).

  Plus, the entire Mojo Manual and other Mojo docs are now [open-sourced on
  GitHub](https://github.com/modular/modular/tree/main/mojo/docs), and we'd love
  to accept contributions to help us improve them!

- Mojo now supports partial automatic parameterization: when a function is
  declared with an argument of a partially bound type, the unbound parameters
  of that type are implicitly added to the function's input parameters. For
  example:

  ```mojo
  @value
  struct Fudge[a: Int, b: Int, c: Int = 7]: ...

  # These function declarations are roughly equivalent:
  fn eat(f: Fudge[5]): ...               # implicitly parameterized
  fn eat[_b: Int](f: Fudge[5, _b]): ...  # explicitly parameterized
  ```

  In the first signature for `eat()`, the `b` parameter isn't bound, so it's
  *implicitly* added as an input parameter on the function.

  In the second signature for `eat()`, the author has explicitly defined an
  input parameter (`_b`), which is bound to the second parameter on the argument
  type (which happens to be `b`).

  Both functions can be called like this:

  ```mojo
  eat(Fudge[5, 8]())
  ```

  Mojo infers the value of the `b` parameter from the argument (in this case,
  8).

  With the second signature, you can also pass the `_b` parameter value
  explicitly:

  ```mojo
  eat[3](Fudge[5, 3]())
  ```

  Moreover, Mojo now allows you to explicitly mark parameters as unbound using
  the `_` as syntax meaning "placeholder for an unbound parameter." For example:

  ```mojo
  # These function declarations are roughly equivalent:
  fn eat(f: Fudge[5, _, c=_]): ...                    # implicitly parameterized
  fn eat(f: Fudge[c=_, a=5, b=_]): ...                # implicitly parameterized
  fn eat[_b: Int, _c: Int](f: Fudge[5, _b, _c]): ...  # explicitly parameterized
  ```

  The first two signatures explicitly unbind the `b` and `c` parameters.

  In the last signature, the `_b` and `_c` parameters are explicitly declared by
  the author, and bound to the `b` and `c` parameters in the argument type.

  Any of these signatures can be called like this:

  ```mojo
  eat(Fudge[5, 8]())
  eat(Fudge[5, 8, 9]())
  ```

  Note that the default parameter values of struct parameters are bound, unless
  explicitly unbound by the user.

  For more information, see the
  [Mojo Manual](/mojo/manual/parameters/#fully-bound-partially-bound-and-unbound-types).

- Parametric types can now be partially bound in certain contexts. For example,
  a new `Scalar` type alias has been added defined as:

  ```mojo
  alias Scalar = SIMD[size=1]
  ```

  Which creates a parametric type alias `Scalar` with a single parameter of type
  `DType`. Types can also be partially or fully bound in other contexts. For
  instance, `alias` declarations of type values inside functions now work
  properly:

  ```mojo
  fn type_aliases():
      alias T = SIMD
      print(T[DType.float32, 1]())
      alias Partial = T[type=DType.int32]
      print(Partial[2]())
  ```

- The `__mlir_op` feature now supports operations that return multiple results.
  To use them, you write the `_type` field as a `Tuple` of types.  For example:

  ```mojo
  # The `ret` variable has type `Tuple[Int, Int]`.
  let ret = __mlir_op.`multi_result_op`[_type=(Int, Int)]()
  ```

- Mojo now has the ability to read raw bytes from a file using the
  [`read_bytes()`](/mojo/stdlib/builtin/file/FileHandle#read_bytes) method.
  For example:

  ```mojo
  with open("file.binary", "r") as f:
      data = f.read_bytes()
  ```

- A size argument was added to the
[`read()`](/mojo/stdlib/builtin/file/FileHandle#read) and
[`read_bytes()`](/mojo/stdlib/builtin/file/FileHandle#read_bytes) methods on
the builtin `file.FileHandle`. The size argument defaults to -1 and maintains
the previous "read to EOF" behavior when size is negative.

  ```mojo
  with open("file.binary", "r") as f:
      data1 = f.read_bytes(1024)
      data2 = f.read_bytes(256)
  ```

- [`Path`](/mojo/stdlib/pathlib/path/Path) now has `read_bytes()` and
  `read_text()` methods to read file contents from a path:

  ```mojo
  let text_path = Path("file.txt")
  let text = text_path.read_text()

  let binary_path = Path("file.binary")
  let data = binary_path.read_bytes()
  ```

- `Tensor` has new `save()` and `load()` methods to save and load to file. These
  methods preserve shape and datatype information. For example:

  ```mojo
  let tensor = Tensor[DType.float32]()
  tensor.save(path)

  let tensor_from_file = Tensor[DType.float32].load(path)
  ```

- Subscripting added to
  [`DTypePointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer) and
  [`Pointer`](/mojo/stdlib/memory/unsafe_pointer/UnsafePointer):

  ```mojo
  let p = DTypePointer[DType.float16].alloc(4)
  for i in range(4):
      p[i] = i
      print(p[i])
  ```

- `file.FileHandle` now has a `seek()` method.

- [`String`](/mojo/stdlib/collections/string/string/String) now has an
  [`rfind()`](/mojo/stdlib/collections/string/string/String#rfind) method
  analogous to Python's `str.rfind()`.

- `String` now has an
  [`split()`](/mojo/stdlib/collections/string/string/String#split) method
  analogous to Python's `str.split()`.

- [`Path`](/mojo/stdlib/pathlib/path/Path) now has a
  [`suffix()`](/mojo/stdlib/pathlib/path/Path#suffix) method analogous to
  Python's `pathlib.Path.suffix`.

- The Mojo REPL now supports indented expressions, making it a bit easier to
  execute expressions copied from an indented block (such as a doc string).

- The Mojo Language Server now implements the Document Symbols request. IDEs use
  this to provide support for **Outline View** and **Go to Symbol**. This
  addresses [Issue #960](https://github.com/modular/modular/issues/960).

- The Mojo Language Server now shows documentation when code completing modules
  or packages in `import` statements.

- The Mojo Language Server now supports processing code examples, defined as
  markdown Mojo code blocks, inside of doc strings. This enables IDE features
  while writing examples in API documentation.

- The Mojo Language Server now provides semantic token information, providing
  better highlighting for symbols whose semantics are not statically analyzable.

- The Mojo Language Server now classifies doc strings as folding ranges,
  making them easier to collapse, reducing vertical space while editing.

- Command line options for the `mojo` driver that take arguments can now be
  written in either of two ways: both `--foo FOO` and `--foo=FOO`. Previously,
  only the former was valid.

### 🦋 Changed

- Variadic list types
  [`VariadicList`](/mojo/stdlib/builtin/variadics/VariadicList) and
  [`VariadicListMem`](/mojo/stdlib/builtin/variadics/VariadicListMem)
  are now iterable. Variadic arguments are automatically projected into one of
  these types inside the function body, so var args can be iterated:

  ```mojo
  fn print_ints(*nums: Int):
      for num in nums:
          print(num)
      print(len(nums))
  ```

- The assert functions in the [`testing`](/mojo/stdlib/testing/testing)
  package now raise an `Error` when the assertion fails instead of returning a
  `Bool` for whether the assertion succeeded or not.

- Parameters of [`AnyType`](/mojo/stdlib/builtin/type_aliases) type are no
  longer (implicitly) assumed to be register-passable. A new `AnyRegType` type
  is used to represent generic types that are register passable.

- Changing the units in a [`benchmark`](/mojo/stdlib/benchmark/benchmark)
  report is now an argument instead of a parameter:

  ```mojo
  let report = benchmark.run[timer]()
  report.print(Unit.ms)
  ```

- Default values on `inout` arguments are no longer permitted, i.e. the
  following will now raise an error:

  ```mojo
  fn inout_default(inout x: Int = 2): ...
  ```

- The `to_string()` function has been removed from
  [`PythonObject`](/mojo/stdlib/python/python_object/PythonObject) in favor of
  the new `__str__()` function.  This composes better with traits so it can be
  used with the generic `str()` function.

### 🛠️ Fixed

- [#734](https://github.com/modular/modular/issues/734) - Consumption of struct
  works only for types with a `__del__` method.

- [#910](https://github.com/modular/modular/issues/910) - Parser crash when
  using memory-only generic type as return of function that `raise`s.

- [#1060](https://github.com/modular/modular/issues/1060) - Mojo happily parses
  code that has messed up indentation

- [#1159](https://github.com/modular/modular/issues/1159) - The language server
  doesn't warn about bad return type.

- [#1166](https://github.com/modular/modular/issues/1166) - warning: unreachable
  code after return statement with context manager

- [#1098](https://github.com/modular/modular/issues/1098) - The language server
  doesn't highlight properties of PythonObjects correctly.

- [#1153](https://github.com/modular/modular/issues/1153) - The language server
  crashes when parsing an invalid multi-nested module import.

- [#1236](https://github.com/modular/modular/issues/1236) - The language server
  doesn't show autocomplete in if statements.

- [#1246](https://github.com/modular/modular/issues/1246) - Warning diagnostics
  are transient in the presence of caching.

### Known Issue

- There is an issue affecting Jupyter notebooks that use autotuning and traits.
  This issue only manifests on macOS, and the same code runs without issue
  outside of the notebooks. This issue affects the *Matrix multiplication in
  Mojo* notebook.

## v0.5.0 (2023-11-2)

### ⭐️ New

- The [`SIMD`](/mojo/stdlib/builtin/simd/SIMD) type now defaults to the
  architectural SIMD width of the type. This means you can write
  `SIMD[DType.float32]` which is equivalent to
  `SIMD[DType.float32, simdwidthof[DType.float32]()]`.

- The [`SIMD`](/mojo/stdlib/builtin/simd/SIMD) type now contains a `join()`
  function that allows you to concatenate two `SIMD` values together and produce
  a new `SIMD` value.

- Mojo now supports compile-time *keyword parameters*, in addition to existing
  support for [keyword
  arguments](/mojo/manual/parameters/#optional-parameters-and-keyword-parameters).
  For example:

  ```mojo
  fn foo[a: Int, b: Int = 42]():
      print(a, "+", b)

  foo[a=5]()        # prints '5 + 42'
  foo[a=7, b=13]()  # prints '7 + 13'
  foo[b=20, a=6]()  # prints '6 + 20'
  ```

  Keyword parameters are also supported in structs:

  ```mojo
  struct KwParamStruct[a: Int, msg: String = "🔥mojo🔥"]:
      fn __init__(inout self):
          print(msg, a)

  fn use_kw_params():
      KwParamStruct[a=42]()               # prints '🔥mojo🔥 42'
      KwParamStruct[5, msg="hello"]()     # prints 'hello 5'
      KwParamStruct[msg="hello", a=42]()  # prints 'hello 42'
  ```

  For more detail, see the [Mojo
  Manual](/mojo/manual/parameters/#optional-parameters-and-keyword-parameters).

  For the time being, the following notable limitations apply:

  - Keyword-only parameters are **not supported** yet:

    ```mojo
    fn baz[*args: Int, b: Int](): pass  # fails
    fn baz[a: Int, *, b: Int](): pass  # fails
    ```

    (The analogous keyword-only arguments in Python are described in
    [PEP 3102](https://peps.python.org/pep-3102/).)

  - Variadic keyword parameters are **not supported** yet:

    ```mojo
    fn baz[a: Int, **kwargs: Int](): pass  # fails
    ```

- Mojo now supports "automatic" parameterization of functions. What this means
  is that if a function argument type is parametric but has no bound parameters,
  they are automatically added as input parameters on the function. This works
  with existing features to allow you to write parametric functions with less
  boilerplate.

  ```mojo
  @value
  struct Thing[x: Int, y: Int]:
      pass

  fn foo(v: Thing):
      print(v.x)
      print(v.y)

  fn main():
      let v = Thing[2, 3]()
      foo(v)
  ```

  However, partial autoparameterization is **not supported** yet:

  ```mojo
  fn foo(v: Thing[y=7]):  # Partially bound type not allowed yet.
      ...
  ```

- Keyword argument passing is supported when invoking `__getitem__` using
  the bracket syntax:

  ```mojo
  @value
  struct MyStruct:
      fn __getitem__(self, x: Int, y: Int, z: Int) -> Int:
          return x * y + z

  MyStruct()[z=7, x=3, y=5]  # returns 22
  ```

  However, keyword argument passing to `__setitem__` using the bracket syntax is
  **not supported** yet:

  ```mojo
  @value
  struct OtherStruct:
      fn __setitem__(self, x: Int, y: Int): pass

  OtherStruct()[x=1] = 4  # fails
  ```

- Function argument input parameters can now be referenced within the signature
  of the function:

  ```mojo
  fn foo(x: SIMD, y: SIMD[x.type, x.size]):
      pass
  ```

- The [`benchmark`](/mojo/stdlib/benchmark/benchmark) module has been
  simplified and improved so you can now run:

  ```mojo
  import benchmark
  from time import sleep

  fn sleeper():
      sleep(.01)

  fn main():
      let report = benchmark.run[sleeper]()
      print(report.mean())
  ```

  It no longer requires a capturing `fn` so can benchmark functions outside the
  same scope.

  You can print a report with:

  ```mojo
  report.print()
  ```

  ```plaintext
  ---------------------
  Benchmark Report (s)
  ---------------------
  Mean: 0.012314264957264957
  Total: 1.440769
  Iters: 117
  Warmup Mean: 0.0119335
  Warmup Total: 0.023866999999999999
  Warmup Iters: 2
  Fastest Mean: 0.012227958333333334
  Slowest Mean: 0.012442699999999999
  ```

  Units for all functions default to seconds, but can be changed with:

  ```mojo
  from benchmark import Unit

  report.print[Unit.ms]()
  ```

- Mojo now supports struct parameter deduction (a.k.a. class template argument
  deduction, or CTAD) for partially bound types. Struct parameter deduction is
  also possible from static methods. For example:

  ```mojo
  @value
  struct Thing[v: Int]: pass

  struct CtadStructWithDefault[a: Int, b: Int, c: Int = 8]:
      fn __init__(inout self, x: Thing[a]):
          print("hello", a, b, c)

      @staticmethod
      fn foo(x: Thing[a]):
          print("🔥", a, b, c)

  fn main():
      _ = CtadStructWithDefault[b=7](Thing[6]())  # prints 'hello 6 7 8'
      CtadStructWithDefault[b=7].foo(Thing[6]())  # prints '🔥 6 7 8'
  ```

- `Tensor` has new `fromfile()` and `tofile()` methods to save and load as bytes
  from a file.

- The built-in `print()` function now works on the
  [`Tensor`](/max/api/mojo/tensor/tensor/Tensor) type.

- [`TensorShape`](/max/api/mojo/tensor/tensor_shape/TensorShape) and
  [`TensorSpec`](/max/api/mojo/tensor/tensor_spec/TensorSpec) now have
  constructors that take
  [`DynamicVector[Int]`](/mojo/stdlib/collections/list/List) and
  [`IndexList`](/mojo/stdlib/utils/index_/IndexList) to initialize shapes.

- The [`String`](/mojo/stdlib/collections/string/string/String) type now has the
 `count()` and `find()` methods to enable counting the number of occurrences or
  finding the offset index of a substring in a string.

- The `String` type now has a `replace()` method which allows you to replace a
  substring with another string.

### 🦋 Changed

- [`VariadicList`](/mojo/stdlib/builtin/variadics/VariadicList) and
  [`VariadicListMem`](/mojo/stdlib/builtin/variadics/VariadicListMem)
  moved under builtins, and no longer need to be imported.

- Variadic arguments are now automatically projected into a `VariadicList` or
  `VariadicListMem` inside the function body. This allows for more flexibility
  in using var args. For example:

  ```mojo
    fn print_ints(*nums: Int):
        let len = len(nums)
        for i in range(len):
            print(nums[i])
        print(len)
  ```

- The parameters for
  [`InlinedFixedVector`](/mojo/stdlib/collections/inline_array/InlineArray)
  have been switched. The parameters are now `[type, size]` instead of
  `[size, type]`. The `InlinedFixedVector` now has a default size which means
  that one can just use `InlinedFixedVector` as `InlinedFixedVector[Float32]`
  and the default size is used.

- `write_file()` method in [`Buffer`](/mojo/stdlib/buffer/buffer/NDBuffer)
  and [`NDBuffer`](/mojo/stdlib/buffer/buffer/NDBuffer) is renamed to
  `tofile()` to match the Python naming.

- Mojo will now utilize all available cores across all NUMA sockets on the host
  machine by default. The prior default behavior was to use all the cores on
  the first socket.

### ❌ Removed

- The `math.numerics` module is now private, because its types (`FPUtils` and
  `FlushDenormals`) should not be used externally.

### 🛠️ Fixed

- [#532](https://github.com/modular/modular/issues/532) - Compiler optimizing
  while True loop away
- [#760](https://github.com/modular/modular/issues/760) - Compilation error:
  'hlcf.for.yield' op specifies 0 branch inputs but target expected 1 along
  control-flow edge from here
- [#849](https://github.com/modular/modular/issues/849) - The `Tensor` type is
  now initialized with zeros at construction time.
- [#912](https://github.com/modular/modular/issues/912) - Invalid load for
  `__get_address_as_lvalue`.
- [#916](https://github.com/modular/modular/issues/916) - Parser crash when
  specifying default values for `inout` arguments.
- [#943](https://github.com/modular/modular/issues/943) - Mojo hangs if you
  use continue in the nested loop
- [#957](https://github.com/modular/modular/issues/957) - Parser crash when a
  function call with variadic arguments of a memory-only type is evaluated at
  compile time.
- [#990](https://github.com/modular/modular/issues/990) - Fixes rounding
  issue with floor division with negative numerator.
- [#1018](https://github.com/modular/modular/issues/1018) - In some cases the
  sort function was returning invalid results. This release fixes some of these
  corner cases.
- [#1010](https://github.com/modular/modular/issues/1010) - Initializing tensor
  in alias declaration results in crash.
- [#1110](https://github.com/modular/modular/issues/1110) - The `time.now()`
  function now returns nanoseconds across all operating systems.
- [#1115](https://github.com/modular/modular/issues/1115) - cannot load
  non-register passable type into SSA register.

## v0.4.0 for Mac (2023-10-19)

### 🔥 Legendary

- Mojo for Mac!

  The Mojo SDK now works on macOS (Apple silicon). This is the same version
  previously released for Linux. Get the latest version of the SDK for your Mac
  system:

  [Download Now!](https://developer.modular.com/download)

## v0.4.0 (2023-10-05)

### ⭐️ New

- Mojo now supports default parameter values. For example:

  ```mojo
  fn foo[a: Int = 3, msg: StringLiteral = "woof"]():
      print(msg, a)

  fn main():
      foo()  # prints 'woof 3'
      foo[5]()  # prints 'woof 5'
      foo[7, "meow"]()  # prints 'meow 7'
  ```

  Inferred parameter values take precedence over defaults:

  ```mojo
  @value
  struct Bar[v: Int]:
      pass

  fn foo[a: Int = 42, msg: StringLiteral = "quack"](bar: Bar[a]):
      print(msg, a)

  fn main():
      foo(Bar[9]())  # prints 'quack 9'
  ```

  Structs also support default parameters:

  ```mojo
  @value
  struct DefaultParams[msg: StringLiteral = "woof"]:
      alias message = msg

  fn main():
      print(DefaultParams[]().message)  # prints 'woof'
      print(DefaultParams["meow"]().message)  # prints 'meow'
  ```

- The new [`file`](/mojo/stdlib/builtin/file) module adds basic file I/O
  support. You can now write:

  ```mojo
  var f = open("my_file.txt", "r")
  print(f.read())
  f.close()
  ```

  or

  ```mojo
  with open("my_file.txt", "r") as f:
      print(f.read())
  ```

- Mojo now allows context managers to support an `__enter__` method without
  implementing support for an `__exit__` method, enabling idioms like this:

  ```mojo
  # This context manager consumes itself and returns it as the value.
  fn __enter__(owned self) -> Self:
      return self^
  ```

  Here Mojo *cannot* invoke a noop `__exit__` method because the context
  manager is consumed by the `__enter__` method.  This can be used for types
  (like file descriptors) that are traditionally used with `with` statements,
  even though Mojo's guaranteed early destruction doesn't require that.

- A very basic version of `pathlib` has been implemented in Mojo. The
  module will be improved to achieve functional parity with Python in
  the next few releases.

- The `memory.unsafe` module now contains a `bitcast` function. This is a
  low-level operation that enables bitcasting between pointers and scalars.

- The input parameters of a parametric type can now be directly accessed as
  attribute references on the type or variables of the type. For example:

  ```mojo
  @value
  struct Thing[param: Int]:
      pass

  fn main():
      print(Thing[2].param) # prints '2'
      let x = Thing[9]()
      print(x.param) # prints '9'
  ```

  Input parameters on values can even be accessed in parameter contexts. For
  example:

  ```mojo
  fn foo[value: Int]():
      print(value)

  let y = Thing[12]()
  alias constant = y.param + 4
  foo[constant]() # prints '16'
  ```

- The Mojo REPL now supports code completion. Press <kbd>Tab</kbd> while typing
  to query potential completion results.

- Error messages from Python are now exposed in Mojo. For example the following
  should print `No module named 'my_uninstalled_module'`:

  ```mojo
  fn main():
      try:
          let my_module = Python.import_module("my_uninstalled_module")
      except e:
          print(e)
  ```

- Error messages can now store dynamic messages. For example, the following
  should print "Failed on: Hello"

  ```mojo
  fn foo(x: String) raises:
      raise Error("Failed on: " + x)

  fn main():
      try:
          foo("Hello")
      except e:
          print(e)
  ```

### 🦋 Changed

- We have improved and simplified the `parallelize` function. The function
  now elides some overhead by caching the Mojo parallel runtime.

- The Mojo REPL and Jupyter environments no longer implicitly expose `Python`,
  `PythonObject`, or `Pointer`. These symbols must now be imported explicitly,
  for example:

  ```mojo
  from python import Python
  from python.object import PythonObject
  from memory.unsafe import Pointer
  ```

- The syntax for specifying attributes with the `__mlir_op` prefix have changed
  to mimic Python's keyword argument passing syntax. That is, `=` should be used
  instead of `:`, e.g.:

  ```mojo
  # Old syntax, now fails.
  __mlir_op.`index.bool.constant`[value : __mlir_attr.false]()
  # New syntax.
  __mlir_op.`index.bool.constant`[value=__mlir_attr.false]()
  ```

- You can now print the `Error` object directly. The `message()` method
  has been removed.

### 🛠️ Fixed

- [#794](https://github.com/modular/modular/issues/794) - Parser crash when
  using the `in` operator.
- [#936](https://github.com/modular/modular/issues/936) - The `Int` constructor
  now accepts other `Int` instances.
- [#921](https://github.com/modular/modular/issues/921) - Better error message
  when running `mojo` on a module with no  `main` function.
- [#556](https://github.com/modular/modular/issues/556) - UInt64s are now
  printed correctly.
- [#804](https://github.com/modular/modular/issues/804) - Emit error instead of
  crashing when passing variadic arguments of unsupported types.
- [#833](https://github.com/modular/modular/issues/833) - Parser crash when
  assigning module value.
- [#752](https://github.com/modular/modular/issues/752) - Parser crash when
  calling async def.
- [#711](https://github.com/modular/modular/issues/711) - The overload resolution
  logic now correctly prioritizes instance methods over static methods (if
  candidates are an equally good match otherwise), and no longer crashed if a
  static method has a `Self` type as its first argument.
- [#859](https://github.com/modular/modular/issues/859) - Fix confusing error and
  documentation of the `rebind` builtin.
- [#753](https://github.com/modular/modular/issues/753) - Direct use of LLVM
  dialect produces strange errors in the compiler.
- [#926](https://github.com/modular/modular/issues/926) - Fixes an issue that
  occurred when a function with a return type of `StringRef` raised an error.
  When the function raised an error, it incorrectly returned the string value of
  that error.
- [#536](https://github.com/modular/modular/issues/536) - Report More information
  on python exception.

## v0.3.1 (2023-09-28)

Our first-ever patch release of the Mojo SDK is here! Release v0.3.1
includes primarily installation-related fixes. If you’ve had trouble
installing the previous versions of the SDK, this release may be for you.

### 🛠️ Fixed

- [#538](https://github.com/modular/modular/issues/538) - Installation hangs
  during the testing phase. This issue occurs on machines with a low number
  of CPU cores, such as free AWS EC2 instances and GitHub Codespaces.
- [#590](https://github.com/modular/modular/issues/590) - Installation fails
  with a “failed to run python” message.
- [#672](https://github.com/modular/modular/issues/672) - Language server hangs
  on code completion. Related to #538, this occurs on machines with a low
  number of CPU cores.
- [#913](https://github.com/modular/modular/issues/913) - In the REPL and Jupyter
  notebooks, inline comments were being parsed incorrectly.

## v0.3.0 (2023-09-21)

There's more Mojo to love in this, the second release of the Mojo SDK! This
release includes new features, an API change, and bug fixes.

There's also an updated version of the [Mojo extension for VS
Code](https://marketplace.visualstudio.com/items?itemName=modular-mojotools.vscode-mojo).

### ⭐️ New

- Mojo now has partial support for passing keyword arguments to functions and
  methods. For example the following should work:

  ```mojo
  fn foo(a: Int, b: Int = 3) -> Int:
      return a * b

  fn main():
      print(foo(6, b=7))  # prints '42'
      print(foo(a=6, b=7))  # prints '42'
      print(foo(b=7, a=6))  # prints '42'
  ```

  Parameters can also be inferred from keyword arguments, for example:

  ```mojo
  fn bar[A: AnyType, B: AnyType](a: A, b: B):
      print("Hello 🔥")

  fn bar[B: AnyType](a: StringLiteral, b: B):
      print(a)

  fn main():
      bar(1, 2)  # prints `Hello 🔥`
      bar(b=2, a="Yay!")  # prints `Yay!`
  ```

  For the time being, the following notable limitations apply:

  - Keyword-only arguments are not supported:

    ```mojo
    fn baz(*args: Int, b: Int): pass  # fails
    fn baz(a: Int, *, b: Int): pass  # fails
    ```

    (Keyword-only arguments are described in
    [PEP 3102](https://peps.python.org/pep-3102/).)

  - Variadic keyword arguments are not supported:

    ```mojo
    fn baz(a: Int, **kwargs: Int): pass  # fails
    ```

- Mojo now supports the `@nonmaterializable` decorator.  The purpose is to mark
  data types that should only exist in the parameter domain.  To use it, a
  struct is decorated with `@nonmaterializable(TargetType)`.  Any time the
  nonmaterializable type is converted from the parameter domain, it is
  automatically converted to `TargetType`.  A nonmaterializable struct should
  have all of its methods annotated as `@always_inline`, and must be computable
  in the parameter domain.  In the following example, the `NmStruct` type can
  be added in the parameter domain, but are converted to `HasBool` when
  materialized.

  ```mojo
  @value
  @register_passable("trivial")
  struct HasBool:
      var x: Bool
      fn __init__(x: Bool) -> Self:
          return Self {x: x}
      @always_inline("nodebug")
      fn __init__(nms: NmStruct) -> Self:
          return Self {x: True if (nms.x == 77) else False}

  @value
  @nonmaterializable(HasBool)
  @register_passable("trivial")
  struct NmStruct:
      var x: Int
      @always_inline("nodebug")
      fn __add__(self: Self, rhs: Self) -> Self:
          return NmStruct(self.x + rhs.x)

  alias stillNmStruct = NmStruct(1) + NmStruct(2)
  # When materializing to a run-time variable, it is automatically converted,
  # even without a type annotation.
  let convertedToHasBool = stillNmStruct
  ```

- Mojo integer literals now produce the `IntLiteral` infinite precision integer
  type when used in the parameter domain.  `IntLiteral` is materialized to the
  `Int` type for runtime computation, but intermediate computations at compile
  time, using supported operators, can now exceed the bit width of the `Int`
  type.

- The Mojo Language Server now supports top-level code completions, enabling
  completion when typing a reference to a variable, type, etc. This resolves
  [#679](https://github.com/modular/modular/issues/679).

- The Mojo REPL now colorizes the resultant variables to help distinguish input
  expressions from the output variables.

### 🦋 Changed

- Mojo allows types to implement two forms of move constructors, one that is
  invoked when the lifetime of one value ends, and one that is invoked if the
  compiler cannot prove that.  These were previously both named `__moveinit__`,
  with the following two signatures:

  ```mojo
  fn __moveinit__(inout self, owned existing: Self): ...
  fn __moveinit__(inout self, inout existing: Self): ...
  ```

  We've changed the second form to get its own name to make it more clear that
  these are two separate operations: the second has been renamed to
  `__takeinit__`:

  ```mojo
  fn __moveinit__(inout self, owned existing: Self): ...
  fn __takeinit__(inout self, inout existing: Self): ...
  ```

  The name is intended to connote that the operation takes the conceptual value
  from the source (without destroying it) unlike the first one which "moves" a
  value from one location to another.

  For more information, see the Mojo Manual section on
  [move constructors](/mojo/manual/lifecycle/life#move-constructor).

- The Error type in Mojo has changed. Instead of extracting the error message
  using `error.value` you will now extract the error message using
  `error.message()`.

### 🛠️ Fixed

- [#503](https://github.com/modular/modular/issues/503) - Improve error message
  for failure lowering `kgen.param.constant`.
- [#554](https://github.com/modular/modular/issues/554) - Alias of static tuple
  fails to expand.
- [#500](https://github.com/modular/modular/issues/500) - Call expansion failed
  due to verifier error.
- [#422](https://github.com/modular/modular/issues/422) - Incorrect comment
  detection in multiline strings.
- [#729](https://github.com/modular/modular/issues/740) - Improve messaging on
  how to exit the REPL.
- [#756](https://github.com/modular/modular/issues/756) - Fix initialization
  errors of the VS Code extension.
- [#575](https://github.com/modular/modular/issues/575) - Build LLDB/REPL with
  libedit for a nicer editing experience in the terminal.

## v0.2.1 (2023-09-07)

The first versioned release of Mojo! 🔥

All earlier releases were considered version 0.1.

### 🔥 Legendary

- First release of the Mojo SDK!

  You can now develop with Mojo locally. The Mojo SDK is currently available
  for Ubuntu Linux systems, and support for Windows and macOS is coming soon.
  You can still develop from a Windows or Mac computer using a container or
  remote Linux system.

  The Mojo SDK includes the Mojo standard library and the [Mojo command-line
  interface](/mojo/cli/) (CLI), which allows you to run, compile, and package
  Mojo code. It also provides a REPL programming environment.

  [Get the Mojo SDK!](https://developer.modular.com/download)

- First release of the [Mojo extension for VS
  Code](https://marketplace.visualstudio.com/items?itemName=modular-mojotools.vscode-mojo).

  This provides essential Mojo language features in Visual Studio Code, such as
  code completion, code quick fixes, docs tooltips, and more. Even when
  developing on a remote system, using VS Code with this extension provides
  a native-like IDE experience.

### ⭐️ New

- A new `clobber_memory` function has been added to the
  [`benchmark`](/mojo/stdlib/benchmark/benchmark) module.
  The clobber memory function tells the system to flush all memory operations
  at the specified program point. This allows you to benchmark operations
  without the compiler reordering memory operations.

- A new `keep` function has been added to the
  [`benchmark`](/mojo/stdlib/benchmark/benchmark) module. The `keep`
  function tries to tell the compiler not to optimize the variable away
  if not used. This allows you to avoid compiler's dead code elimination
  mechanism, with a low footprint side effect.

- New `shift_right` and `shift_left` functions have been added to the
  [`simd`](/mojo/stdlib/builtin/simd) module. They shift the elements in
  a SIMD vector right/left, filling elements with zeros as needed.

- A new `cumsum` function has been added to the
  [`reduction`](/mojo/stdlib/algorithm/reduction) module that computes
  the cumulative sum (also known as scan) of input elements.

- Mojo Jupyter kernel now supports code completion.

### 🦋 Changed

- Extends `rotate_bits_left`, `rotate_left`, `rotate_bits_right`, and
  `rotate_right` to operate on Int values. The ordering of parameters has also
  been changed to enable type inference. Now it's possible to write
  `rotate_right[shift_val](simd_val)` and have the `dtype` and `simd_width`
  inferred from the argument. This addresses
  [Issue #528](https://github.com/modular/modular/issues/528).

### 🛠️ Fixed

- Fixed a bug causing the parser to crash when the `with` statement was written
  without a colon.
  This addresses [Issue #529](https://github.com/modular/modular/issues/529).

- Incorrect imports no longer crash when there are other errors at the top
  level of a module. This fixes [Issue
  #531](https://github.com/modular/modular/issues/531).

## August 2023

### 2023-08-24

- Fixed issue where the `with expr as x` statement within `fn` behaved
  as if it were in a `def`, binding `x` with function scope instead of using
  lexical scope.

#### ⭐️ New

- Major refactoring of the standard library to enable packaging and better
  import ergonomics:
  - The packages are built as binaries to improve startup speed.
  - Package and module names are now lowercase to align with the Python style.
  - Modules have been moved to better reflect the purpose of the underlying
    functions (e.g. `Pointer` is now within the `unsafe` module in the `memory`
    package).
  - The following modules are now included as built-ins:
    `SIMD`, `DType`, `IO`, `Object`, and `String`.
    This means it's no longer necessary to explicitly import these modules.
    Instead, these modules will be implicitly imported for the user. Private
    methods within the module are still accessible using the
    `builtin.module_name._private_method` import syntax.
  - New `math` package has been added to contain the `bit`, `math`, `numerics`,
    and `polynomial` modules. The contents of the `math.math` module are
    re-exported into the `math` package.

- Mojo now supports using memory-only types in parameter expressions and as
  function or type parameters:

  ```mojo
  @value
  struct IntPair:
      var first: Int
      var second: Int

  fn add_them[value: IntPair]() -> Int:
      return value.first + value.second

  fn main():
      print(add_them[IntPair(1, 2)]()) # prints '3'
  ```

- In addition, Mojo supports evaluating code that uses heap-allocated memory
  at compile-time and materializing compile-time values with heap-allocated
  memory into dynamic values:

  ```mojo
  fn fillVector(lowerBound: Int, upperBound: Int, step: Int) -> DynamicVector[Int]:
      var result = DynamicVector[Int]()
      for i in range(lowerBound, upperBound, step):
          result.push_back(i)
      return result

  fn main():
      alias values = fillVector(5, 23, 7)
      for i in range(0, values.__len__()):
          print(values[i]) # prints '5', '12', and then '19'
  ```

#### 🦋 Changed

- `def main():`, without the explicit `None` type, can now be used to define
  the entry point to a Mojo program.

- The `assert_param` function has been renamed to `constrained` and is now
  a built-in function.

- The `print` function now works on `Complex` values.

#### 🛠️ Fixed

- Fixed issues with print formatting for `DType.uint16` and `DType.int16`.
- [Issue #499](https://github.com/modular/modular/issues/499) - Two new
  `rotate_right` and `rotate_left` functions have been added to the SIMD module.
- [Issue #429](https://github.com/modular/modular/issues/429) - You can now
  construct a `Bool` from a `SIMD` type whose element-type is `DType.bool`.
- [Issue #350](https://github.com/modular/modular/issues/350) - Confusing Matrix
  implementation
- [Issue #349](https://github.com/modular/modular/issues/349) - Missing load_tr
  in struct Matrix
- [Issue #501](https://github.com/modular/modular/issues/501) - Missing syntax
  error messages in Python expressions.

### 2023-08-09

#### 🦋 Changed

- The `ref` and `mutref` identifiers are now treated as keywords, which means
  they cannot be used as variable, attribute, or function names.  These keywords
  are used by the "lifetimes" features, which is still in development.  We can
  consider renaming these (as well as other related keywords) when the
  development work gels, support is enabled in public Mojo builds, and when we
  have experience using them.

- The argument handling in `def` functions has changed: previously, they had
  special behavior that involved mutable copies in the callee. Now, we have a
  simple rule, which is that `def` argument default to the `owned` convention
  (`fn` arguments still default to the `borrowed` convention).

  This change is mostly an internal cleanup and simplification of the compiler
  and argument model, but does enable one niche use-case: you can now pass
  non-copyable types to `def` arguments by transferring ownership of a value
  into the `def` call. Before, that would not be possible because the copy was
  made on the callee side, not the caller's side. This also allows the explicit
  use of the `borrowed` keyword with a `def` that wants to opt-in to that
  behavior.

### 2023-08-03

#### ⭐️ New

- A new [`Tensor`](/max/api/mojo/tensor/tensor/Tensor) type has been introduced.
  This tensor type manages its own data (unlike `NDBuffer` and `Buffer` which
  are just views). Therefore, the tensor type performs its own allocation and
  free. Here is a simple example of using the tensor type to represent an RGB
  image and convert it to grayscale:

  ```mojo
  from tensor import Tensor, TensorShape
  from utils.index import Index
  from random import rand

  let height = 256
  let width = 256
  let channels = 3

  # Create the tensor of dimensions height, width, channels and fill with
  # random value.
  let image = rand[DType.float32](height, width, channels)

  # Declare the grayscale image.
  var gray_scale_image = Tensor[DType.float32](height, width)

  # Perform the RGB to grayscale transform.
  for y in range(height):
      for x in range(width):
          let r = image[y, x, 0]
          let g = image[y, x, 1]
          let b = image[y, x, 2]
          gray_scale_image[Index(y, x)] = 0.299 * r + 0.587 * g + 0.114 * b
  ```

#### 🛠️ Fixed

- [Issue #53](https://github.com/modular/modular/issues/53) - `Int` now
  implements true division with the `/` operator. Similar to Python, this
  returns a 64-bit floating point number. The corresponding in-place operator,
  `/=`, has the same semantics as `//=`.

## July 2023

### 2023-07-26

#### ⭐️ New

- Types that define both `__getitem__` and `__setitem__` (i.e. where
  sub-scripting instances creates computed LValues) can now be indexed
  in parameter expressions.

- Unroll decorator for loops with constant bounds and steps:
  - `@unroll`: Fully unroll a loop.
  - `@unroll(n)`: Unroll a loop by factor of n, where `n` is a positive integer.
  - Unroll decorator requires loop bounds and iteration step to be
  compiler time constant value, otherwise unrolling will fail with
  compilation error. This also doesn't make loop induction variable a parameter.

  ```mojo
  # Fully unroll the loop.
  @unroll
  for i in range(5):
      print(i)

  # Unroll the loop by a factor of 4 (with remainder iterations of 2).
  @unroll(4)
  for i in range(10):
      print(i)
  ```

- The Mojo REPL now prints the values of variables defined in the REPL. There is
  full support for scalars and structs. Non-scalar SIMD vectors are not
  supported at this time.

#### 🛠️ Fixed

- [Issue #437](https://github.com/modular/modular/issues/437) - Range can now
  be instantiated with a PythonObject.

- [Issue #288](https://github.com/modular/modular/issues/288) - Python strings
  can now be safely copied.

### 2023-07-20

#### ⭐️ New

- Mojo now includes a `Limits` module, which contains functions to get the max
  and min values representable by a type, as requested in [Issue
  #51](https://github.com/modular/modular/issues/51). The following functions
  moved from `Math` to `Limits`: `inf()`, `neginf()`, `isinf()`, `isfinite()`.

- Mojo decorators are now distinguished between "signature" and "body"
  decorators and are ordered. Signature decorators, like `@register_passable`
  and `@parameter`, modify the type of declaration before the body is parsed.
  Body decorators, like `@value`, modify the body of declaration after it is
  fully parsed. Due to ordering, a signature decorator cannot be applied after
  a body decorator. That means the following is now invalid:

  ```mojo
  @register_passable # error: cannot apply signature decorator after a body one!
  @value
  struct Foo:
      pass
  ```

- Global variables can now be exported in Mojo compiled archives, using the
  `@export` decorator. Exported global variables are public symbols in compiled
  archives and use the variable name as its linkage name, by default. A custom
  linkage name can be specified with `@export("new_name")`. This does not affect
  variable names in Mojo code.

- Mojo now supports packages! A Mojo package is defined by placing an
  `__init__.mojo` or `__init__.🔥` within a directory. Other files in the same
  directory form modules within the package (this works exactly like it
  does [in Python](https://docs.python.org/3/tutorial/modules.html#packages)).
  Example:

  ```bash
  main.🔥
  my_package/
    __init__.🔥
    module.🔥
    my_other_package/
      __init__.🔥
      stuff.🔥
  ```

  ```mojo
  # main.🔥
  from my_package.module import some_function
  from my_package.my_other_package.stuff import SomeType

  fn main():
      var x: SomeType = some_function()
  ```

- Mojo now supports direct module and package imports! Modules and packages can
  be imported and bound to names. Module and package elements, like functions,
  types, global variables, and other modules, can be accessed using attribute
  references, like `my_module.foo`. Note that modules lack runtime
  representations, meaning module references cannot be instantiated.

  ```mojo
  import builtin.io as io
  import SIMD

  io.print("hello world")
  var x: SIMD.Float32 = 1.2
  ```

#### 🦋 Changed

- Reverted the feature from 2023-02-13 that allowed unqualified struct members.
  Use the `Self` keyword to conveniently access struct members with bound
  parameters instead.  This was required to fix
  [Issue #260](https://github.com/modular/modular/issues/260).

- Updated the RayTracing notebook: added step 5 to create specular lighting for
  more realistic images and step 6 to add a background image.

#### 🛠️ Fixed

- [Issue #260](https://github.com/modular/modular/issues/260) - Definitions
  inside structs no longer shadow definitions outside of struct definitions.

### 2023-07-12

#### ⭐️ New

- Mojo now has support for global variables! This enables `var` and `let`
  declaration at the top-level scope in Mojo files. Global variable initializers
  are run when code modules are loaded by the platform according to the order of
  dependencies between global variables, and their destructors are called in the
  reverse order.

- The Mojo programming manual is now written
  as a Jupyter notebook, and available in its entirety in the Mojo Playground
  (`programming-manual.ipynb`). (Previously, `HelloMojo.ipynb` included most of
  the same material, but it was not up-to-date.)

- As a result, we've also re-written `HelloMojo.ipynb` to be much shorter and
  provide a more gentle first-user experience.

- [`Coroutine` module documentation](/mojo/stdlib/builtin/coroutine) is now
  available. Coroutines form the basis of Mojo's support for asynchronous
  execution. Calls to `async fn`s can be stored into a `Coroutine`, from which
  they can be resumed, awaited upon, and have their results retrieved upon
  completion.

#### 🦋 Changed

- `simd_bit_width` in the `TargetInfo` module has been renamed to `simdbitwidth`
  to better align with `simdwidthof`, `bitwidthof`, etc.

#### 🛠️ Fixed

- The walrus operator now works in if/while statements without parentheses,
  e.g. `if x := function():`.

- [Issue #428](https://github.com/modular/modular/issues/428) - The
  `FloatLiteral` and `SIMD` types now support conversion to `Int` via the
  `to_int` or `__int__` method calls. The behavior matches that of Python, which
  rounds towards zero.

### 2023-07-05

#### ⭐️ New

- Tuple expressions now work without parentheses. For example, `a, b = b, a`
  works as you'd expect in Python.
- Chained assignments (e.g. `a = b = 42`) and the walrus operator (e.g.
  `some_function(b := 17)`) are now supported.

#### 🦋 Changed

- The `simd_width` and `dtype_simd_width` functions in the
  [`TargetInfo`](/mojo/stdlib/sys/info) module
  have been renamed to `simdwidthof`.

- The `dtype_` prefix has been dropped from `alignof`, `sizeof`, and
  `bitwidthof`. You can now use these functions (e.g. `alignof`) with any
  argument type, including `DType`.

- The `inf`, `neginf`, `nan`, `isinf`, `isfinite`, and `isnan` functions were
  moved from the `Numerics` module to the [`Math`](/mojo/stdlib/math/math/)
  module, to better align with Python's library structure.

#### 🛠️ Fixed

- [Issue #253](https://github.com/modular/modular/issues/253) - Issue
  when accessing a struct member alias without providing parameters.

- [Issue #404](https://github.com/modular/modular/issues/404) - The docs now use
  `snake_case` for variable names, which more closely conforms to Python's
  style.

- [Issue #379](https://github.com/modular/modular/issues/379) - Tuple
  limitations have been addressed and multiple return values are now supported,
  even without parentheses.

- [Issue #347](https://github.com/modular/modular/issues/347) - Tuples no longer
  require parentheses.

- [Issue #320](https://github.com/modular/modular/issues/320) - Python objects
  are now traversable via `for` loops.

## June 2023

### 2023-06-29

#### ⭐️ New

- You can now share `.ipynb` notebook files in Mojo Playground. Just save a
  file in the `shared` directory, and then right-click the file and select
  **Copy Sharable link**. To open a shared notebook, you must already have
  access to Mojo Playground;
  when you open a shared notebook, click **Import** at the top of the notebook
  to save your own copy. For more details about this feature, see the
  instructions inside the `help` directory, in the Mojo Playground file browser.

#### 🦋 Changed

- The `unroll2()` and `unroll3()` functions in the
  [`Functional`](/mojo/stdlib/algorithm/functional) module have been renamed to
  overload the `unroll()` function. These functions unroll 2D and 3D loops and
  `unroll()` can determine the intent based on the number of input parameters.

#### 🛠️ Fixed

- [Issue #229](https://github.com/modular/modular/issues/229) - Issue when
  throwing an exception from `__init__` before all fields are initialized.

- [Issue #74](https://github.com/modular/modular/issues/74) - Struct
  definition with recursive reference crashes.

- [Issue #285](https://github.com/modular/modular/issues/285) - The
  [`TargetInfo`](/mojo/stdlib/sys/info) module now includes
  `is_little_endian()` and `is_big_endian()` to check if the target host uses
  either little or big endian.

- [Issue #254](https://github.com/modular/modular/issues/254) - Parameter name
  shadowing in nested scopes is now handled correctly.

### 2023-06-21

#### ⭐️ New

- Added support for overloading on parameter signature. For example, it is now
possible to write the following:

  ```mojo
  fn foo[a: Int](x: Int):
      pass

  fn foo[a: Int, b: Int](x: Int):
      pass
  ```

  For details on the overload resolution logic, see the Mojo Manual section on
  [parameters](/mojo/manual/parameters/#overloading-on-parameters).

- A new `cost_of()` function has been added to `Autotune`. This meta-function
  must be invoked at compile time, and it returns the number of MLIR operations
  in a function (at a certain stage in compilation), which can be used to
  build basic heuristics in higher-order generators.

  ```mojo
  from autotune import cost_of

  fn generator[f: fn(Int) -> Int]() -> Int:
      @parameter
      if cost_of[fn(Int) -> Int, f]() < 10:
          return f()
      else:
          # Do something else for slower functions...
  ```

- Added a new example notebook with a basic Ray Tracing algorithm.

#### 🦋 Changed

- The `constrained_msg()` in the `Assert` module has been renamed to
  `constrained()`.

#### 🛠️ Fixed

- Overloads marked with `@adaptive` now correctly handle signatures that differ
only in declared parameter names, e.g. the following now works correctly:

  ```mojo
  @adaptive
  fn foobar[w: Int, T: DType]() -> SIMD[T, w]: ...

  @adaptive
  fn foobar[w: Int, S: DType]() -> SIMD[S, w]: ...
  ```

- [Issue #219](https://github.com/modular/modular/issues/219) - Issue when
  redefining a function and a struct defined in the same cell.

- [Issue #355](https://github.com/modular/modular/issues/355) - The loop order
  in the Matmul notebook for Python and naive mojo have been reordered for
  consistency. The loop order now follows (M, K, N) ordering.

- [Issue #309](https://github.com/modular/modular/issues/309) - Use snake case
  naming within the testing package and move the asserts out of the TestSuite
  struct.

### 2023-06-14

#### ⭐️ New

- Tuple type syntax is now supported, e.g. the following works:

  ```mojo
  fn return_tuple() -> (Int, Int):
      return (1, 2)
  ```

#### 🦋 Changed

- The `TupleLiteral` type was renamed to just `Tuple`, e.g.
  `Tuple[Int, Float]`.

#### 🛠️ Fixed

- [Issue #354](https://github.com/modular/modular/issues/354) - Returning a tuple
  doesn't work even with parens.
- [Issue #365](https://github.com/modular/modular/issues/365) - Copy-paste error
  in `FloatLiteral` docs.
- [Issue #357](https://github.com/modular/modular/issues/357) - Crash when
  missing input parameter to variadic parameter struct member function.

### 2023-06-07

#### ⭐️ New

- Tuple syntax now works on the left-hand side of assignments (in "lvalue"
  positions), enabling things like `(a, b) = (b, a)`.  There are several
  caveats: the element types must exactly match (no implicit conversions),
  this only works with values of `TupleLiteral` type (notably, it will not work
  with `PythonObject` yet) and parentheses are required for tuple syntax.

#### ❌ Removed

- Mojo Playground no longer includes the following Python packages (due to size,
  compute costs, and
  [environment complications](https://github.com/modular/modular/issues/300)):
  `torch`, `tensorflow`, `keras`, `transformers`.

#### 🦋 Changed

- The data types and scalar names now conform to the naming convention used
  by numpy. So we use `Int32` instead of `SI32`, similarly using `Float32`
  instead of `F32`. Closes
  [Issue #152](https://github.com/modular/modular/issues/152).

#### 🛠️ Fixed

- [Issue #287](https://github.com/modular/modular/issues/287) - computed
  lvalues don't handle raising functions correctly
- [Issue #318](https://github.com/modular/modular/issues/318) - Large integers
  are not being printed correctly
- [Issue #326](https://github.com/modular/modular/issues/326) - Float modulo
  operator is not working as expected
- [Issue #282](https://github.com/modular/modular/issues/282) - Default arguments
  are not working as expected
- [Issue #271](https://github.com/modular/modular/issues/271) - Confusing error
  message when converting between function types with different result semantics

## May 2023

### 2023-05-31

#### ⭐️ New

- Mojo Playground now includes the following Python packages (in response to
  [popular demand](https://github.com/modular/modular/discussions/173)):
  `torch`, `tensorflow`, `polars`, `opencv-python`, `keras`, `Pillow`, `plotly`,
  `seaborn`, `sympy`, `transformers`.

- A new optimization is applied to non-trivial copyable values that are passed
  as an owned value without using the transfer (`^`) operator.  Consider code
  like this:

  ```mojo
  var someValue: T = ...
  ...
  takeValueAsOwned(someValue)
  ...
  ```

  When `takeValueAsOwned()` takes its argument as an
  [`owned`](/mojo/manual/values/ownership#transfer-arguments-var-and-)
  value (this is
  common in initializers for example), it is allowed to do whatever it wants
  with the value and destroy it when it is finished. In order to support this,
  the Mojo compiler is forced to make a temporary copy of the `someValue`
  value, and pass that value instead of `someValue`, because there may be other
  uses of `someValue` after the call.

  The Mojo compiler is now smart enough to detect when there are no uses of
  `someValue` later, and it will elide the copy just as if you had manually
  specified the transfer operator like `takeValueAsOwned(someValue^)`.  This
  provides a nice "it just works" behavior for non-trivial types without
  requiring manual management of transfers.

  If you'd like to take full control and expose full ownership for your type,
  just don't make it copyable.  Move-only types require the explicit transfer
  operator so you can see in your code where all ownership transfer happen.

- Similarly, the Mojo compiler now transforms calls to `__copyinit__` methods
  into calls to `__moveinit__` when that is the last use of the source value
  along a control flow path. This allows types which are both copyable and
  movable to get transparent move optimization. For example, the following code
  is compiled into moves instead of copies even without the use of the transfer
  operator:

  ```mojo
    var someValue = somethingCopyableAndMovable()
    use(someValue)
    ...
    let otherValue = someValue      # Last use of someValue
    use(otherValue)
    ...
    var yetAnother = otherValue     # Last use of otherValue
    mutate(yetAnother)
  ```

  This is a significant performance optimization for things like `PythonObject`
  (and more complex value semantic types) that are commonly used in a fluid
  programming style.  These don't want extraneous reference counting operations
  performed by its copy constructor.

  If you want explicit control over copying, it is recommended to use a
  non-dunder `.copy()` method instead of `__copyinit__`, and recall that
  non-copyable types must always use of the transfer operator for those that
  want fully explicit behavior.

#### 🛠️ Fixed

- [Issue #231](https://github.com/modular/modular/issues/231) - Unexpected error
   when a Python expression raises an exception
- [Issue #119](https://github.com/modular/modular/issues/119) - The REPL fails
   when a python variable is redefined

### 2023-05-24

#### ⭐️ New

- `finally` clauses are now supported on `try` statements. In addition, `try`
  statements no longer require `except` clauses, allowing `try-finally` blocks.
  `finally` clauses contain code that is always executed from control-flow
  leaves any of the other clauses of a `try` statement by any means.

#### 🦋 Changed

- `with` statement emission changed to use the new `finally` logic so that

  ```mojo
  with ContextMgr():
      return
  ```

  Will correctly execute `ContextMgr.__exit__` before returning.

#### 🛠️ Fixed

- [Issue #204](https://github.com/modular/modular/issues/204) - Mojo REPL
   crash when returning a String at compile-time
- [Issue #143](https://github.com/modular/modular/issues/143) - synthesized
   init in `@register_passable` type doesn't get correct convention.
- [Issue #201](https://github.com/modular/modular/issues/201) - String literal
   concatenation is too eager.
- [Issue #209](https://github.com/modular/modular/issues/209) - [QoI] Terrible
   error message trying to convert a type to itself.
- [Issue #32](https://github.com/modular/modular/issues/32) - Include struct
   fields in docgen
- [Issue #50](https://github.com/modular/modular/issues/50) - Int to string
   conversion crashes due to buffer overflow
- [Issue #132](https://github.com/modular/modular/issues/132) - PythonObject
   `to_int` method has a misleading name
- [Issue #189](https://github.com/modular/modular/issues/189) - PythonObject bool
   conversion is incorrect
- [Issue #65](https://github.com/modular/modular/issues/65) - Add SIMD
   constructor from Bool
- [Issue #153](https://github.com/modular/modular/issues/153) - Meaning of
   `Time.now` function result is unclear
- [Issue #165](https://github.com/modular/modular/issues/165) - Type in
   `Pointer.free` documentation
- [Issue #210](https://github.com/modular/modular/issues/210) - Parameter results
   cannot be declared outside top-level in function
- [Issue #214](https://github.com/modular/modular/issues/214) - Pointer offset
   calculations at compile-time are incorrect
- [Issue #115](https://github.com/modular/modular/issues/115) - Float printing
   does not include the right number of digits
- [Issue #202](https://github.com/modular/modular/issues/202) -
   `kgen.unreachable` inside nested functions is illegal
- [Issue #235](https://github.com/modular/modular/issues/235) - Crash when
   register passable struct field is not register passable
- [Issue #237](https://github.com/modular/modular/issues/237) - Parameter
   closure sharp edges are not documented

### 2023-05-16

#### ⭐️ New

- Added missing dunder methods to `PythonObject`, enabling the use of common
  arithmetic and logical operators on imported Python values.

- `PythonObject` is now printable from Mojo, instead of requiring you to import
  Python's print function.

#### 🛠️ Fixed

- [Issue #98](https://github.com/modular/modular/issues/98):
  Incorrect error with lifetime tracking in loop.

- [Issue #49](https://github.com/modular/modular/issues/49): Type inference
  issue (?) in 'ternary assignment' operation (FloatLiteral vs. 'SIMD[f32, 1]').

- [Issue #48](https://github.com/modular/modular/issues/48):
  and/or don't work with memory-only types.

- [Issue #11](https://github.com/modular/modular/issues/11): `setitem` Support
  for `PythonObject`.

### 2023-05-11

#### ⭐️ New

- `NDBuffer` and `Buffer` are now constructable via `Pointer` and
  `DTypePointer`.

- `String` now supports indexing with either integers or slices.

- Added factorial function to the `Math` module.

#### 🦋 Changed

- The "byref" syntax with the `&` sigil has changed to use an `inout`
  keyword to be more similar to the `borrowed` and `owned` syntax in arguments.
  Please see [Issue #7](https://github.com/modular/modular/issues/7) for more
  information.

- Optimized the Matrix multiplication implementation in the notebook.
  Initially we were optimizing for expandability rather than performance. We
  have found a way to get the best of both worlds and now the performance of the
  optimized Matmul implementation is 3x faster.

- Renamed the [`^` postfix
operator](/mojo/manual/values/ownership#transfer-arguments-var-and-)
from "consume" to "transfer."

#### 🛠️ Fixed

- Fixed missing overloads for `Testing.assertEqual` so that they work on
`Integer` and `String` values.

- [Issue #6](https://github.com/modular/modular/issues/6):
Playground stops evaluating cells when a simple generic is defined.

- [Issue #18](https://github.com/modular/modular/issues/18):
Memory leak in Python interoperability was removed.

### 2023-05-02

#### 📢 Released

- Mojo publicly launched! This was epic, with lots of great coverage online
including a [wonderful post by Jeremy
Howard](https://www.fast.ai/posts/2023-05-03-mojo-launch.html). The team is
busy this week.

#### ⭐️ New

- Added a Base64 encoding function to perform base64 encoding on strings.

#### 🦋 Changed

- Decreased memory usage of serialization of integers to strings.

- Speedup the sort function.

#### 🛠️ Fixed

- Fixed time unit in the `sleep` function.

## April 2023

### Week of 2023-04-24

- 📢 The default behavior of nested functions has been changed. Mojo nested
  functions that capture are by default are non-parametric, runtime closures,
  meaning that:

  ```mojo
  def foo(x):
      # This:
      def bar(y): return x * y
      # Is the same as:
      let bar = lambda y: x * y
  ```

  These closures cannot have input or result parameters, because they are always
  materialized as runtime values. Values captured in the closure (`x` in the
  above example), are captured by copy: values with copy constructors cannot be
  copied and captures are immutable in the closure.

  Nested functions that don't capture anything are by default "parametric"
  closures: they can have parameters and they can be used as parameter values.
  To restore the previous behavior for capturing closures, "parametric,
  capture-by-unsafe-reference closures", tag the nested function with the
  `@parameter` decorator.

- 📢 Mojo now has full support for "runtime" closures: nested functions that
  capture state materialized as runtime values. This includes taking the address
  of functions, indirect calls, and passing closures around through function
  arguments. Note that capture-by-reference is still unsafe!

  You can also take references to member functions with instances of that class
  using `foo.member_function`, which creates a closure with `foo` bound to the
  `self` argument.

- 📢 Mojo now supports Python style `with` statements and context managers.

  These things are very helpful for implementing things like our
  trace region support and things like Runtime support.

  A context manager in Mojo implements three methods:

  ```mojo
  fn __enter__(self) -> T:
  fn __exit__(self):
  fn __exit__(self, err: Error) -> Bool:
  ```

  The first is invoked when the context is entered, and returns a
  value that may optionally be bound to a target for use in the with
  body. If the with block exits normally, the second method is
  invoked to clean it up. If an error is raised, the third method
  is invoked with the Error value. If that method returns true, the
  error is considered handled, if it returns false, the error is
  re-thrown so propagation continues out of the 'with' block.

- 📢 Mojo functions now support variable scopes! Explicit `var` and `let`
  declarations inside functions can shadow declarations from higher "scopes",
  where a scope is defined as any new indentation block. In addition, the
  `for` loop iteration variable is now scoped to the loop body, so it is
  finally possible to write

  ```mojo
  for i in range(1): pass
  for i in range(2): pass
  ```

- 📢 Mojo now supports an `@value` decorator on structs to reduce boilerplate
  and encourage best practices in value semantics.  The `@value` decorator looks
  to see the struct has a fieldwise initializer (which has arguments for each
  field of the struct), a `__copyinit__` method, and a `__moveinit__` method,
  and synthesizes the missing ones if possible.  For example, if you write:

  ```mojo
  @value
  struct MyPet:
    var name: String
    var age: Int
  ```

  The `@value` decorator will synthesize the following members for you:

  ```mojo
  fn __init__(inout self, owned name: String, age: Int):
      self.name = name^
      self.age = age
  fn __copyinit__(inout self, existing: Self):
      self.name = existing.name
      self.age = existing.age
  fn __moveinit__(inout self, owned existing: Self):
      self.name = existing.name^
      self.age = existing.age
  ```

  This decorator can greatly reduce the boilerplate needed to define common
  aggregates, and gives you best practices in ownership management
  automatically.  The `@value` decorator can be used with types that need custom
  copy constructors (your definition wins).  We can explore having the decorator
  take arguments to further customize its behavior in the future.

- 📚 Memcpy and memcmp now consistently use count as the byte count.

- 📚 Add a variadic string join on strings.

- 📚 Introduce a `reduce_bit_count` method to count the number of 1 across all
  elements in a SIMD vector.

- 📚 Optimize the `pow` function if the exponent is integral.

- 📚 Add a `len` function which dispatches to `__len__` across the different
  structs that support it.

### Week of 2023-04-17

- 📢 Error messages have been significantly improved, thanks to prettier
  printing for Mojo types in diagnostics.

- 📢 Variadic values can now be indexed directly without wrapping them in a
  `VariadicList`!

- 📢 `let` declarations in a function can now be lazily initialized, and `var`
  declarations that are never mutated get a warning suggesting they be converted
  to a `let` declaration.  Lazy initialization allows more flexible patterns of
  initialization than requiring the initializer be inline, e.g.:

  ```mojo
  let x: Int
  if cond:
      x = foo()
  else:
      x = bar()
  use(x)
  ```

- 📢 Functions defined with `def` now return `object` by default, instead of
  `None`. This means you can return values (convertible to `object`) inside
  `def` functions without specifying a return type.

- 📢 The `@raises` decorator has been removed. Raising `fn` should be declared
  by specifying `raises` after the function argument list. The rationale is that
  `raises` is part of the type system, instead of a function modifier.

- 📢 The `BoolLiteral` type has been removed. Mojo now emits `True` and `False`
  directly as `Bool`.

- 📢 Syntax for function types has been added. You can now write function types
  with `fn(Int) -> String` or `async def(&String, *Int) -> None`. No more
  writing `!kgen.signature` types by hand!

- 📢 Float literals are not emitted as `FloatLiteral` instead of an MLIR `f64`
  type!

- 📢 Automatic destructors are now supported by Mojo types, currently spelled
  `fn __del___(owned self):` (the extra underscore will be dropped shortly).
  These destructors work like Python object destructors and similar to C++
  destructors, with the major difference being that they run "as soon as
  possible" after the last use of a value.  This means they are not suitable
  for use in C++-style RAII patterns (use the `with` statement for that, which
  is currently unsupported).

  These should be generally reliable for both memory-only and register-passable
  types, with the caveat that closures are known to *not* capture values
  correctly.  Be very careful with interesting types in the vicinity of a
  closure!

- A new (extremely dangerous!) builtin function is available for low-level
  ownership muckery.  The `__get_address_as_owned_value(x)` builtin takes a
  low-level address value (of `!kgen.pointer` type) and returns an `owned` value
  for the memory that is pointed to.  This value is assumed live at the
  invocation of the builtin, but is "owned" so it needs to be consumed by the
  caller, otherwise it will be automatically destroyed.  This is an effective
  way to do a "placement delete" on a pointer.

  ```mojo
  # "Placement delete": destroy the initialized object begin pointed to.
  _ = __get_address_as_owned_value(somePointer.value)

  # Result value can be consumed by anything that takes it as an 'owned'
  # argument as well.
  consume(__get_address_as_owned_value(somePointer.value))
  ```

- Another magic operator, named `__get_address_as_uninit_lvalue(x)` joins
  the magic LValue operator family.  This operator projects a pointer to
  an LValue like `__get_address_as_lvalue(x)`.  The difference is that
  `__get_address_as_uninit_lvalue(x)` tells the compiler that the pointee is
  uninitialized on entry and initialized on exit, which means that you can use
  it as a "placement new" in C++ sense.  `__get_address_as_lvalue(x)` tells the
  compiler that the pointee is initialized already, so reassigning over it will
  run the destructor.

  ```mojo
  # "*Re*placement new": destroy the existing SomeHeavy value in the memory,
  # then initialize a new value into the slot.
  __get_address_as_lvalue(somePointer.value) = SomeHeavy(4, 5)

  # Ok to use an lvalue, convert to borrow etc.
  use(__get_address_as_lvalue(somePointer.value))

  # "Placement new": Initialize a new value into uninitialied memory.
  __get_address_as_uninit_lvalue(somePointer.value) = SomeHeavy(4, 5)

  # Error, cannot read from uninitialized memory.
  use(__get_address_as_uninit_lvalue(somePointer.value))
  ```

  Note that `__get_address_as_lvalue` assumes that there is already a value at
  the specified address, so the assignment above will run the `SomeHeavy`
  destructor (if any) before reassigning over the value.

- 📢 Implement full support for `__moveinit__` (aka move constructors)

  This implements the ability for memory-only types to define two different
  types of move ctors if they'd like:

  1. `fn __moveinit__(inout self, owned existing: Self)`: Traditional Rust
      style moving constructors that shuffles data around while taking
      ownership of the source binding.
  2. `fn __moveinit__(inout self, inout existing: Self):`: C++ style "stealing"
     move constructors that can be used to take from an arbitrary LValue.

  This gives us great expressive capability (better than Rust/C++/Swift)
  and composes naturally into our lifetime tracking and value
  categorization system.

- The `__call__` method of a callable type has been relaxed to take `self` by
  borrow, allow non-copyable callees to be called.

- Implicit conversions are now invoked in `raise` statements properly, allowing
  converting strings to `Error` type.

- Automatic destructors are turned on for `__del__` instead of `__del___`.

- 📚 Add the builtin FloatLiteral type.

- 📚 Add integral `floordiv` and `mod` for the SIMD type that handle negative
  values.

- 📚 Add an F64 to String converter.

- 📚 Make the `print` function take variadic inputs.

### Week of 2023-04-10

- 📢 Introduce consume operator `x^`

  This introduces the postfix consume operator, which produces an RValue given
  a lifetime tracked object (and, someday, a movable LValue).

- Mojo now automatically synthesizes empty destructor methods for certain types
  when needed.

- The `object` type has been built out into a fully-dynamic type, with dynamic
  function dispatch, with full error handling support.

  ```mojo
  def foo(a) -> object:
      return (a + 3.45) < [1, 2, 3] # raises a TypeError
  ```

- 📢 The `@always_inline` decorator is no longer required for passing capturing
  closures as parameters, for both the functions themselves as functions with
  capturing closures in their parameters. These functions are still inlined but
  it is an implementation detail of capturing parameter closures. Mojo now
  distinguishes between capturing and non-capturing closures. Nested functions
  are capturing by default and can be made non-capturing with the
  `@noncapturing` decorator. A top-level function can be passed as a capturing
  closure by marking it with the `@closure` decorator.

- 📢 Support for list literals has been added. List literals `[1, 2, 3]`
  generate a variadic heterogeneous list type.

- Variadics have been extended to work with memory-primary types.

- Slice syntax is now fully-supported with a new builtin `slice` object, added
  to the compiler builtins. Slice indexing with `a[1:2:3]` now emits calls to
  `__setitem__` and `__getitem__` with a slice object.

- Call syntax has been wired up to `__call__`. You can now `f()` on custom
  types!

- Closures are now explicitly typed as capturing or non-capturing. If a
  function intends to accept a capturing closure, it must specify the
  `capturing` function effect.

- 📚 Add a `Tile2D` function to enable generic `2D` tiling optimizations.

- 📚 Add the `slice` struct to enable getting/setting spans of elements via
  `getitem`/`setitem`.

- 📚 Add syntax sugar to autotuning for both specifying the autotuned values,
  searching, and declaring the evaluation function.

### Week of 2023-04-03

- The `AnyType` and `NoneType` aliases were added and auto-imported in all
  files.

- 📢 The Mojo VS Code extension has been improved with docstring validation. It
  will now warn when a function's docstring has a wrong argument name, for
  example.

- 📢 A new built-in literal type `TupleLiteral` was added in `_CompilerBuiltin`.
  It represents literal tuple values such as `(1, 2.0)` or `()`.

- 📢 The `Int` type has been moved to a new `Builtin` module and is
  auto-imported in all code. The type of integer literals has been changed from
  the MLIR `index` type to the `Int` type.

- Mojo now has a powerful flow-sensitive uninitialized variable checker.  This
  means that you need to initialize values before using them, even if you
  overwrite all subcomponents.  This enables the compiler to reason about the
  true lifetime of values, which is an important stepping stone to getting
  automatic value destruction in place.

- 📢 Call syntax support has been added. Now you can directly call an object
  that implements the `__call__` method, like `foo(5)`.

- 📢 The name for copy constructors got renamed from `__copy__` to
  `__copyinit__`.  Furthermore, non-`@register_passable` types now implement
  it like they do an init method where you fill in a by-reference self, for
  example:

  ```mojo
  fn __copyinit__(inout self, existing: Self):
      self.first = existing.first
      self.second = existing.second
  ```

  This makes copy construction work more similarly to initialization, and
  still keeps copies `x = y` distinct from initialization `x = T(y)`.

- 📢 Initializers for memory-primary types are now required to be in the form
  `__init__(inout self, ...):` with a None result type, but for register primary
  types, it remains in the form `__init__(...) -> Self:`. The `T{}` initializer
  syntax has been removed for memory-primary types.

- Mojo String literals now emit a builtin `StringLiteral` type! One less MLIR
  type to worry about.

- New `__getattr__` and `__setattr__` dunder methods were added. Mojo calls
  these methods on a type when attempting member lookup of a non-static member.
  This allows writing dynamic objects like `x.foo()` where `foo` is not a member
  of `x`.

- Early destructor support has been added. Types can now define a special
  destructor method `__del___` (note three underscores). This is an early
  feature and it is still being built out. There are many caveats, bugs,
  and missing pieces. Stay tuned!

- 📚 Integer division and mod have been corrected for rounding in the presence
  of negative numbers.

- 📚 Add scalar types (UI8, SI32, F32, F64, etc.) which are aliases to
  `SIMD[1, type]`.

## March 2023

### Week of 2023-03-27

- 📢 Parameter names are no longer load-bearing in function signatures. This
   gives more flexibility in defining higher-order functions, because the
   functions passed as parameters do not need their parameter names to match.

   ```mojo
   # Define a higher-order function...
   fn generator[
      func: __mlir_type[`!kgen.signature<`, Int, `>() -> !kgen.none`]
   ]():
      pass

   # Int parameter is named "foo".
   fn f0[foo: Int]():
      pass

   # Int parameter is named "bar".
   fn f1[bar: Int]():
      pass

   fn main():
      # Both can be used as `func`!
      generator[f0]()
      generator[f1]()
   ```

   Stay tuned for improved function type syntax...

- 📢 Two magic operators, named `__get_lvalue_as_address(x)` and
  `__get_address_as_lvalue` convert stored LValues to and from `!kgen.pointer`
  types (respectively).  This is most useful when using the `Pointer[T]`
  library type.  The `Pointer(to=lvalue)` method uses the first one
  internally.  The second one must currently be used explicitly, and can be
  used to project a pointer to a reference that you can pass around and use
  as a self value, for example:

  ```mojo
  # "Replacement new" SomeHeavy value into the memory pointed to by a
  # Pointer[SomeHeavy].
  __get_address_as_lvalue(somePointer.value) = SomeHeavy(4, 5)
  ```

  Note that `__get_address_as_lvalue` assumes that there is already a value at
  the specified address, so the assignment above will run the `SomeHeavy`
  destructor (if any) before reassigning over the value.

- The `(((x)))` syntax is __mlir_op has been removed in favor of
  `__get_lvalue_as_address` which solves the same problem and is more general.

- 📢 When using a mutable `self` argument to a struct `__init__` method, it
  now must be declared with `&`, like any other mutable method.  This clarifies
  the mutation model by making `__init__` consistent with other mutating
  methods.

- 📚 Add variadic string join function.

- 📚 Default initialize values with 0 or null if possible.

- 📚 Add compressed, aligned, and mask store intrinsics.

### Week of 2023-03-20

- Initial `String` type is added to the standard library with some very basic
  methods.

- Add `DimList` to remove the need to use an MLIR list type throughout the
  standard library.

- 📢 The `__clone__` method for copying a value is now named `__copy__` to
  better follow Python term of art.

- 📢 The `__copy__` method now takes its self argument as a "read" value,
  instead of taking it by reference.  This makes it easier to write, works for
  `@register_passable` types, and exposes more optimization opportunities to
  the early optimizer and dataflow analysis passes.

  ```mojo
  # Before:
  fn __clone__(inout self) -> Self: ...

  # After:
  fn __copy__(self) -> Self: ...
  ```

- 📢 A new `@register_passable("trivial")` may be applied to structs that
  have no need for a custom `__copy__` or `__del__` method, and whose state is
  only made up of `@register_passable("trivial")` types.  This eliminates the
  need to define `__copy__` boilerplate and reduces the amount of IR generated
  by the compiler for trivial types like `Int`.

- You can now write back to attributes of structs that are produced by a
  computed lvalue expression.  For example `a[i].x = ..` works when `a[i]`
  is produced with a `__getitem__`/`__setitem__` call.  This is implemented by
  performing a read of `a[i]`, updating the temporary, then doing a writeback.

- The remaining hurdles to using non-parametric, `@register_passable` types as
  parameter values have been cleared. Types like `Int` should enjoy full use as
  parameter values.

- Parameter pack inference has been added to function calls. Calls to functions
  with parameter packs can now elide the pack types:

  ```mojo
  fn foo[*Ts: AnyType](*args: *Ts): pass

  foo(1, 1.2, True, "hello")
  ```

  Note that the syntax for parameter packs has been changed as well.

- 📚 Add the runtime string type.

- 📚 Introduce the DimList struct to remove the need to use low-level MLIR
  operations.

### Week of 2023-03-13

- 📢 Initializers for structs now use `__init__` instead of `__new__`,
  following standard practice in Python.  You can write them in one of two
  styles, either traditional where you mutate self:

  ```mojo
  fn __init__(self, x: Int):
      self.x = x
  ```

  or as a function that returns an instance:

  ```mojo
  fn __init__(x: Int) -> Self:
      return Self {x: x}
  ```

  Note that `@register_passable` types must use the later style.

- 📢 The default argument convention is now the `borrowed` convention.  A
  "read" argument is passed like a C++ `const&` so it doesn't need to
  invoke the copy constructor (aka the `__clone__` method) when passing a value
  to the function.  There are two differences from C++ `const&`:

  1. A future borrow checker will make sure there are no mutable
     aliases with an immutable borrow.
  2. `@register_passable` values are passed directly in an SSA register (and
     thus, usually in a machine register) instead of using an extra reference
     wrapper.  This is more efficient and is the 'right default' for
     `@register_passable` values like integers and pointers.

  This also paves the way to remove the reference requirement from `__clone__`
  method arguments, which will allow us to fill in more support for them.

- Support for variadic pack arguments has been added to Mojo. You can now
  write heterogeneous variadic packs like:

  ```mojo
  fn foo[*Ts: AnyType](args*: Ts): pass

  foo[Int, F32, String, Bool](1, 1.5, "hello", True)
  ```

- The `owned` argument convention has been added. This argument convention
  indicates that the function takes ownership of the argument and is responsible
  for managing its lifetime.

- The `borrowed` argument convention has been added. This convention signifies
  the callee gets an immutable shared reference to a value in the caller's
  context.

- 📚 Add the `getenv` function to the `OS` module to enable getting environment
  variables.

- 📚 Enable the use of dynamic strides in `NDBuffer`.

### Week of 2023-03-06

- 📢 Support added for using capturing async functions as parameters.

- 📢 Returning result parameters has been moved from `return` statements to a
  new `param_return` statement. This allows returning result parameters from
  throwing functions:

  ```mojo
  @raises
  fn foo[() -> out: Int]():
      param_return[42]
      raise Error()
  ```

  And returning different parameters along `@parameter if` branches:

  ```mojo
  fn bar[in: Bool -> out: Int]():
      @parameter
      if in:
          param_return[1]
      else:
          param_return[2]
  ```

- 📢 Mojo now supports omitting returns at the end of functions when they would
  not reachable. For instance,

  ```mojo
  fn foo(cond: Bool) -> Int:
      if cond:
          return 0
      else:
          return 1

  fn bar() -> Int:
      while True:
          pass
  ```

- String literals now support concatenation, so `"hello " "world"` is treated
  the same as `"hello world"`.

- Empty bodies on functions, structs, and control flow statements are no longer
  allowed.  Please use `pass` in them to explicitly mark that they are empty,
  just like in Python.

- 📢 Structs in Mojo now default to living in memory instead of being passed
  around in registers.  This is the right default for generality (large
  structures, structures whose pointer identity matters, etc) and is a key
  technology that enables the borrow model.  For simple types like `Int` and
  `SIMD`, they can be marked as `@register_passable`.

  Note that memory-only types currently have some limitations: they cannot be
  used in generic algorithms that take and return a `!mlirtype` argument, and
  they cannot be used in parameter expressions.  Because of this, a lot of
  types have to be marked `@register_passable` just to work around the
  limitations.  We expect to enable these use-cases over time.

- 📢 Mojo now supports computed lvalues, which means you can finally assign to
  subscript expressions instead of having to call `__setitem__` explicitly.

  Some details on this: Mojo allows you to define multiple `__setitem__`
  overloads, but will pick the one that matches your `__getitem__` type if
  present.  It allows you to pass computed lvalues into inout arguments by
  introducing a temporary copy of the value in question.

- Mojo now has much better support for using register-primary struct types in
  parameter expressions and as the types of parameter values. This will allow
  migration of many standard library types away from using bare MLIR types like
  `__mlir_type.index` and towards using `Int`. This moves us towards getting rid
  of MLIR types everywhere and makes struct types first-class citizens in the
  parameter system.

- 📚 Add a `sort` function.

- 📚 Add non-temporal store to enable cache bypass.

## February 2023

### Week of 2023-02-27

- 📢 The `@interface`, `@implements`, and `@evaluator` trio of decorators have
  been removed, replaced by the `@parameter if` and `@adaptive` features.

- 📢 Parameter inference can now infer the type of variadic lists.

- 📢 Memory primary types are now supported in function results. A result slot
  is allocated in the caller, and the callee writes the result of the function
  into that slow. This is more efficient for large types that don't fit into
  registers neatly! And initializers for memory-primary types now initialize
  the value in-place, instead of emitting a copy!

- Support for `let` decls of memory primary types has been implemented. These
  are constant, ready-only values of memory primary types but which are
  allocated on the function stack.

- Overload conversion resolution and parameter inference has been improved:

  1. Inference now works with `let` decls in some scenarios that weren't
     working before.
  2. Parameter bindings can now infer types into parameter expressions. This
     helps resolve higher-order functions in parameter expressions.

- 📚 Optimize floor, ceil, and ldexp on X86 hardware.

- 📚 Implement the log math function.

### Week of 2023-02-20

- 📢 A new `@__memory_primary` struct decorator has been introduced. Memory
  primary types must always have an address. For instance, they are always
  stack-allocated when declared in a function and their values are passed into
  function calls by address instead of copy. This is in contract with register
  primary types that may not have an address, and which are passed by value
  in function calls. Memory-primary fields are not allowed inside
  register-primary structs, because struct elements are stored in-line.

- 📢 A new `_CompilerBuiltin` module was added. This module defines core types
  and functions of the language that are referenced by the parser, and hence, is
  auto-imported by all other modules. For example new types for literal values
  like the boolean True/False will be included in `_CompilerBuiltin`.

- 📢 A special `__adaptive_set` property can be accessed on a function reference
  marked as `@adaptive`. The property returns the adaptive overload set of that
  function. The return type is a `!kgen.variadic`. This feature is useful to
  implement a generic `evaluate` function in the standard library.

- 📢 A new built-in literal type `BoolLiteral` was added in `_CompilerBuiltin`.
  It represents the literal boolean values `True` and `False`. This is the first
  Mojo literal to be emitted as a standard library type!

- 📚 Add the prefetch intrinsic to enable HW prefetching a cache line.

- 📚 Add the `InlinedFixedVector`, which is optimized for small vectors and stores
  values on both the stack and the heap.

### Week of 2023-02-13

- Unqualified lookups of struct members apply contextual parameters. This means
  for instance that you can refer to static methods without binding the
  struct parameters.

  ```mojo
  struct Foo[x: Int]:
      @staticmethod
      bar(): pass

      foo(self):
          bar()         # implicitly binds to Foo[x].bar()
          Foo[2].bar()  # explicitly bind to another parameter
  ```

- 📢 A new `Self` type refers to the enclosing type with all parameters bound
  to their current values.  This is useful when working with complex parametric
  types, e.g.:

  ```mojo
  struct MyArray[size: Int, element_type: type]:
     fn __new__() -> Self:
         return Self {...}
  ```

  which is a lot nicer than having to say `MyArray[size, element_type]` over
  and over again.

- 📢 Mojo now supports an `@adaptive` decorator. This decorator will supersede
  interfaces, and it represents an overloaded function that is allowed to
  resolve to multiple valid candidates. In that case, the call is emitted as a
  fork, resulting in multiple function candidates to search over.

  ```mojo
  @adaptive
  fn sort(arr: ArraySlice[Int]):
      bubble_sort(arr)

  @adaptive
  fn sort(arr: ArraySlice[Int]):
      merge_sort(arr)

  fn concat_and_sort(lhs: ArraySlice[Int], rhs: ArraySlice[Int]):
      let arr = lhs + rhs
      sort(arr) # this forks compilation, creating two instances
                # of the surrounding function
  ```

- 📢 Mojo now requires that types implement the `__clone__` special member in
  order to copy them.  This allows the safe definition of non-copyable types
  like Atomic.  Note that Mojo still doesn't implement destructors, and (due to
  the absence of non-mutable references) it doesn't actually invoke the
  `__clone__` member when copying a let value. As such, this forces to you as
  a Mojo user to write maximal boilerplate without getting much value out of it.

  In the future, we will reduce the boilerplate with decorators, and we will
  actually start using it. This will take some time to build out though.

- 📢 A special `__mlir_region` statement was added to provide stronger
  invariants around defining MLIR operation regions in Mojo. It similar syntax
  to function declarations, except it there are no results and no input
  conventions.

- 📚 Implement the log math function.

- 📚 Improve the DType struct to enable compile-time equality checks.

- 📚 Add the Complex struct class.

### Week of 2023-02-06

- 📢 The `if` statement now supports a `@parameter` decorator, which requires
  its condition to be a parameter expression, but which only emits the 'True'
  side of the condition to the binary, providing a "static if" functionality.
  This should eliminate many uses of `@interface` that are just used to provide
  different constraint on the implementations.

- 📢 `fn main():` is now automatically exported and directly runnable by the
  command-line `mojo` tool. This is a stop-gap solution to enable script-like
  use cases until we have more of the language built out.

- 🪦 The `@nodebug_inline` feature has been removed, please use
  `@alwaysinline("nodebug")` for methods that must be inlined and that we don't
  want to step into.

- 📢 Python chained comparisons, ex. `a < b < c`, are now supported in Mojo.

- 📢 Functions can now be defined with default argument values, such as
  `def f(x: Int, y: Int = 5):`. The default argument value is used when callers
  do not provide a value for that argument: `f(3)`, for example, uses the
  default argument value of `y = 5`.

- Unused coroutine results are now nicely diagnosed as "missing await" warnings.

- 📚 Introduce a vectorized reduction operations to the SIMD type.

## January 2023

### Week of 2023-01-30

- A basic Mojo language server has been added to the VS Code extension, which
  parses your code as you write it, and provides warnings, errors, and fix-it
  suggestions!

- 💯 The Mojo standard library is now implicitly imported by default.

- The coroutine lowering support was reworked and a new `Coroutine[T]` type was
  implemented. Now, the result of a call to an async function MUST be wrapped in
  a `Coroutine[T]`, or else memory will leak. In the future, when Mojo supports
  destructors and library types as literal types, the results of async function
  calls will automatically wrapped in a `Coroutine[T]`. But today, it must be
  done manually. This type implements all the expected hooks, such as
  `__await__`, and `get()` to retrieve the result. Typical usage:

  ```mojo
  async fn add_three(a: Int, b: Int, c: Int) -> Int:
      return a + b + c

  async fn call_it():
      let task: Coroutine[Int] = add_three(1, 2, 3)
      print(await task)
  ```

- ⭐️ We now diagnose unused expression values at statement context in `fn`
  declarations (but not in `def`s). This catches bugs with unused values, e.g.
  when you forget the parens to call a function.

- 📢 An `@always_inline("nodebug")` function decorator can be used on functions
  that need to be force inlined, but when they should not have debug info in
  the result.  This should be used on methods like `Int.__add__` which should
  be treated as builtin.

- 📢 The `@export` decorator now supports an explicit symbol name to export to,
  for example:

  ```mojo
  @export("baz") # exported as 'baz'
  fn some_mojo_fn_name():
  ```

- 📢 🚧 Subscript syntax is now wired up to the `__getitem__` dunder method.

  This allows type authors to implement the `__getitem__` method to enable
  values to be subscripted.  This is an extended version of the Python semantics
  (given we support overloading) that allows you to define N indices instead of
  a single version that takes a tuple (also convenient because we don't have
  tuples yet).

  Note that this has a very, very important limitation: subscripts are NOT
  wired up to `__setitem__` yet. This means that you can read values with
  `.. = v[i]` but you cannot store to them with `v[i] = ..`.  For this, please
  continue to call `__setitem__` directly.

- 📢 Function calls support parameter inference.

  For calls to functions that have an insufficient number of parameters
  specified at the callsite, we can now infer them from the argument list. We
  do this by matching up the parallel type structure to infer what the
  parameters must be.

  Note that this works left to right in the parameter list, applying explicitly
  specified parameters before trying to infer new ones. This is similar to how
  C++ does things, which means that you may want to reorder the list of
  parameters with this in mind. For example, a `dyn_cast`-like function will be
  more elegant when implemented as:

  `fn dyn_cast[DstType: type, SrcType: type](src: SrcType) -> DstType:`

  Than with the `SrcType`/`DstType` parameters flipped around.

- 📚 Add the growable Dynamic vector struct.

### Week of 2023-01-23

- Inplace operations like `+=`/`__iadd__` may now take `self` by-val if they
  want to, instead of requiring it to be by-ref.
- ⭐️ Inplace operations are no longer allowed to return a non-None value.  The
  corresponding syntax is a statement, not an expression.

- A new `TaskGroup` type was added to the standard library. This type can be
  used to schedule multiple tasks on a multi-threaded workqueue to be executed
  in parallel. An async function can `await` all the tasks at once with the
  taskgroup.

- 📢 We now support for loops! A type that defines an `__iter__` method that
  returns a type that defines `__next__` and `__len__` methods is eligible to
  be used in the statement `for el in X()`. Control flow exits the loop when
  the length is zero.

  This means things like this now work:

  ```mojo
  for item in range(start, end, step):
      print(item)
  ```

- Result parameters now have names. This is useful for referring to result
  parameters in the return types of a function:

  ```mojo
  fn return_simd[() -> nelts: Int]() -> SIMD[f32, nelts]:
  ```

- 📢 We now support homogeneous variadics in value argument lists, using the
  standard Python `fn thing(*args: Int):` syntax! Variadics also have support
  in parameter lists:

  ```mojo
  fn variadic_params_and_args[*a: Int](*b: Int):
      print(a[0])
      print(b[1])
  ```

- 📚 Add the range struct to enable `for ... range(...)` loops.

- 📚 Introduce the unroll generator to allow one to unroll loops via a library
  function.

### Week of 2023-01-16

- 📢 Struct field references are now supported in parameter context, so you
    can use `someInt.value` to get the underlying MLIR thing out of it. This
    should allow using first-class types in parameters more widely.
- 📢 We now support "pretty" initialization syntax for structs, e.g.:

  ```mojo
  struct Int:
      var value: __mlir_type.index
      fn __new__(value: __mlir_type.index) -> Int:
          return Int {value: value}
  ```

  This eliminates the need to directly use the MLIR `lit.struct.create` op in
  struct initializers.  This syntax may change in the future when ownership
  comes in, because we will be able to support the standard `__init__` model
  then.
- 📢 It is now possible to attach regions to `__mlir_op` operations.  This is
  done with a hack that allows an optional `_region` attribute that lists
  references to the region bodies (max 1 region right now due to lack of list
  `[]` literal).
- Nested functions now parse, e.g.:

  ```mojo
  fn foo():
      fn bar():
          pass
      bar()
  ```

- Python-style `async` functions should now work and the `await` expression
  prefix is now supported.  This provides the joy of async/await syntactic
  sugar when working with asynchronous functions.  This is still somewhat
  dangerous to use because we don't have proper memory ownership support yet.

- String literals are now supported.

- Return processing is now handled by a dataflow pass inside the compiler, so
  it is possible to return early out of if statements.

- The parser now supports generating 'fixit' hints on diagnostics, and uses
  them when a dictionary literal uses a colon instead of equal, e.g.:

  ```log
  x.mojo:8:48: error: expected ':' in subscript slice, not '='
      return __mlir_op.`lit.struct.create`[value = 42]()
                                                 ^
                                                 :
  ```

- 📚 Add reduction methods which operate on buffers.

- 📚 Add more math functions like sigmoid, sqrt, rsqrt, etc.

- 📚 Add partial load / store which enable loads and stores that are predicated
  on a condition.

### Week of 2023-01-09

- The `/` and `*` markers in function signatures are now parsed and their
  invariants are checked.  We do not yet support keyword arguments yet though,
  so they aren't very useful.
- Functions now support a new `@nodebug_inline` decorator.
  (Historical note: this was later replaced with `@alwaysinline("nodebug")`).

  Many of the things at the bottom level of the Mojo stack are trivial
  zero-abstraction wrappers around MLIR things, for example, the `+`
  operator on Int or the `__bool__` method on Bool itself.  These operators
  need to be force inlined even at -O0, but they have some additional things
  that we need to wrestle with:

  1. In no case would a user actually want to step into the `__bool__` method on
     Bool or the + method on Int.  This would be terrible debugger QoI for
     unless you're debugging Int itself. We need something like
     `__always_inline__, __nodebug__` attributes that clang uses in headers
     like xmmintrin.h.

  2. Similarly, these "operators" should be treated by users as primitives:
     they don't want to know about MLIR or internal implementation details of
     Int.

  3. These trivial zero abstraction things should be eliminated early in the
     compiler pipeline so they don't slow down the compiler, bloating out the
     call graph with trivial leaves.  Such thing slows down the elaborator,
     interferes with basic MLIR things like fold(), bloats out the IR, or
     bloats out generated debug info.

  4. In a parameter context, we want some of these things to get inlined so
     they can be simplified by the attribute logic and play more nicely with
     canonical types.  This is just a nice to have thing those of us who have
     to stare at generated IR.

  The solution to this is a new `@nodebug_inline` decorator. This decorator
  causes the parser to force-inline the callee instead of generating a call to
  it. While doing so, it gives the operations the location of the call itself
  (that's the "nodebug" part) and strips out let decls that were part of the
  internal implementation details.

  This is a super-power-user-feature intended for those building the standard
  library itself, so it is intentionally limited in power and scope: It can
  only be used on small functions, it doesn't support regions, by-ref, throws,
  async, etc.

- Separately, we now support an `@alwaysInline` decorator on functions. This
  is a general decorator that works on any function, and indicates that the
  function must be inlined. Unlike `@nodebug_inline`, this kind of inlining is
  performed later in the compilation pipeline.

- The `__include` hack has been removed now that we have proper import support.

- `__mlir_op` can now get address of l-value:

  You can use magic `(((x)))` syntax in __mlir_op that forces the `x`
  expression to be an lvalue, and yields its address.  This provides an escape
  hatch (isolated off in `__mlir_op` land) that allows unsafe access to lvalue
  addresses.

- We now support `__rlshift__` and `__rtruediv__`.

- 📢 The parser now resolves scoped alias references.  This allows us to support
  things like `SomeType.someAlias`, forward substituting the value.  This
  unblocks use of aliases in types like `DType`.  We'd like to eventually
  preserve the reference in the AST, but this unblocks library development.

- 📚 Add a `now` function and `Benchmark` struct to enable timing and
  benchmarking.

- 📚 Move more of the computation in NDBuffer from runtime to compile time if
  possible (e.g. when the dimensions are known at compile time).

### Week of 2023-01-02

- 📚 Added the `print` function which works on Integers and SIMD values.

- The frontend now has a new diagnostic subsystem used by the `kgen` tool (but
  not by `kgen-translate` for tests) that supports source ranges on
  diagnostics. Before we'd emit an error like:

  ```log
  x.mojo:13:3: error: invalid call to 'callee': in argument #0, value of type '$F32::F32' cannot be converted to expected type '$int::Int'
    callee(1.0+F32(2.0))
    ^
  x.lit:4:1: note: function declared here
  fn callee(a: Int):
  ^
  ```

   now we produce:

  ```log
  x.mojo:13:3: error: invalid call to 'callee': in argument #0, value of type '$F32::F32' cannot be converted to expected type '$int::Int'
    callee(1.0+F32(2.0))
    ^      ~~~~~~~~~~~~
  x.lit:4:1: note: function declared here
  fn callee(a: Int):
  ^
  ```

- 📢 Parameter results are now supported in a proper way. They are now forward
  declared with an alias declaration and then bound in a call with an arrow,
  e.g.:

  ```mojo
  alias a: __mlir_type.index
  alias b: __mlir_type.index
  idx_result_params[xyz * 2 -> a, b]()
  ```

- Various minor issues with implicit conversions are fixed. For instances,
  implicit conversions are now supported in parameter binding contexts and
  `alias` declarations with explicit types.
- Doc strings are allowed on functions and structs, but they are currently
  discarded by the parser.

- 📚 Add a `print` method!!!

- 📚 Demonstrate a naive matmul in Mojo.

- 📚 Initial work on functions that depend on types (e.g. FPUtils, nan, inf,
  etc.)

- 📚 Allow one to query hardware properties such as simd_width, os, etc. via
  TargetInfo at compile time.

## December 2022

### Week of 2022-12-26

- 📢 You can now call functions in a parameter context! Calling a function in
  a parameter context will evaluate the function at compile time. The result
  can then be used as parameter values. For example,

  ```mojo
  fn fma(x: Int, y: Int, z: Int) -> Int:
      return a + b * c

  fn parameter_call():
      alias nelts = fma(32, 2, 16)
      var x: SIMD[f32, nelts]
  ```

- You can now disable printing of types in an `__mlir_attr` substitution by
   using unary `+` expression.

- 📢 `let` declarations are now supported in functions.  `let` declarations are
  local run-time constant values, which are always rvalues. They complement
  'var' decls (which are mutable lvalues) and are the normal thing to use in
  most cases.  They also generate less IR and are always in SSA form when
  initialized.

  We will want to extend this to support 'let' decls in structs at some point
  and support lazy initialized 'let' declarations (using dataflow analysis) but
  that isn't supported yet.

- 📚 Add the NDBuffer struct.

- Happy new year.

### Week of 2022-12-19

- 📚 Start of the Standard library:
  1. Added Integer and SIMD structs to bootstrap the standard library.
  2. Added very basic buffer data structure.

- We have basic support for parsing parameter results in function calls! Result
  parameters are an important Mojo metaprogramming feature. They allow functions
  to return compile-time constants.

  ```mojo
  fn get_preferred_simdwidthof[() -> nelts: Int]():
      return[2]

  fn vectorized_function():
      get_preferred_simdwidthof[() -> nelts]()
      var x: SIMD[f32, nelts]
  ```

- Types can now be used as parameters of `!kgen.mlirtype` in many more cases.

- MLIR operations with zero results don't need to specify `_type: []` anymore.

- We support parsing triple quoted strings, for writing docstrings for your
  functions and structs!

- A new `__mlir_type[a,b,c]` syntax is available for substituting into MLIR
   types and attributes is available, and the old placeholder approach is
   removed.  This approach has a few advantages beyond what placeholders do:

  1. It's simpler.
  2. It doesn't form the intermediate result with placeholders, which
     gets rejected by MLIR's semantic analysis, e.g. the complex case
     couldn't be expressed before.
  3. It provides a simple way to break long attrs/types across multiple
     lines.

- We now support an `@evaluator` decorator on functions for KGEN evaluators.
  This enables specifying user-defined interface evaluators when performing
  search during compilation.

- 📢 `import` syntax is now supported!

  This handles packaging imported modules into file ops, enables effective
  isolation from the other decls. "import" into the desired context is just
  aliasing decls, with the proper symbols references handle automatically during
  IR generation. As a starting point, this doesn't handle any notion of packages
  (as those haven't been sketched out enough).

- 📢 Reversed binary operators (like `__radd__`) are now looked up and used if
  the forward version (like `__add__`) doesn't work for some reason.

- 📢 Implicit conversions are now generally available, e.g. in assign
  statements, variable initializers etc. There are probably a few more places
  they should work, but we can start eliminating all the extraneous explicit
  casts from literals now.

- Happy Holidays

### Week of 2022-12-12

- 📢 Function overloading now works. Call resolution filters candidate list
  according to the actual parameter and value argument specified at the site of
  the call, diagnosing an error if none of the candidates are viable or if
  multiple are viable and ambiguous. We also consider implicit conversions in
  overload look:

  ```mojo
  fn foo(x: Int): pass
  fn foo(x: F64): pass

  foo(Int(1)) # resolves to the first overload
  foo(1.0)    # resolves to the second overload
  foo(1)      # error: both candidates viable with 1 implicit conversion!
  ```

- The short circuiting binary `and` and `or` expressions are now supported.

- Unary operator processing is a lot more robust, now handling the `not`
  expression and `~x` on Bool.

- 📢 The compiler now generates debug information for use with GDB/LLDB that
  describes variables and functions.

- The first version of the Mojo Visual Studio Code extension has been released!
  It supports syntax highlighting for Mojo files.

- The first version of the `Bool` type has landed in the new Mojo standard
  library!

- 📢 Implicit conversions are now supported in return statements.

### Week of 2022-12-05

- "Discard" patterns are now supported, e.g. `_ = foo()`

- We now support implicit conversions in function call arguments, e.g.
   converting an `index` value to `Int` automatically.  This eliminates a bunch
   of casts, e.g. the need to say F32(1.0) everywhere.

   This is limited for a few reasons that will be improved later:
   1. We don't support overloading, so lots of types aren't convertible
      from all the things they should be, e.g. you can't pass "1" to
      something that expects F32, because F32 can't be created from index.
   2. This doesn't "check to see if we can invoke `__new__`" it force applies
      it on a mismatch, which leads to poor QoI.
   3. This doesn't fix things that need radd.

## November 2022

### Week of 2022-11-28

- 📢 We support the `True` and `False` keywords as expressions.

- 📢 A new `alias` declaration is supported which allows defining local
   parameter values.  This will eventually subsume type aliases and other
   things as it gets built out.

- 📢 We now have end-to-end execution of Mojo files using the `kgen` tool!
  Functions exported with `@export` can be executed.

- 📢 We have try-except-else and `raise` statements and implicit error
  propagation! The error semantics are that `def` can raise by default, but `fn`
  must explicitly declare raising with a `@raises` decorator. Stub out basic
  `Error` type.

- The `&` sigil for by-ref arguments is now specified after the identifier.
  Postfix works better for ref and move operators on the expression
  side because it chains an mentally associates correctly:
  `thing.method().result^`. We don't do that yet, but align param
  decl syntax to it so that things won't be odd looking when we do.
  In practice this looks like:

  ```mojo
  def mutate_argument(a&: index):
      a = 25
  ```

### Week of 2022-11-21

- 📢 The magic `index` type is gone. Long live `__mlir_type.index`.

- Implement parameter substitution into parametric `__mlir_type` decls. This
  allows us to define parametric opaque MLIR types with exposed parameters using
  a new "placeholder" attribute.  This allows us to expose the power of the KGEN
  type parametric system directly into Mojo.

- 📢 Fully-parametric custom types can now be defined and work in Mojo, bringing
  together a lot of the recent work. We can write the SIMD type directly as a
  wrapper around the KGEN type, for example:

  ```mojo
  struct SIMD[dt: __mlir_type.`!kgen.dtype`, nelts: __mlir_type.index]:
      var value:
        __mlir_type.`!pop.simd<#lit<placeholder index>,
                               #lit<placeholder !kgen.dtype>>`[nelts, dt]

      fn __add__(self, rhs: SIMD[dt, nelts]) -> SIMD[dt, nelts]:
          return __mlir_op.`pop.add`(self.value, rhs.value)
  ```

### Week of 2022-11-14

- 📢 Implement a magic `__mlir_type` declaration that can be used to access any
  MLIR type. E.g. `__mlir_type.f64`.

- 📢 Add an `fn` declaration. These are like `def` declarations, but are more
  strict in a few ways: they require type annotations on arguments, don't allow
  implicit variable declarations in their body, and make their arguments rvalues
  instead of lvalues.

- Implemented Swift-style backtick identifiers, which are useful for code
  migration where names may collide with new keywords.

- 📢 A new `__include` directive has been added that performs source-level
  textual includes. This is temporary until we have an `import` model.

- Implement IR generation for arithmetic operators like `+` and `*` in terms
  of the `__add__` and `__mul__` methods.

- 📢 Added support for `break` and `continue` statements, as well as early
  returns inside loops and conditionals!

- 📢 Implemented augmented assignment operators, like `+=` and `@=`.

- 📢 Mojo now has access to generating any MLIR operations (without regions)
  with a new `__mlir_op` magic declaration. We can start to build out the
  language's builtin types with this:

  ```mojo
  struct Int:
      var value: __mlir_type.index

      fn __add__(self, rhs: Int) -> Int:
          return __mlir_op.`index.add`(self.value, rhs.value)
  ```

  Attributes can be attached to the declaration with subscript `[]` syntax,
  and an explicit result type can be specified with a special `_type` attribute
  if it cannot be inferred. Attributes can be accessed via the `__mlir_attr`
  magic decl:

  ```mojo
  __mlir_op.`index.cmp`[
      _type: __mlir_type.i1,
      pred: __mlir_attr.`#index<cmp_predicate slt>`
  ](lhs, rhs)
  ```

- Improved diagnostics emissions with ranges! Now errors highlight the whole
  section of code and not just the first character.

### Week of 2022-11-07

- Implemented the `@interface` and `@implements` decorators, which provide
  access to KGEN generator interfaces. A function marked as an `@interface`
  has no body, but it can be implemented by multiple other functions.

  ```mojo
  @interface
  def add(lhs: index, rhs: index):

  @implements(add)
  def normal_add(lhs: index, rhs: index) -> index:
      return lhs + rhs

  @implements(add)
  def slow_add(lhs: index, rhs: index) -> index:
      wait(1000)
      return normal_add(lhs, rhs)
  ```

- 📢 Support for static struct methods and initializer syntax has been added.
  Initializing a struct with `Foo()` calls an implicitly static `__new__`
  method. This method should be used instead of `__init__` inside structs.

  ```mojo
  struct Foo:
      var value: index

      def __new__() -> Foo:
          var result: Foo
          result.value = Foo.return_a_number() # static method!
          return result

      @staticmethod
      def return_a_number() -> index:
          return 42
  ```

- 📢 Full by-ref argument support. It's now possible to define in-place
  operators like `__iadd__` and functions like `swap(x, y)` correctly.

- 📢 Implemented support for field extract from rvalues, like `x.value` where
  `x` is not an lvalue (`var` declaration or by-ref function argument).

## October 2022

### Week of 2022-10-31

- Revised `return` handling so that a return statement with no expression is
  syntax sugar for `return None`. This enables early exits in functions that
  implicitly return `None` to be cleaner:

  ```mojo
  def just_return():
      return
  ```

- Added support for parsing more expressions: if-else, bitwise operators,
  shift operators, comparisons, floor division, remainder, and matmul.

- 📢 The type of the `self` argument can now be omitted on member methods.

### Week of 2022-10-24

- Added parser support for right-associativity and unary ops, like the power
  operator `a ** b ** c` and negation operator `-a`.

- Add support for `&expr` in Mojo, which allows denoting a by-ref argument in
  functions. This is required because the `self` type of a struct method is
  implicitly a pointer.

- Implemented support for parametric function declarations, such as:

  ```mojo
  struct SIMD[dt: DType, width: index]:
      fn struct_method(self: &SIMD[dt, width]):
          pass

  def fancy_add[dt: DType, width: index](
      lhs: SIMD[dt, width], rhs: SIMD[dt, width]) -> index:
    return width
  ```

### Week of 2022-10-17

- Added explicit variable declarations with `var`, for declaring variables both
  inside functions and structs, with support for type references. Added `index`
  as a temporary built-in type.

  ```mojo
  def foo(lhs: index, rhs: index) -> index:
      var result: index = lhs + rhs
      return result
  ```

- Implemented support for parsing struct declarations and references to type
  declarations in functions! In `def`, the type can be omitted to signal an
  object type.

  ```mojo
  struct Foo:
      var member: index

  def bar(x: Foo, obj) -> index:
      return x.member
  ```

- Implemented parser support for `if` statements and `while` loops!

  ```mojo
  def if_stmt(c: index, a: index, b: index) -> index:
      var result: index = 0
      if c:
          result = a
      else:
          result = b
      return result

  def while_stmt(init: index):
      while init > 1:
          init = init - 1
  ```

- Significantly improved error emission and handling, allowing the parser to
  emit multiple errors while parsing a file.

### Week of 2022-10-10

- Added support for parsing integer, float, and string literals.

- Implemented parser support for function input parameters and results. You can
  now write parametric functions like,

  ```mojo
  def foo[param: Int](arg: Int) -> Int:
      result = param + arg
      return result
  ```

### Week of 2022-10-03

- Added some basic parser scaffolding and initial parser productions, including
  trivial expressions and assignment parser productions.
- Implemented basic scope handling and function IR generation, with support for
  forward declarations. Simple functions like,

  ```mojo
  def foo(x: Int):
  ```

  Now parse! But all argument types are hard-coded to the MLIR `index` type.

- Added IR emission for simple arithmetic expressions on builtin types, like
  `x + y`.

## September 2022

### Week of 2022-09-26

- Mojo's first patch to add a lexer was Sep 27, 2022.

- Settled on `[]` for Mojo generics instead of `<>`. Square brackets are
  consistent with Python generics and don't have the less than ambiguity
  other languages have.
