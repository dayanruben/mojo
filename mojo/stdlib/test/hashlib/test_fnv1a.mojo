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

from hashlib._fnv1a import Fnv1a
from testing import assert_equal
from memory import memset_zero
from test_utils import (
    gen_word_pairs,
    assert_dif_hashes,
    assert_fill_factor,
    words_ar,
    words_el,
    words_en,
    words_he,
    words_lv,
    words_pl,
    words_ru,
)


def test_hash_byte_array():
    assert_equal(
        hash[HasherType=Fnv1a]("a"),
        hash[HasherType=Fnv1a]("a"),
    )
    assert_equal(
        hash[HasherType=Fnv1a]("b"),
        hash[HasherType=Fnv1a]("b"),
    )

    assert_equal(
        hash[HasherType=Fnv1a]("c"),
        hash[HasherType=Fnv1a]("c"),
    )

    assert_equal(
        hash[HasherType=Fnv1a]("d"),
        hash[HasherType=Fnv1a]("d"),
    )
    assert_equal(
        hash[HasherType=Fnv1a]("d"),
        hash[HasherType=Fnv1a]("d"),
    )


def test_avalanche():
    # test that values which differ just in one bit,
    # produce significatly different hash values
    var buffer = InlineArray[UInt8, 256](fill=0)
    var hashes = List[UInt64]()
    hashes.append(hash[HasherType=Fnv1a](buffer.unsafe_ptr(), 256))

    for i in range(256):
        memset_zero(buffer.unsafe_ptr(), 256)
        var v = 1 << (i & 7)
        buffer[i >> 3] = v
        hashes.append(hash[HasherType=Fnv1a](buffer.unsafe_ptr(), 256))

    assert_dif_hashes(hashes, 15)


def test_trailing_zeros():
    # checks that a value with different amount of trailing zeros,
    # results in significantly different hash values
    var buffer = InlineArray[UInt8, 8](fill=0)
    buffer[0] = 23
    var hashes = List[UInt64]()
    for i in range(1, 9):
        hashes.append(hash[HasherType=Fnv1a](buffer.unsafe_ptr(), i))

    assert_dif_hashes(hashes, 21)


def test_fill_factor():
    words = gen_word_pairs[words_ar]()
    assert_fill_factor["AR", Fnv1a](words, len(words), 0.63)
    assert_fill_factor["AR", Fnv1a](words, len(words) // 2, 0.86)
    assert_fill_factor["AR", Fnv1a](words, len(words) // 4, 0.98)
    assert_fill_factor["AR", Fnv1a](words, len(words) // 14, 1.0)

    words = gen_word_pairs[words_el]()
    assert_fill_factor["EL", Fnv1a](words, len(words), 0.63)
    assert_fill_factor["EL", Fnv1a](words, len(words) // 2, 0.86)
    assert_fill_factor["EL", Fnv1a](words, len(words) // 4, 0.98)
    assert_fill_factor["EL", Fnv1a](words, len(words) // 13, 1.0)

    words = gen_word_pairs[words_en]()
    assert_fill_factor["EN", Fnv1a](words, len(words), 0.63)
    assert_fill_factor["EN", Fnv1a](words, len(words) // 2, 0.86)
    assert_fill_factor["EN", Fnv1a](words, len(words) // 4, 0.98)
    assert_fill_factor["EN", Fnv1a](words, len(words) // 14, 1.0)

    words = gen_word_pairs[words_he]()
    assert_fill_factor["HE", Fnv1a](words, len(words), 0.63)
    assert_fill_factor["HE", Fnv1a](words, len(words) // 2, 0.86)
    assert_fill_factor["HE", Fnv1a](words, len(words) // 4, 0.98)
    assert_fill_factor["HE", Fnv1a](words, len(words) // 14, 1.0)

    words = gen_word_pairs[words_lv]()
    assert_fill_factor["LV", Fnv1a](words, len(words), 0.63)
    assert_fill_factor["LV", Fnv1a](words, len(words) // 2, 0.86)
    assert_fill_factor["LV", Fnv1a](words, len(words) // 4, 0.98)
    assert_fill_factor["LV", Fnv1a](words, len(words) // 14, 1.0)

    words = gen_word_pairs[words_pl]()
    assert_fill_factor["PL", Fnv1a](words, len(words), 0.63)
    assert_fill_factor["PL", Fnv1a](words, len(words) // 2, 0.86)
    assert_fill_factor["PL", Fnv1a](words, len(words) // 4, 0.98)
    assert_fill_factor["PL", Fnv1a](words, len(words) // 14, 1.0)

    words = gen_word_pairs[words_ru]()
    assert_fill_factor["RU", Fnv1a](words, len(words), 0.63)
    assert_fill_factor["RU", Fnv1a](words, len(words) // 2, 0.86)
    assert_fill_factor["RU", Fnv1a](words, len(words) // 4, 0.98)
    assert_fill_factor["RU", Fnv1a](words, len(words) // 14, 1.0)


def test_hash_simd_values():
    fn hash(value: SIMD) -> UInt64:
        hasher = Fnv1a()
        hasher._update_with_simd(value)
        return hasher^.finish()

    assert_equal(hash(SIMD[DType.float16, 1](1.5)), 12636464265834235359)
    assert_equal(hash(SIMD[DType.float32, 1](1.5)), 8026467504136239071)
    assert_equal(hash(SIMD[DType.float64, 1](1.5)), 15000291120250992607)
    assert_equal(hash(SIMD[DType.float16, 1](1)), 12637027215787879391)
    assert_equal(hash(SIMD[DType.float32, 1](1)), 3414781483884328927)
    assert_equal(hash(SIMD[DType.float64, 1](1)), 14020758201297909727)

    assert_equal(hash(SIMD[DType.bool, 1](True)), 12638152016183539244)
    assert_equal(hash(SIMD[DType.int8, 1](1)), 12638152016183539244)
    assert_equal(hash(SIMD[DType.int16, 1](1)), 12638152016183539244)
    assert_equal(hash(SIMD[DType.int32, 1](1)), 12638152016183539244)
    assert_equal(hash(SIMD[DType.int64, 1](1)), 12638152016183539244)
    assert_equal(hash(SIMD[DType.int128, 1](1)), 589727492704079044)
    assert_equal(hash(SIMD[DType.int64, 2](1, 0)), 589727492704079044)
    assert_equal(hash(SIMD[DType.int256, 1](1)), 12478008331234465636)
    assert_equal(hash(SIMD[DType.int64, 4](1, 0, 0, 0)), 12478008331234465636)

    assert_equal(hash(SIMD[DType.int8, 1](-1)), 12638352127299873646)
    assert_equal(hash(SIMD[DType.int16, 1](-1)), 12690424998011946606)
    assert_equal(hash(SIMD[DType.int32, 1](-1)), 7718450949043144302)
    assert_equal(hash(SIMD[DType.int64, 1](-1)), 5808589858502755950)
    assert_equal(hash(SIMD[DType.int128, 1](-1)), 591639543425159523)
    assert_equal(hash(SIMD[DType.int64, 2](-1)), 591639543425159523)
    assert_equal(hash(SIMD[DType.int256, 1](-1)), 16463485165778154321)
    assert_equal(hash(SIMD[DType.int64, 4](-1)), 16463485165778154321)

    assert_equal(hash(SIMD[DType.int8, 1](0)), 12638153115695167455)
    assert_equal(hash(SIMD[DType.int8, 2](0)), 590684067820433389)
    assert_equal(hash(SIMD[DType.int8, 4](0)), 5558979605539197941)
    assert_equal(hash(SIMD[DType.int8, 8](0)), 12161962213042174405)
    assert_equal(hash(SIMD[DType.int8, 16](0)), 9808874869469701221)
    assert_equal(hash(SIMD[DType.int8, 32](0)), 901300984310592933)
    assert_equal(hash(SIMD[DType.int8, 64](0)), 13380826962402805797)

    assert_equal(hash(SIMD[DType.int32, 1](0)), 12638153115695167455)
    assert_equal(hash(SIMD[DType.int32, 2](0)), 590684067820433389)
    assert_equal(hash(SIMD[DType.int32, 4](0)), 5558979605539197941)
    assert_equal(hash(SIMD[DType.int32, 8](0)), 12161962213042174405)
    assert_equal(hash(SIMD[DType.int32, 16](0)), 9808874869469701221)
    assert_equal(hash(SIMD[DType.int32, 32](0)), 901300984310592933)
    assert_equal(hash(SIMD[DType.int32, 64](0)), 13380826962402805797)


def test_hash_at_compile_time():
    alias h = hash[HasherType=Fnv1a]("hello")
    assert_equal(h, 11831194018420276491)


def main():
    test_hash_byte_array()
    test_avalanche()
    test_trailing_zeros()
    test_fill_factor()
    test_hash_simd_values()
    test_hash_at_compile_time()
