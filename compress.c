#include "mega.h"

static void _4bpp_to_8bpp(tile4_t tile, tile8_t result) {
  memset(result, 0, sizeof(tile8_t));

  for (int y = 0; y < 8; ++y) {
    for (int x = 0; x < 4; ++x) {
      result[y][x * 2] = tile[y * 4 + x] >> 4;
      result[y][x * 2 + 1] = tile[y * 4 + x] & 0x0F;
    }
  }
}

static void cmp_stream_write_bit(state_t* s, uint8_t bit) {
  s->cmp_long <<= 1;

  if (bit) {
    s->cmp_long++;
  }

  s->cmp_bits_used++;

  if (s->cmp_bits_used == 8) {
    s->dst_data[s->dst_stream_pos++] = s->cmp_long & 0xFF;
    s->dst_data_size++;
    s->cmp_bits_used = 0;
  }
}

static void cmp_stream_write_bits(state_t* s, uint32_t value, uint8_t size) {
  while (size-- > 0) {
    s->cmp_long <<= 1;
    s->cmp_long |= (value >> size) & 1;
    s->cmp_bits_used++;

    if (s->cmp_bits_used == 8) {
      s->dst_data[s->dst_stream_pos++] = s->cmp_long & 0xFF;
      s->dst_data_size++;
      s->cmp_bits_used = 0;
    }
  }
}

static void bstream_init(bstream_t* s) {
  memset(s, 0, sizeof(bstream_t));
}

static void bstream_write_bit(bstream_t* s, int bit) {
  s->data[s->byte] |= (bit ? 1 : 0) << (7 - s->bits);
  s->bits++;
  s->total++;

  if (s->bits == 8) {
    s->bits = 0;
    s->byte++;
  }
}

static void bstream_write_byte(bstream_t* s, uint8_t value) {
  for (int i = 0; i < 8; ++i) {
    bstream_write_bit(s, value & (1 << (7 - i)));
  }
}

static int bstream_get_bit(bstream_t* s, uint32_t index) {
  int byte_index = index / 8;
  int sub_index = index - byte_index * 8;
  return s->data[byte_index] & (1 << (7 - sub_index));
}

static void cmp_stream_write_bstream(state_t* s, bstream_t* vec) {
  for (uint32_t i = 0; i < vec->total; ++i) {
    cmp_stream_write_bit(s, bstream_get_bit(vec, i));
  }
}

static int truncated_binary(int x, int n, bstream_t* result) {
  uint32_t length = 0;

  if (n > 0x100) {
    int low = n & 0xFF;
    int hi = ((n - 1) >> 8) + 1;

    if (x >= low) {
      int xhi = ((x - low) >> 8) + 1;
      int xlow = (x & 0xFF) - low;

      length += truncated_binary(xhi, hi, result);

      if (result) {
        bstream_write_byte(result, xlow);
      }

      length += 8;
    }
    else {
      length += truncated_binary(0, hi, result);
      length += truncated_binary(x, low, result);
    }

    return length;
  }

  int k = 0;
  int t = n;

  while (t > 1) {
    k++;
    t >>= 1;
  }

  int u = (1 << (k + 1)) - n;

  if (x < u) {
    for (int i = 0; i < k; ++i) {
      if (result) {
        bstream_write_bit(result, x & (1 << (k - i - 1)));
      }
    }
    length += k;
  }
  else {
    for (int i = 0; i < k + 1; ++i) {
      if (result) {
        bstream_write_bit(result, (x + u) & (1 << (k - i)));
      }
    }
    length += k + 1;
  }

  return length;
}

static uint8_t count_bits_set(uint16_t value) {
  uint8_t res = 0;

  while (value > 0) {
    res += (value & 1);
    value >>= 1;
  }

  return res;
}

static void set_to_array(uint16_t col_set, uint8_t* result) {
  int j = 0;

  memset(result, 0, 16);

  for (int i = 0; i < 16; ++i) {
    if (col_set & (1 << i)) {
      result[j++] = i;
    }
  }
}

static int get_element_index(uint16_t pixels, uint8_t element) {
  if (pixels & (1 << element)) {
    uint8_t p[16];
    set_to_array(pixels, p);

    for (int i = 0; i < 16; ++i) {
      if (p[i] == element) {
        return i;
      }
    }
  }

  return -1;
}

static uint16_t compress_similar_tile(state_t* s, int i, int j, int length_only) {
  int index = j;
  uint8_t vmap = 0xFF;
  uint8_t hmap = 0x00;

  uint16_t pixels = 0;

  for (int y = 0; y < 8; ++y) {
    hmap <<= 1;

    if (memcmp(s->tiles[i][y], s->tiles[index][y], 8) == 0) {
      hmap++;
    }
    else {
      for (int x = 0; x < 8; ++x) {
        s->similar_tiles[i].vbits[y] <<= 1;

        if (s->tiles[i][y][x] == s->tiles[index][y][x]) {
          s->similar_tiles[i].vbits[y]++;
        }
        else {
          pixels |= (1 << s->tiles[i][y][x]);
        }
      }

      vmap &= s->similar_tiles[i].vbits[y];
    }
  }

  s->similar_tiles[i].pixels = pixels;

  uint32_t sz = truncated_binary(i - index - 1, i, length_only ? NULL : &s->similar_tiles[i].packed);

  if (length_only) {
    s->similar_tiles[i].size = sz;
  }

  s->similar_tiles[i].vhi = vmap >> 4;
  s->similar_tiles[i].vlo = vmap & 0x0F;

  if (length_only) {
    s->similar_tiles[i].size += 2;
  }

  if (s->similar_tiles[i].vhi) {
    if (!length_only) {
      bstream_write_bit(&s->similar_tiles[i].packed, 1);
    }

    sz = truncated_binary(s->similar_tiles[i].vhi ^ 0x0F, 0x0F, length_only ? NULL : &s->similar_tiles[i].packed);

    if (length_only) {
      s->similar_tiles[i].size += sz;
    }
  }
  else if (!length_only) {
    bstream_write_bit(&s->similar_tiles[i].packed, 0);
  }

  if (s->similar_tiles[i].vlo) {
    if (!length_only) {
      bstream_write_bit(&s->similar_tiles[i].packed, 1);
    }

    sz = truncated_binary(s->similar_tiles[i].vlo ^ 0x0F, 0x0F, length_only ? NULL : &s->similar_tiles[i].packed);

    if (length_only) {
      s->similar_tiles[i].size += sz;
    }
  }
  else if (!length_only) {
    bstream_write_bit(&s->similar_tiles[i].packed, 0);
  }

  s->similar_tiles[i].hhi = hmap >> 4;
  s->similar_tiles[i].hlo = hmap & 0x0F;

  if (length_only) {
    s->similar_tiles[i].size += 2;
  }

  if (s->similar_tiles[i].hhi) {
    if (!length_only) {
      bstream_write_bit(&s->similar_tiles[i].packed, 1);
    }

    sz = truncated_binary(s->similar_tiles[i].hhi ^ 0x0F, 0x0F, length_only ? NULL : &s->similar_tiles[i].packed);

    if (length_only) {
      s->similar_tiles[i].size += sz;
    }
  }
  else if (!length_only) {
    bstream_write_bit(&s->similar_tiles[i].packed, 0);
  }

  if (s->similar_tiles[i].hlo) {
    if (!length_only) {
      bstream_write_bit(&s->similar_tiles[i].packed, 1);
    }

    sz = truncated_binary(s->similar_tiles[i].hlo ^ 0x0F, 0x0F, length_only ? NULL : &s->similar_tiles[i].packed);

    if (length_only) {
      s->similar_tiles[i].size += sz;
    }
  }
  else if (!length_only) {
    bstream_write_bit(&s->similar_tiles[i].packed, 0);
  }

  for (int y = 7; y >= 0; --y) {
    uint8_t vmaptmp = vmap;

    if ((hmap & (1 << y)) == 0) {
      if ((hmap | (1 << y)) != 0xFF) {
        for (int x = 7; x >= 0; --x) {
          if (
            (vmap != 0xFE) &&
            (vmap != 0xFD) &&
            (vmap != 0xFB) &&
            (vmap != 0xF7) &&
            (vmap != 0xEF) &&
            (vmap != 0xDF) &&
            (vmap != 0xBF) &&
            (vmap != 0x7F) &&
            ((vmap & (1 << x))) == 0) {
            if (length_only) {
              s->similar_tiles[i].size++;
            }
            else {
              bstream_write_bit(&s->similar_tiles[i].packed, (s->similar_tiles[i].vbits[7 - y] >> x) & 1);
            }

            vmaptmp |= (s->similar_tiles[i].vbits[7 - y] & (1 << x));

            if (
              (vmaptmp == 0xFE) ||
              (vmaptmp == 0xFD) ||
              (vmaptmp == 0xFB) ||
              (vmaptmp == 0xF7) ||
              (vmaptmp == 0xEF) ||
              (vmaptmp == 0xDF) ||
              (vmaptmp == 0xBF) ||
              (vmaptmp == 0x7F)
              ) {
              break;
            }
          }
        }
      }

      for (int x = 7; x >= 0; --x) {
        if ((s->similar_tiles[i].vbits[7 - y] & (1 << x)) == 0) {
          pixels = s->similar_tiles[i].pixels;
          pixels &= ~(1 << s->tiles[index][7 - y][7 - x]);
          int element_index = get_element_index(pixels, s->tiles[i][7 - y][7 - x]);

          sz = truncated_binary(element_index, count_bits_set(pixels), length_only ? NULL : &s->similar_tiles[i].packed);

          if (length_only) {
            s->similar_tiles[i].size += sz;
          }
        }
      }
    }
  }

  if (length_only) {
    return s->similar_tiles[i].size;
  }

  s->similar_tiles[i].size = (uint16_t)s->similar_tiles[i].packed.total;
  return s->similar_tiles[i].size;
}

static int find_similar_tile(state_t* s, int index) {
  uint16_t min_diff = 0xFFFF;
  int result = 0;
  int j = index;

  for (int i = index - 1; i >= 0; --i) {
    uint16_t diff = compress_similar_tile(s, j, i, 1);

    if (diff < min_diff) {
      min_diff = diff;
      result = i;
    }
  }

  return result;
}

static void compress_similar_tiles(state_t* s) {
  s->similar_tiles[0].size = 0xFFFF;

  for (uint32_t i = 1; i < s->tiles_num; ++i) {
    uint16_t pixels = 0;

    int index = find_similar_tile(s, (int)i);
    compress_similar_tile(s, i, index, 0);
  }
}

static void compress_line_repeats_tiles(state_t* s) {
  s->src_stream_pos = 0;

  for (uint32_t i = 0; i < s->tiles_num; ++i) {
    uint8_t vmap = 0x7F;
    uint8_t hmap = 0x00;

    for (int x = 1; x < 8; ++x) {
      s->line_repeats_tiles[i].vbits[0] <<= 1;

      if (s->tiles[i][0][x - 1] == s->tiles[i][0][x]) {
        s->line_repeats_tiles[i].vbits[0]++;
      }
    }

    vmap &= s->line_repeats_tiles[i].vbits[0];

    for (int y = 1; y < 8; ++y) {
      hmap <<= 1;

      if (memcmp(s->tiles[i][y - 1], s->tiles[i][y], 8) == 0) {
        hmap++;
      }
      else {
        for (int x = 1; x < 8; ++x) {
          s->line_repeats_tiles[i].vbits[y] <<= 1;

          if (s->tiles[i][y][x - 1] == s->tiles[i][y][x]) {
            s->line_repeats_tiles[i].vbits[y]++;
          }
        }

        vmap &= s->line_repeats_tiles[i].vbits[y];
      }
    }

    s->line_repeats_tiles[i].hhi = hmap >> 3;
    s->line_repeats_tiles[i].hlo = hmap & 7;

    if (s->line_repeats_tiles[i].hhi) {
      bstream_write_bit(&s->line_repeats_tiles[i].packed, 1);
      truncated_binary(s->line_repeats_tiles[i].hhi ^ 0x0F, 0x0F, &s->line_repeats_tiles[i].packed);
    }
    else {
      bstream_write_bit(&s->line_repeats_tiles[i].packed, 0);
    }

    if (hmap & 8) {
      if (s->line_repeats_tiles[i].hlo == 7) {
        bstream_write_bit(&s->line_repeats_tiles[i].packed, 0);
      }
      else {
        bstream_write_bit(&s->line_repeats_tiles[i].packed, 1);
        truncated_binary(s->line_repeats_tiles[i].hlo, 7, &s->line_repeats_tiles[i].packed);
      }
    }
    else {
      if (s->line_repeats_tiles[i].hlo) {
        bstream_write_bit(&s->line_repeats_tiles[i].packed, 1);
        truncated_binary(s->line_repeats_tiles[i].hlo ^ 7, 7, &s->line_repeats_tiles[i].packed);
      }
      else {
        bstream_write_bit(&s->line_repeats_tiles[i].packed, 0);
      }
    }

    s->line_repeats_tiles[i].vhi = vmap >> 3;
    s->line_repeats_tiles[i].vlo = vmap & 7;

    if (s->line_repeats_tiles[i].vhi) {
      bstream_write_bit(&s->line_repeats_tiles[i].packed, 1);
      truncated_binary(s->line_repeats_tiles[i].vhi ^ 0x0F, 0x0F, &s->line_repeats_tiles[i].packed);
    }
    else {
      bstream_write_bit(&s->line_repeats_tiles[i].packed, 0);
    }

    if (vmap & 8) {
      if (s->line_repeats_tiles[i].vlo == 7) {
        bstream_write_bit(&s->line_repeats_tiles[i].packed, 0);
      }
      else {
        bstream_write_bit(&s->line_repeats_tiles[i].packed, 1);
        truncated_binary(s->line_repeats_tiles[i].vlo, 7, &s->line_repeats_tiles[i].packed);
      }
    }
    else {
      if (s->line_repeats_tiles[i].vlo) {
        bstream_write_bit(&s->line_repeats_tiles[i].packed, 1);
        truncated_binary(s->line_repeats_tiles[i].vlo ^ 7, 7, &s->line_repeats_tiles[i].packed);
      }
      else {
        bstream_write_bit(&s->line_repeats_tiles[i].packed, 0);
      }
    }

    uint16_t pixels = s->line_repeats_tiles[i].pixels;
    int element_index = get_element_index(pixels, s->tiles[i][0][0]);
    truncated_binary(element_index, count_bits_set(pixels), &s->line_repeats_tiles[i].packed);

    for (int x = 6; x >= 0; --x) {
      if ((vmap & (1 << x)) == 0) {
        if ((s->line_repeats_tiles[i].vbits[0] & (1 << x)) == 0) {
          pixels = s->line_repeats_tiles[i].pixels;
          pixels &= ~(1 << s->tiles[i][0][7 - x - 1]);

          bstream_write_bit(&s->line_repeats_tiles[i].packed, 1);
          element_index = get_element_index(pixels, s->tiles[i][0][7 - x]);
          truncated_binary(element_index, count_bits_set(pixels), &s->line_repeats_tiles[i].packed);
        }
        else {
          bstream_write_bit(&s->line_repeats_tiles[i].packed, 0);
        }
      }
    }

    int vpref = 1;

    for (int y = 6; y >= 0; --y) {
      if ((hmap & (1 << y)) == 0) {
        if (s->tiles[i][7 - y][0] != s->tiles[i][7 - y - 1][0]) {
          pixels = s->line_repeats_tiles[i].pixels;
          pixels &= ~(1 << s->tiles[i][7 - y - 1][0]);

          bstream_write_bit(&s->line_repeats_tiles[i].packed, 1);
          element_index = get_element_index(pixels, s->tiles[i][7 - y][0]);
          truncated_binary(element_index, count_bits_set(pixels), &s->line_repeats_tiles[i].packed);
        }
        else {
          bstream_write_bit(&s->line_repeats_tiles[i].packed, 0);
        }

        for (int x = 6; x >= 0; --x) {
          if ((vmap & (1 << x)) == 0) {
            if (vpref) {
              if (s->tiles[i][7 - y][7 - x] != s->tiles[i][7 - y][7 - x - 1]) {
                bstream_write_bit(&s->line_repeats_tiles[i].packed, 1);

                if (s->tiles[i][7 - y][7 - x - 1] == s->tiles[i][7 - y - 1][7 - x]) {
                  pixels = s->line_repeats_tiles[i].pixels;
                  pixels &= ~(1 << s->tiles[i][7 - y][7 - x - 1]);

                  element_index = get_element_index(pixels, s->tiles[i][7 - y][7 - x]);
                  truncated_binary(element_index, count_bits_set(pixels), &s->line_repeats_tiles[i].packed);
                }
                else {
                  if (s->tiles[i][7 - y][7 - x] == s->tiles[i][7 - y - 1][7 - x]) {
                    bstream_write_bit(&s->line_repeats_tiles[i].packed, 0);
                    vpref = 0;
                  }
                  else {
                    bstream_write_bit(&s->line_repeats_tiles[i].packed, 1);
                    pixels = s->line_repeats_tiles[i].pixels;
                    pixels &= ~(1 << s->tiles[i][7 - y][7 - x - 1]);
                    pixels &= ~(1 << s->tiles[i][7 - y - 1][7 - x]);

                    element_index = get_element_index(pixels, s->tiles[i][7 - y][7 - x]);
                    truncated_binary(element_index, count_bits_set(pixels), &s->line_repeats_tiles[i].packed);
                  }
                }
              }
              else {
                bstream_write_bit(&s->line_repeats_tiles[i].packed, 0);
              }
            }
            else {
              if (s->tiles[i][7 - y][7 - x] != s->tiles[i][7 - y - 1][7 - x]) {
                bstream_write_bit(&s->line_repeats_tiles[i].packed, 1);

                if (s->tiles[i][7 - y][7 - x - 1] == s->tiles[i][7 - y - 1][7 - x]) {
                  pixels = s->line_repeats_tiles[i].pixels;
                  pixels &= ~(1 << s->tiles[i][7 - y][7 - x - 1]);

                  element_index = get_element_index(pixels, s->tiles[i][7 - y][7 - x]);
                  truncated_binary(element_index, count_bits_set(pixels), &s->line_repeats_tiles[i].packed);
                }
                else {
                  if (s->tiles[i][7 - y][7 - x] == s->tiles[i][7 - y][7 - x - 1]) {
                    bstream_write_bit(&s->line_repeats_tiles[i].packed, 0);
                    vpref = 1;
                  }
                  else {
                    bstream_write_bit(&s->line_repeats_tiles[i].packed, 1);
                    pixels = s->line_repeats_tiles[i].pixels;
                    pixels &= ~(1 << s->tiles[i][7 - y][7 - x - 1]);
                    pixels &= ~(1 << s->tiles[i][7 - y - 1][7 - x]);

                    element_index = get_element_index(pixels, s->tiles[i][7 - y][7 - x]);
                    truncated_binary(element_index, count_bits_set(pixels), &s->line_repeats_tiles[i].packed);
                  }
                }
              }
              else {
                bstream_write_bit(&s->line_repeats_tiles[i].packed, 0);
              }
            }
          }
        }
      }
    }

    s->line_repeats_tiles[i].size = (uint16_t)s->line_repeats_tiles[i].packed.total;
  }
}

static int vector_indexof(const uint16_t* vec, uint16_t element) {
  for (uint32_t i = 0; i < cvector_size(vec); ++i) {
    if (vec[i] == element) {
      return (int)i;
    }
  }

  return -1;
}

static uint8_t bit_on_index(uint16_t value) {
  for (int i = 0; i < 16; ++i) {
    if (value == (1 << i)) {
      return i;
    }
  }

  return -1;
}

static void cmp_stream_write_bits_flush(state_t* s) {
  if (s->cmp_bits_used > 0) {
    s->dst_data[s->dst_stream_pos++] = (s->cmp_long << (8 - s->cmp_bits_used)) & 0xFF;
    s->dst_data_size++;
    s->cmp_bits_used = 0;
  }

  s->cmp_long = 0;
}

uint32_t compress(const uint8_t* src, uint32_t size, uint8_t* dest) {
  state_t* s = (state_t*)malloc(sizeof(state_t));

  if (s == NULL) {
    return 0;
  }

  memset(s, 0, sizeof(state_t));

  s->src_data = src;
  s->src_stream_pos = 0;

  s->dst_data = dest;
  s->dst_stream_pos = 0;

  s->tiles_num = (uint32_t)(size / sizeof(tile4_t));

  for (uint32_t i = 0; i < s->tiles_num; ++i) {
    tile4_t tile;
    memcpy(tile, &s->src_data[s->src_stream_pos], sizeof(tile4_t));

    _4bpp_to_8bpp(tile, s->tiles[i]);
    s->src_stream_pos += sizeof(tile4_t);
  }

  cmp_stream_write_bits(s, s->tiles_num, 8);
  cmp_stream_write_bits(s, s->tiles_num >> 8, 2);

  for (uint32_t i = 0; i < s->tiles_num; ++i) {
    uint16_t pixels = 0;

    for (int y = 0; y < 8; ++y) {
      for (int x = 0; x < 8; ++x) {
        if ((pixels & (1 << s->tiles[i][y][x])) == 0) {
          pixels |= (1 << s->tiles[i][y][x]);
        }
      }
    }

    s->similar_tiles[i].pixels = pixels;
    s->line_repeats_tiles[i].pixels = pixels;
  }

  cvector_vector_type(uint16_t) list_of_set = NULL;

  compress_similar_tiles(s);
  compress_line_repeats_tiles(s);

  for (uint32_t i = 0; i < s->tiles_num; ++i) {
    if (s->similar_tiles[i].size < s->line_repeats_tiles[i].size) {
      if (vector_indexof(list_of_set, s->similar_tiles[i].pixels) == -1) {
        cvector_push_back(list_of_set, s->similar_tiles[i].pixels);
      }
    }
    else {
      if (vector_indexof(list_of_set, s->line_repeats_tiles[i].pixels) == -1) {
        cvector_push_back(list_of_set, s->line_repeats_tiles[i].pixels);
      }
    }
  }

  bstream_t tmp;
  bstream_init(&tmp);
  if (s->tiles_num > MAX_SET_NUMS) {
    truncated_binary((uint32_t)(cvector_size(list_of_set) - 1), MAX_SET_NUMS, &tmp);
  }
  else {
    truncated_binary((uint32_t)(cvector_size(list_of_set) - 1), s->tiles_num, &tmp);
  }
  cmp_stream_write_bstream(s, &tmp);

  cmp_stream_write_bits(s, list_of_set[0], 16);

  for (uint32_t j = 1; j < cvector_size(list_of_set); ++j) {
    uint32_t k = 0;

    for (k = 0; k < j; ++k) {
      if ((count_bits_set(list_of_set[k] ^ list_of_set[j])) == 1) {
        int index = j - k - 1;
        cmp_stream_write_bit(s, 0);

        bstream_init(&tmp);
        truncated_binary(index, j, &tmp);
        cmp_stream_write_bstream(s, &tmp);

        index = bit_on_index(list_of_set[k] ^ list_of_set[j]);
        cmp_stream_write_bits(s, index, 4);
        break;
      }
    }

    if (k == j) {
      cmp_stream_write_bit(s, 1);
      cmp_stream_write_bits(s, list_of_set[j], 16);
    }
  }

  cvector_free(list_of_set);
  list_of_set = NULL;

  cmp_stream_write_bits(s, 1, 1);
  cmp_stream_write_bstream(s, &s->line_repeats_tiles[0].packed);
  cvector_push_back(list_of_set, s->line_repeats_tiles[0].pixels);

  for (uint32_t i = 1; i < s->tiles_num; ++i) {
    bstream_init(&tmp);

    if (s->similar_tiles[i].size < s->line_repeats_tiles[i].size) {
      if (vector_indexof(list_of_set, s->similar_tiles[i].pixels) == -1) {
        cvector_push_back(list_of_set, s->similar_tiles[i].pixels);
        truncated_binary(0, (uint32_t)cvector_size(list_of_set), &tmp);
      }
      else {
        uint32_t index = (uint32_t)(cvector_size(list_of_set) - vector_indexof(list_of_set, s->similar_tiles[i].pixels));
        truncated_binary(index, (uint32_t)(cvector_size(list_of_set) + 1), &tmp);
      }

      cmp_stream_write_bstream(s, &tmp);

      cmp_stream_write_bit(s, 0);
      cmp_stream_write_bstream(s, &s->similar_tiles[i].packed);
    }
    else {
      if (vector_indexof(list_of_set, s->line_repeats_tiles[i].pixels) == -1) {
        cvector_push_back(list_of_set, s->line_repeats_tiles[i].pixels);
        truncated_binary(0, (uint32_t)cvector_size(list_of_set), &tmp);
      }
      else {
        uint32_t index = (uint32_t)(cvector_size(list_of_set) - vector_indexof(list_of_set, s->line_repeats_tiles[i].pixels));
        truncated_binary(index, (uint32_t)(cvector_size(list_of_set) + 1), &tmp);
      }

      cmp_stream_write_bstream(s, &tmp);
      cmp_stream_write_bit(s, 1);
      cmp_stream_write_bstream(s, &s->line_repeats_tiles[i].packed);
    }
  }

  cvector_free(list_of_set);

  cmp_stream_write_bits_flush(s);

  uint32_t result = s->dst_stream_pos;
  free(s);

  return result;
}
