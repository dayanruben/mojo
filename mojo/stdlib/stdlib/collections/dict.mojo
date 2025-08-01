# ===----------------------------------------------------------------------=== #
# Copyright (c) 2025, Modular Inc. All rights reserved.
#
# Licensed under the Apache License v2.0 with LLVM Exceptions:
# https://llvm.org/LICENSE.txt
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ===----------------------------------------------------------------------=== #
"""Defines `Dict`, a collection that stores key-value pairs.

Dict provides an efficient, O(1) amortized
average-time complexity for insert, lookup, and removal of dictionary elements.
Its implementation closely mirrors Python's `dict` implementation:

- Performance and size are heavily optimized for small dictionaries, but can
  scale to large dictionaries.

- Insertion order is implicitly preserved. Iteration over keys, values, and
  items have a deterministic order based on insertion.

- For more information on the Mojo `Dict` type, see the
  [Mojo `Dict` manual](/mojo/manual/types/#dict). To learn more about using
  Python dictionaries from Mojo, see
  [Python types in Mojo](/mojo/manual/python/types/#python-types-in-mojo).

Key elements must implement the `KeyElement` trait, which encompasses
Movable, Hashable, and EqualityComparable. It also includes Copyable and Movable
until we push references through the standard library types.

Value elements must be CollectionElements for a similar reason. Both key and
value types must always be Movable so we can resize the dictionary as it grows.

See the `Dict` docs for more details.
"""

from hashlib import Hasher, default_hasher, default_comp_time_hasher
from sys.intrinsics import likely
from memory import bitcast, memcpy


alias KeyElement = Copyable & Movable & Hashable & EqualityComparable
"""A trait composition for types which implement all requirements of
dictionary keys. Dict keys must minimally be Copyable, Movable, Hashable,
and EqualityComparable for a hash map. Until we have references
they must also be copyable."""


@fieldwise_init
struct _DictEntryIter[
    mut: Bool, //,
    K: KeyElement,
    V: Copyable & Movable,
    H: Hasher,
    origin: Origin[mut],
    forward: Bool = True,
](Copyable, Movable):
    """Iterator over immutable DictEntry references.

    Parameters:
        mut: Whether the reference to the dictionary is mutable.
        K: The key type of the elements in the dictionary.
        V: The value type of the elements in the dictionary.
        H: The type of the hasher in the dictionary.
        origin: The origin of the List
        forward: The iteration direction. `False` is backwards.
    """

    alias Element = DictEntry[K, V, H]

    var index: Int
    var seen: Int
    var src: Pointer[Dict[K, V, H], origin]

    fn __init__(
        out self, index: Int, seen: Int, ref [origin]dict: Dict[K, V, H]
    ):
        self.index = index
        self.seen = seen
        self.src = Pointer(to=dict)

    fn __iter__(self) -> Self:
        return self

    @always_inline
    fn __has_next__(self) -> Bool:
        return self.seen < len(self.src[])

    @always_inline
    fn __next__(
        mut self,
    ) -> ref [self.src[]._entries[0].value()] Self.Element:
        while True:
            ref opt_entry_ref = self.src[]._entries[self.index]

            @parameter
            if forward:
                self.index += 1
            else:
                self.index -= 1

            if opt_entry_ref:
                self.seen += 1
                return opt_entry_ref.value()


@fieldwise_init
struct _DictKeyIter[
    mut: Bool, //,
    K: KeyElement,
    V: Copyable & Movable,
    H: Hasher,
    origin: Origin[mut],
    forward: Bool = True,
](Copyable, Iterator, Movable):
    """Iterator over immutable Dict key references.

    Parameters:
        mut: Whether the reference to the vector is mutable.
        K: The key type of the elements in the dictionary.
        V: The value type of the elements in the dictionary.
        H: The type of the hasher in the dictionary.
        origin: The origin of the List
        forward: The iteration direction. `False` is backwards.
    """

    alias dict_entry_iter = _DictEntryIter[K, V, H, origin, forward]
    alias Element = K

    var iter: Self.dict_entry_iter

    @always_inline
    fn __iter__(self) -> Self:
        return self

    @always_inline
    fn __has_next__(self) -> Bool:
        return self.iter.__has_next__()

    fn __next_ref__(mut self) -> ref [self.iter.__next__().key] Self.Element:
        return self.iter.__next__().key

    @always_inline
    fn __next__(mut self) -> Self.Element:
        return self.__next_ref__()


@fieldwise_init
struct _DictValueIter[
    mut: Bool, //,
    K: KeyElement,
    V: Copyable & Movable,
    H: Hasher,
    origin: Origin[mut],
    forward: Bool = True,
](Copyable, Iterator, Movable):
    """Iterator over Dict value references. These are mutable if the dict
    is mutable.

    Parameters:
        mut: Whether the reference to the vector is mutable.
        K: The key type of the elements in the dictionary.
        V: The value type of the elements in the dictionary.
        H: The type of the hasher in the dictionary.
        origin: The origin of the List
        forward: The iteration direction. `False` is backwards.
    """

    var iter: _DictEntryIter[K, V, H, origin, forward]
    alias Element = V

    fn __iter__(self) -> Self:
        return self

    fn __reversed__(self) -> _DictValueIter[K, V, H, origin, False]:
        var src = self.iter.src
        return _DictValueIter(
            _DictEntryIter[K, V, H, origin, False](
                src[]._reserved() - 1, 0, src
            )
        )

    @always_inline
    fn __has_next__(self) -> Bool:
        return self.iter.__has_next__()

    fn __next_ref__(mut self) -> ref [origin] Self.Element:
        ref entry_ref = self.iter.__next__()
        # Cast through a pointer to grant additional mutability because
        # _DictEntryIter.next erases it.
        return UnsafePointer(to=entry_ref.value).origin_cast[origin=origin]()[]

    @always_inline
    fn __next__(mut self) -> Self.Element:
        return self.__next_ref__()


@fieldwise_init
struct DictEntry[K: KeyElement, V: Copyable & Movable, H: Hasher](
    Copyable, ExplicitlyCopyable, Movable
):
    """Store a key-value pair entry inside a dictionary.

    Parameters:
        K: The key type of the dict. Must be Hashable+EqualityComparable.
        V: The value type of the dict.
        H: The type of the hasher used to hash the key.
    """

    var hash: UInt64
    """`key.__hash__()`, stored so hashing isn't re-computed during dict
    lookup."""
    var key: K
    """The unique key for the entry."""
    var value: V
    """The value associated with the key."""

    fn __init__(out self, var key: K, var value: V):
        """Create an entry from a key and value, computing the hash.

        Args:
            key: The key of the entry.
            value: The value of the entry.
        """
        self.hash = hash[HasherType=H](key)
        self.key = key^
        self.value = value^

    fn copy(self) -> Self:
        """Copy an existing entry.

        Returns:
            A copy of the value.
        """
        return self

    fn reap_value(var self, out result: V):
        """Take the value from an owned entry.

        Returns:
            The value of the entry.
        """
        result = self.value^
        __disable_del self


alias _EMPTY = -1
alias _REMOVED = -2


struct _DictIndex(Movable):
    """A compact dict-index type. Small dict indices are compressed
    to smaller integer types to use less memory.

    _DictIndex doesn't store its own size, so the size must be passed in to
    its indexing methods.

    Ideally this could be type-parameterized so that the size checks don't
    need to be performed at runtime, but I couldn't find a way to express
    this in the current type system.
    """

    var data: OpaquePointer

    @always_inline
    @implicit
    fn __init__(out self, reserved: Int):
        if reserved <= 128:
            var data = UnsafePointer[Int8].alloc(reserved)
            for i in range(reserved):
                data[i] = _EMPTY
            self.data = data.bitcast[NoneType]()
        elif reserved <= 2**16 - 2:
            var data = UnsafePointer[Int16].alloc(reserved)
            for i in range(reserved):
                data[i] = _EMPTY
            self.data = data.bitcast[NoneType]()
        elif reserved <= 2**32 - 2:
            var data = UnsafePointer[Int32].alloc(reserved)
            for i in range(reserved):
                data[i] = _EMPTY
            self.data = data.bitcast[NoneType]()
        else:
            var data = UnsafePointer[Int64].alloc(reserved)
            for i in range(reserved):
                data[i] = _EMPTY
            self.data = data.bitcast[NoneType]()

    fn copy(self, reserved: Int) -> Self:
        var index = Self(reserved)
        if reserved <= 128:
            var data = self.data.bitcast[Int8]()
            var new_data = index.data.bitcast[Int8]()
            memcpy(new_data, data, reserved)
        elif reserved <= 2**16 - 2:
            var data = self.data.bitcast[Int16]()
            var new_data = index.data.bitcast[Int16]()
            memcpy(new_data, data, reserved)
        elif reserved <= 2**32 - 2:
            var data = self.data.bitcast[Int32]()
            var new_data = index.data.bitcast[Int32]()
            memcpy(new_data, data, reserved)
        else:
            var data = self.data.bitcast[Int64]()
            var new_data = index.data.bitcast[Int64]()
            memcpy(new_data, data, reserved)
        return index^

    fn __moveinit__(out self, owned existing: Self):
        self.data = existing.data

    fn get_index(self, reserved: Int, slot: UInt64) -> Int:
        if reserved <= 128:
            var data = self.data.bitcast[Int8]()
            return Int(data.load(slot & (reserved - 1)))
        elif reserved <= 2**16 - 2:
            var data = self.data.bitcast[Int16]()
            return Int(data.load(slot & (reserved - 1)))
        elif reserved <= 2**32 - 2:
            var data = self.data.bitcast[Int32]()
            return Int(data.load(slot & (reserved - 1)))
        else:
            var data = self.data.bitcast[Int64]()
            return Int(data.load(slot & (reserved - 1)))

    fn set_index(mut self, reserved: Int, slot: UInt64, value: Int):
        if reserved <= 128:
            var data = self.data.bitcast[Int8]()
            return data.store(slot & (reserved - 1), value)
        elif reserved <= 2**16 - 2:
            var data = self.data.bitcast[Int16]()
            return data.store(slot & (reserved - 1), value)
        elif reserved <= 2**32 - 2:
            var data = self.data.bitcast[Int32]()
            return data.store(slot & (reserved - 1), value)
        else:
            var data = self.data.bitcast[Int64]()
            return data.store(slot & (reserved - 1), value)

    fn __del__(owned self):
        self.data.free()


struct Dict[K: KeyElement, V: Copyable & Movable, H: Hasher = default_hasher](
    Boolable, Copyable, Defaultable, ExplicitlyCopyable, Movable, Sized
):
    """A container that stores key-value pairs.

    Parameters:
        K: The type of the dictionary key. Must be `Hashable` and
            `EqualityComparable` so we can find the key in the map.
        V: The value type of the dictionary. Currently must be
            Copyable & Movable.
        H: The type of the hasher used to hash the keys.

    The key type and value type must be specified statically, unlike a Python
    dictionary, which can accept arbitrary key and value types.

    The key type must implement the `KeyElement` trait, which encompasses
    `Movable`, `Hashable`, and `EqualityComparable`. It also includes `Copyable`
    and `Movable` until we have references.

    The value type must implement the `Copyable` and `Movable` traits.

    Examples:

    ```mojo
    var d = Dict[String, Int]()
    d["a"] = 1
    d["b"] = 2
    print(len(d))      # prints 2
    print(d["a"])      # prints 1
    print(d.pop("b"))  # prints 2
    print(len(d))      # prints 1
    ```

    For more information on the Mojo `Dict` type, see the
    [Mojo `Dict` manual](/mojo/manual/types/#dict). To learn more about using
    Python dictionaries from Mojo, see
    [Python types in Mojo](/mojo/manual/python/types/#python-types-in-mojo).
    """

    # Implementation:
    #
    # `Dict` provides an efficient, O(1) amortized average-time complexity for
    # insert, lookup, and removal of dictionary elements.
    #
    # Its implementation closely mirrors Python's `dict` implementation:
    #
    # - Performance and size are heavily optimized for small dictionaries, but can
    #     scale to large dictionaries.
    # - Insertion order is implicitly preserved. Once `__iter__` is implemented
    #     it will return a deterministic order based on insertion.
    # - To achieve this, elements are stored in a dense array. Inserting a new
    #     element will append it to the entry list, and then that index will be stored
    #     in the dict's index hash map. Removing an element updates that index to
    #     a special `REMOVED` value for correctness of the probing sequence, and
    #     the entry in the entry list is marked as removed and the relevant data is freed.
    #     The entry can be re-used to insert a new element, but it can't be reset to
    #     `EMPTY` without compacting or resizing the dictionary.
    # - The index probe sequence is taken directly from Python's dict implementation:
    #
    #     ```mojo
    #     var slot = hash(key) % self._reserved
    #     var perturb = hash(key)
    #     while True:
    #         check_slot(slot)
    #         alias PERTURB_SHIFT = 5
    #         perturb >>= PERTURB_SHIFT
    #         slot = ((5 * slot) + perturb + 1) % self._reserved
    #     ```
    #
    # - Similarly to Python, we aim for a maximum load of 2/3, after which we resize
    #     to a larger dictionary.
    # - In the case where many entries are being added and removed, the dictionary
    #     can fill up with `REMOVED` entries without being resized. In this case
    #     we will eventually "compact" the dictionary and shift entries towards
    #     the beginning to free new space while retaining insertion order.
    #
    # Key elements must implement the `KeyElement` trait, which encompasses
    # Movable, Hashable, and EqualityComparable. It also includes Copyable
    # and Movable until we have references.
    #
    # Value elements must be CollectionElements for a similar reason. Both key and
    # value types must always be Movable so we can resize the dictionary as it grows.
    #
    # Without conditional trait conformance, making a `__str__` representation for
    # Dict is tricky. We'd need to add `Stringable` to the requirements for keys
    # and values. This may be worth it.
    #
    # Invariants:
    #
    # - size = 2^k for integer k:
    #     This allows for faster entry slot lookups, since modulo can be
    #     optimized to a bit shift for powers of 2.
    #
    # - size <= 2/3 * _reserved
    #     If size exceeds this invariant, we double the size of the dictionary.
    #     This is the maximal "load factor" for the dict. Higher load factors
    #     trade off higher memory utilization for more frequent worst-case lookup
    #     performance. Lookup is O(n) in the worst case and O(1) in average case.
    #
    # - _n_entries <= 3/4 * _reserved
    #     If _n_entries exceeds this invariant, we compact the dictionary, retaining
    #     the insertion order while resetting _n_entries = size.
    #     As elements are removed, they retain marker entries for the probe sequence.
    #     The average case miss lookup (ie. `contains` check on a key not in the dict)
    #     is O(_reserved  / (1 + _reserved - _n_entries)). At `(k-1)/k` this
    #     approaches `k` and is therefore O(1) average case. However, we want it to
    #     be _larger_ than the load factor: since `compact` is O(n), we don't
    #     don't churn and compact on repeated insert/delete, and instead amortize
    #     compaction cost to O(1) amortized cost.

    # ===-------------------------------------------------------------------===#
    # Aliases
    # ===-------------------------------------------------------------------===#

    alias EMPTY = _EMPTY
    alias REMOVED = _REMOVED
    alias _initial_reservation = 8

    # ===-------------------------------------------------------------------===#
    # Fields
    # ===-------------------------------------------------------------------===#

    var _len: Int
    """The number of elements currently stored in the dict."""
    var _n_entries: Int
    """The number of entries currently allocated."""

    var _index: _DictIndex

    # We use everything available in the list. Which means that
    # len(self._entries) == self._entries.capacity == self._reserved()
    var _entries: List[Optional[DictEntry[K, V, H]]]

    # ===-------------------------------------------------------------------===#
    # Life cycle methods
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn __init__(out self):
        """Initialize an empty dictiontary."""
        self._len = 0
        self._n_entries = 0
        self._entries = Self._new_entries(Self._initial_reservation)
        self._index = _DictIndex(len(self._entries))

    @always_inline
    fn __init__(out self, *, power_of_two_initial_capacity: Int):
        """Initialize an empty dictiontary with a pre-reserved initial capacity.

        Args:
            power_of_two_initial_capacity: At least 8, has to be a power of two.

        Examples:

        ```mojo
        var x = Dict[Int, Int](power_of_two_initial_capacity = 1024)
        # Insert (2/3 of 1024) entries without reallocation.
        ```
        """
        debug_assert(
            power_of_two_initial_capacity.is_power_of_two()
            and power_of_two_initial_capacity >= 8,
            "power_of_two_initial_capacity need to be >=8 and a power of two",
        )
        self._len = 0
        self._n_entries = 0
        self._entries = Self._new_entries(power_of_two_initial_capacity)
        self._index = _DictIndex(len(self._entries))

    @always_inline
    fn __init__(
        out self,
        owned keys: List[K],
        owned values: List[V],
        __dict_literal__: (),
    ):
        """Constructs a dictionary from the given keys and values.

        Args:
            keys: The list of keys to build the dictionary with.
            values: The corresponding values to pair with the keys.
            __dict_literal__: Tell Mojo to use this method for dict literals.
        """
        # TODO: Use power_of_two_initial_capacity to reserve space.
        self = Self()
        debug_assert(
            len(keys) == len(values),
            "keys and values must have the same length",
        )

        # TODO: Should transfer the key/value's from the list to avoid copying
        # the values.
        for i in range(len(keys)):
            self._insert(keys[i], values[i])

    # TODO: add @property when Mojo supports it to make
    # it possible to do `self._reserved`.
    @always_inline
    fn _reserved(self) -> Int:
        return len(self._entries)

    @always_inline
    fn copy(self) -> Self:
        """Copy an existing dictiontary.

        Returns:
            A copy of the value.
        """
        return self

    @staticmethod
    fn fromkeys(keys: List[K, *_], value: V) -> Self:
        """Create a new dictionary with keys from list and values set to value.

        Args:
            keys: The keys to set.
            value: The value to set.

        Returns:
            The new dictionary.
        """
        var my_dict = Dict[K, V, H]()
        for key in keys:
            my_dict[key] = value
        return my_dict

    @staticmethod
    fn fromkeys(
        keys: List[K, *_], value: Optional[V] = None
    ) -> Dict[K, Optional[V], H]:
        """Create a new dictionary with keys from list and values set to value.

        Args:
            keys: The keys to set.
            value: The value to set.

        Returns:
            The new dictionary.
        """
        return Dict[K, Optional[V], H].fromkeys(keys, value)

    fn __copyinit__(out self, existing: Self):
        """Copy an existing dictiontary.

        Args:
            existing: The existing dict.
        """
        self._len = existing._len
        self._n_entries = existing._n_entries
        self._index = existing._index.copy(existing._reserved())
        self._entries = existing._entries

    # ===-------------------------------------------------------------------===#
    # Operator dunders
    # ===-------------------------------------------------------------------===#

    fn __getitem__(
        self, key: K
    ) raises -> ref [self._entries[0].value().value] Self.V:
        """Retrieve a value out of the dictionary.

        Args:
            key: The key to retrieve.

        Returns:
            The value associated with the key, if it's present.

        Raises:
            "KeyError" if the key isn't present.
        """
        return self._find_ref(key)

    fn __setitem__(mut self, var key: K, var value: V):
        """Set a value in the dictionary by key.

        Args:
            key: The key to associate with the specified value.
            value: The data to store in the dictionary.
        """
        self._insert(key^, value^)

    fn __contains__(self, key: K) -> Bool:
        """Check if a given key is in the dictionary or not.

        Args:
            key: The key to check.

        Returns:
            True if the key exists in the dictionary, False otherwise.
        """
        return self._find_index(hash[HasherType=H](key), key)[0]

    fn __iter__(ref self) -> _DictKeyIter[K, V, H, __origin_of(self)]:
        """Iterate over the dict's keys as immutable references.

        Returns:
            An iterator of immutable references to the dictionary keys.
        """
        return _DictKeyIter(_DictEntryIter(0, 0, self))

    fn __reversed__(
        ref self,
    ) -> _DictKeyIter[K, V, H, __origin_of(self), False]:
        """Iterate backwards over the dict keys, returning immutable references.

        Returns:
            A reversed iterator of immutable references to the dict keys.
        """
        return _DictKeyIter(
            _DictEntryIter[forward=False](self._reserved() - 1, 0, self)
        )

    fn __or__(self, other: Self) -> Self:
        """Merge self with other and return the result as a new dict.

        Args:
            other: The dictionary to merge with.

        Returns:
            The result of the merge.
        """
        var result = self.copy()
        result.update(other)
        return result^

    fn __ior__(mut self, other: Self):
        """Merge self with other in place.

        Args:
            other: The dictionary to merge with.
        """
        self.update(other)

    # ===-------------------------------------------------------------------===#
    # Trait implementations
    # ===-------------------------------------------------------------------===#

    fn __len__(self) -> Int:
        """The number of elements currently stored in the dictionary.

        Returns:
            The number of elements currently stored in the dictionary.
        """
        return self._len

    fn __bool__(self) -> Bool:
        """Check if the dictionary is empty or not.

        Returns:
            `False` if the dictionary is empty, `True` if there is at least one
            element.
        """
        return len(self).__bool__()

    @no_inline
    fn __str__[
        T: KeyElement & Representable, U: Copyable & Movable & Representable, //
    ](self: Dict[T, U]) -> String:
        """Returns a string representation of a `Dict`.

        Parameters:
            T: The type of the keys in the Dict. Must implement the
                traits `Representable` and `KeyElement`.
            U: The type of the values in the Dict. Must implement the
                traits `Representable`, `Copyable` and `Movable`.

        Returns:
            A string representation of the Dict.

        Notes:
            Since we can't condition methods on a trait yet, the way to call
            this method is a bit special. Here is an example below:

            ```mojo
            var my_dict = Dict[Int, Float64]()
            my_dict[1] = 1.1
            my_dict[2] = 2.2
            dict_as_string = my_dict.__str__()
            print(dict_as_string)
            # prints "{1: 1.1, 2: 2.2}"
            ```

            When the compiler supports conditional methods, then a simple
            `String(my_dict)` will be enough.
        """
        var minimum_capacity = self._minimum_size_of_string_representation()
        var result = String(capacity=minimum_capacity)
        result += "{"

        var i = 0
        for key_value in self.items():
            result += repr(key_value.key) + ": " + repr(key_value.value)
            if i < len(self) - 1:
                result += ", "
            i += 1
        result += "}"
        return result

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    fn _minimum_size_of_string_representation(self) -> Int:
        # we do a rough estimation of the minimum number of chars that we'll see
        # in the string representation, we assume that String(key) and String(value)
        # will be both at least one char.
        return (
            2  # '{' and '}'
            + len(self) * 6  # String(key), String(value) ": " and ", "
            - 2  # remove the last ", "
        )

    fn find(self, key: K) -> Optional[V]:
        """Find a value in the dictionary by key.

        Args:
            key: The key to search for in the dictionary.

        Returns:
            An optional value containing a copy of the value if it was present,
            otherwise an empty Optional.
        """

        try:
            return self._find_ref(key)
        except:
            return Optional[V](None)

    fn _find_ref(
        ref self, key: K
    ) raises -> ref [self._entries[0].value().value] Self.V:
        """Find a value in the dictionary by key.

        Args:
            key: The key to search for in the dictionary.

        Returns:
            An optional value containing a reference to the value if it is
            present, otherwise an empty Optional.
        """
        var hash = hash[HasherType=H](key)
        var found, _, index = self._find_index(hash, key)

        if found:
            ref entry = self._entries[index]
            debug_assert(entry.__bool__(), "entry in index must be full")
            # SAFETY: We just checked that `entry` is present.
            return entry.unsafe_value().value

        raise Error("KeyError")

    fn get(self, key: K) -> Optional[V]:
        """Get a value from the dictionary by key.

        Args:
            key: The key to search for in the dictionary.

        Returns:
            An optional value containing a copy of the value if it was present,
            otherwise an empty Optional.
        """
        return self.find(key)

    fn get(self, key: K, default: V) -> V:
        """Get a value from the dictionary by key.

        Args:
            key: The key to search for in the dictionary.
            default: Default value to return.

        Returns:
            A copy of the value if it was present, otherwise default.
        """
        return self.find(key).or_else(default)

    fn pop(mut self, key: K, var default: V) -> V:
        """Remove a value from the dictionary by key.

        Args:
            key: The key to remove from the dictionary.
            default: A default value to return if the key
                was not found instead of raising.

        Returns:
            The value associated with the key, if it was in the dictionary.
            If it wasn't, return the provided default value instead.
        """
        try:
            return self.pop(key)
        except:
            return default

    fn pop(mut self, key: K) raises -> V:
        """Remove a value from the dictionary by key.

        Args:
            key: The key to remove from the dictionary.

        Returns:
            The value associated with the key, if it was in the dictionary.
            Raises otherwise.

        Raises:
            "KeyError" if the key was not present in the dictionary.
        """
        var hash = hash[HasherType=H](key)
        var found, slot, index = self._find_index(hash, key)
        if found:
            self._set_index(slot, Self.REMOVED)
            ref entry = self._entries[index]
            debug_assert(entry.__bool__(), "entry in index must be full")
            var entry_value = entry.unsafe_take()
            entry = None
            self._len -= 1
            return entry_value^.reap_value()
        raise Error("KeyError")

    fn popitem(mut self) raises -> DictEntry[K, V, H]:
        """Remove and return a (key, value) pair from the dictionary.

        Returns:
            Last dictionary item

        Raises:
            "KeyError" if the dictionary is empty.

        Notes:
            Pairs are returned in LIFO order. popitem() is useful to
            destructively iterate over a dictionary, as often used in set
            algorithms. If the dictionary is empty, calling popitem() raises a
            KeyError.
        """

        var key = Optional[K](None)
        var val = Optional[V](None)

        for item in reversed(self.items()):
            key = Optional(item.key)
            val = Optional(item.value)
            break

        if key:
            _ = self.pop(key.value())
            return DictEntry[K, V, H](key.value(), val.value())

        raise "KeyError: popitem(): dictionary is empty"

    fn keys(ref self) -> _DictKeyIter[K, V, H, __origin_of(self)]:
        """Iterate over the dict's keys as immutable references.

        Returns:
            An iterator of immutable references to the dictionary keys.
        """
        return Self.__iter__(self)

    fn values(ref self) -> _DictValueIter[K, V, H, __origin_of(self)]:
        """Iterate over the dict's values as references.

        Returns:
            An iterator of references to the dictionary values.
        """
        return _DictValueIter(_DictEntryIter(0, 0, self))

    fn items(ref self) -> _DictEntryIter[K, V, H, __origin_of(self)]:
        """Iterate over the dict's entries as immutable references.

        Returns:
            An iterator of immutable references to the dictionary entries.

        Examples:

        ```mojo
        var my_dict = Dict[String, Int]()
        my_dict["a"] = 1
        my_dict["b"] = 2

        for e in my_dict.items():
            print(e.key, e.value)
        ```

        Notes:
            These can't yet be unpacked like Python dict items, but you can
            access the key and value as attributes.
        """
        return _DictEntryIter(0, 0, self)

    fn update(mut self, other: Self, /):
        """Update the dictionary with the key/value pairs from other,
        overwriting existing keys.

        Args:
            other: The dictionary to update from.

        Notes:
            The argument must be positional only.
        """
        for entry in other.items():
            self[entry.key] = entry.value

    fn clear(mut self):
        """Remove all elements from the dictionary."""
        self._len = 0
        self._n_entries = 0
        self._entries = Self._new_entries(Self._initial_reservation)
        self._index = _DictIndex(self._reserved())

    fn setdefault(
        mut self, key: K, var default: V
    ) -> ref [self._entries[0].value().value] V:
        """Get a value from the dictionary by key, or set it to a default if it
        doesn't exist.

        Args:
            key: The key to search for in the dictionary.
            default: The default value to set if the key is not present.

        Returns:
            The value associated with the key, or the default value if it wasn't
            present.
        """
        self._maybe_resize()
        var found, slot, index = self._find_index(hash[HasherType=H](key), key)
        ref entry = self._entries[index]
        if not found:
            entry = DictEntry[H=H](key, default^)
            self._set_index(slot, index)
            self._len += 1
            self._n_entries += 1
        return entry.unsafe_value().value

    @staticmethod
    @always_inline
    fn _new_entries(
        reserve_at_least: Int,
    ) -> List[Optional[DictEntry[K, V, H]]]:
        var entries = List[Optional[DictEntry[K, V, H]]](
            capacity=reserve_at_least
        )
        # We have memory available, we'll use everything.
        for _ in range(entries.capacity):
            entries.append(None)
        return entries

    fn _insert(mut self, owned key: K, owned value: V):
        self._insert(DictEntry[K, V, H](key^, value^))

    fn _insert[
        safe_context: Bool = False
    ](mut self, owned entry: DictEntry[K, V, H]):
        @parameter
        if not safe_context:
            self._maybe_resize()
        var found, slot, index = self._find_index(entry.hash, entry.key)

        self._entries[index] = entry^
        if not found:
            self._set_index(slot, index)
            self._len += 1
            self._n_entries += 1

    fn _get_index(self, slot: UInt64) -> Int:
        return self._index.get_index(self._reserved(), slot)

    fn _set_index(mut self, slot: UInt64, index: Int):
        return self._index.set_index(self._reserved(), slot, index)

    fn _next_index_slot(self, mut slot: UInt64, mut perturb: UInt64):
        alias PERTURB_SHIFT = 5
        perturb >>= PERTURB_SHIFT
        slot = ((5 * slot) + Int(perturb + 1)) & (self._reserved() - 1)

    fn _find_empty_index(self, hash: UInt64) -> UInt64:
        var slot = hash & (self._reserved() - 1)
        var perturb = hash
        while True:
            var index = self._get_index(slot)
            if index == Self.EMPTY:
                return slot
            self._next_index_slot(slot, perturb)

    fn _find_index(self, hash: UInt64, key: K) -> (Bool, UInt64, Int):
        # Return (found, slot, index)
        var slot = hash & (self._reserved() - 1)
        var perturb = hash
        while True:
            var index = self._get_index(slot)
            if index == Self.EMPTY:
                return (False, slot, self._n_entries)
            elif index == Self.REMOVED:
                pass
            else:
                ref entry = self._entries[index]
                debug_assert(entry.__bool__(), "entry in index must be full")
                ref val = entry.unsafe_value()
                if val.hash == hash and likely(val.key == key):
                    return True, slot, index
            self._next_index_slot(slot, perturb)

    fn _over_load_factor(self) -> Bool:
        return 3 * self._len > 2 * self._reserved()

    fn _over_compact_factor(self) -> Bool:
        return 4 * self._n_entries > 3 * self._reserved()

    fn _maybe_resize(mut self):
        if not self._over_load_factor():
            if self._over_compact_factor():
                self._compact()
            return
        var _reserved = self._reserved() * 2
        self._len = 0
        self._n_entries = 0
        var old_entries = self._entries^
        self._entries = self._new_entries(_reserved)
        self._index = _DictIndex(self._reserved())

        for i in range(len(old_entries)):
            var entry = old_entries[i]
            if entry:
                self._insert[safe_context=True](entry.unsafe_take())

    fn _compact(mut self):
        self._index = _DictIndex(self._reserved())
        var right = 0
        for left in range(self._len):
            while not self._entries[right]:
                right += 1
                debug_assert(right < self._reserved(), "Invalid dict state")
            var entry = self._entries[right]
            debug_assert(entry.__bool__(), "Logic error")
            var slot = self._find_empty_index(entry.value().hash)
            self._set_index(slot, left)
            if left != right:
                self._entries[left] = entry.unsafe_take()
            right += 1

        self._n_entries = self._len


struct OwnedKwargsDict[V: Copyable & Movable](
    Copyable, Defaultable, ExplicitlyCopyable, Movable, Sized
):
    """Container used to pass owned variadic keyword arguments to functions.

    Parameters:
        V: The value type of the dictionary. Currently must be Copyable & Movable.

    This type mimics the interface of a dictionary with `String` keys, and
    should be usable more-or-less like a dictionary. Notably, however, this type
    should not be instantiated directly by users.
    """

    # Fields
    alias key_type = String

    var _dict: Dict[Self.key_type, V, default_comp_time_hasher]

    # ===-------------------------------------------------------------------===#
    # Life cycle methods
    # ===-------------------------------------------------------------------===#

    fn __init__(out self):
        """Initialize an empty keyword dictionary."""
        self._dict = Dict[Self.key_type, V, default_comp_time_hasher]()

    fn copy(self) -> Self:
        """Copy an existing keyword dictionary.

        Returns:
            A copy of the value.
        """
        return self

    fn __copyinit__(out self, existing: Self):
        """Copy an existing keyword dictionary.

        Args:
            existing: The existing keyword dictionary.
        """
        self._dict = existing._dict

    fn __moveinit__(out self, owned existing: Self):
        """Move data of an existing keyword dictionary into a new one.

        Args:
            existing: The existing keyword dictionary.
        """
        self._dict = existing._dict^

    # ===-------------------------------------------------------------------===#
    # Operator dunders
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn __getitem__(self, key: Self.key_type) raises -> V:
        """Retrieve a value out of the keyword dictionary.

        Args:
            key: The key to retrieve.

        Returns:
            The value associated with the key, if it's present.

        Raises:
            "KeyError" if the key isn't present.
        """
        return self._dict[key]

    @always_inline
    fn __setitem__(mut self, key: Self.key_type, value: V):
        """Set a value in the keyword dictionary by key.

        Args:
            key: The key to associate with the specified value.
            value: The data to store in the dictionary.
        """
        self._dict[key] = value

    # ===-------------------------------------------------------------------===#
    # Trait implementations
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn __contains__(self, key: Self.key_type) -> Bool:
        """Check if a given key is in the keyword dictionary or not.

        Args:
            key: The key to check.

        Returns:
            True if there key exists in the keyword dictionary, False
            otherwise.
        """
        return key in self._dict

    @always_inline
    fn __len__(self) -> Int:
        """The number of elements currently stored in the keyword dictionary.

        Returns:
            The number of elements currently stored in the keyword dictionary.
        """
        return len(self._dict)

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn find(self, key: Self.key_type) -> Optional[V]:
        """Find a value in the keyword dictionary by key.

        Args:
            key: The key to search for in the dictionary.

        Returns:
            An optional value containing a copy of the value if it was present,
            otherwise an empty Optional.
        """
        return self._dict.find(key)

    @always_inline
    fn pop(mut self, key: self.key_type, var default: V) -> V:
        """Remove a value from the dictionary by key.

        Args:
            key: The key to remove from the dictionary.
            default: A default value to return if the key
                was not found instead of raising.

        Returns:
            The value associated with the key, if it was in the dictionary.
            If it wasn't, return the provided default value instead.
        """
        return self._dict.pop(key, default^)

    @always_inline
    fn pop(mut self, key: self.key_type) raises -> V:
        """Remove a value from the dictionary by key.

        Args:
            key: The key to remove from the dictionary.

        Returns:
            The value associated with the key, if it was in the dictionary.
            Raises otherwise.

        Raises:
            "KeyError" if the key was not present in the dictionary.
        """
        return self._dict.pop(key)

    fn __iter__(
        ref self,
    ) -> _DictKeyIter[
        Self.key_type, V, default_comp_time_hasher, __origin_of(self._dict)
    ]:
        """Iterate over the keyword dict's keys as immutable references.

        Returns:
            An iterator of immutable references to the dictionary keys.
        """
        return self._dict.keys()

    fn keys(
        ref self,
    ) -> _DictKeyIter[
        Self.key_type, V, default_comp_time_hasher, __origin_of(self._dict)
    ]:
        """Iterate over the keyword dict's keys as immutable references.

        Returns:
            An iterator of immutable references to the dictionary keys.
        """
        return self._dict.keys()

    fn values(
        ref self,
    ) -> _DictValueIter[
        Self.key_type, V, default_comp_time_hasher, __origin_of(self._dict)
    ]:
        """Iterate over the keyword dict's values as references.

        Returns:
            An iterator of references to the dictionary values.
        """
        return self._dict.values()

    fn items(
        ref self,
    ) -> _DictEntryIter[
        Self.key_type, V, default_comp_time_hasher, __origin_of(self._dict)
    ]:
        """Iterate over the keyword dictionary's entries as immutable
        references.

        Returns:
            An iterator of immutable references to the dictionary entries.

        Examples:

        ```mojo
        var my_dict = Dict[String, Int]()
        my_dict["a"] = 1
        my_dict["b"] = 2

        for e in my_dict.items():
            print(e.key, e.value)
        ```

        Notes:
            These can't yet be unpacked like Python dict items, but you can
            access the key and value as attributes.
        """

        # TODO(#36448): Use this instead of the current workaround
        # return self[]._dict.items()
        return _DictEntryIter(0, 0, self._dict)

    @always_inline
    fn _insert(mut self, var key: Self.key_type, var value: V):
        self._dict._insert(key^, value^)

    @always_inline
    fn _insert(mut self, key: StringLiteral, var value: V):
        self._insert(String(key), value^)
