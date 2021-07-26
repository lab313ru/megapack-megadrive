#include "mega.h"

static uint16_t cmp_stream_read_bits(state_t* state, uint8_t num_bits) {
  state->cmp_long &= 0xFFFF;

  while (num_bits-- > 0) {
    if (state->cmp_bits_used == 0) {
      uint8_t tmp = state->src_data[state->src_stream_pos++];
      state->cmp_long |= tmp << 8;
      tmp = state->src_data[state->src_stream_pos++];
      state->cmp_long |= tmp;
      state->cmp_bits_used = 16;
    }

    state->cmp_long <<= 1;
    state->cmp_bits_used--;
  }

  return state->cmp_long >> 16;
}

static uint32_t truncated_to_full(state_t* s, uint32_t range) {
  if (range > 0x100) {
    uint32_t low = range & 0xFF;
    uint32_t hi = ((range - 1) >> 8) + 1;
    uint32_t xhi = truncated_to_full(s, hi) - 1;

    if (xhi >= 0) {
      return cmp_stream_read_bits(s, 8) + xhi * 256 + low;
    }

    return truncated_to_full(s, low);
  }

  uint32_t tmp = range;
  uint32_t bit_count = 0;

  while (tmp > 1) {
    bit_count++;
    tmp >>= 1;
  }

  uint32_t unused = (1 << (bit_count + 1)) - range;
  uint32_t x = cmp_stream_read_bits(s, bit_count);

  if (x < unused) {
    return x;
  }

  return ((x << 1) | cmp_stream_read_bits(s, 1)) - unused;
}

static uint32_t get_stream(state_t* s, uint32_t range) {
  return truncated_to_full(s, range);
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

static uint8_t pixstream(state_t* s, uint16_t col_set) {
  uint8_t col_nums = count_bits_set(col_set);
  uint16_t index = get_stream(s, col_nums);

  uint8_t result[16];
  set_to_array(col_set, result);

  return result[index];
}

static uint8_t mpixstream(state_t* s, uint8_t pixel, uint16_t pixels) {
  pixels &= ~(1 << pixel);
  return pixstream(s, pixels);
}

static void _8bpp_to_4bpp(tile8_t tile, tile4_t result) {
  memset(result, 0, sizeof(tile4_t));

  for (int y = 0; y < 8; ++y) {
    for (int x = 0; x < 4; ++x) {
      result[y * 4 + x] = (tile[y][x * 2] << 4) | (tile[y][x * 2 + 1] & 0x0F);
    }
  }
}

uint32_t decompress(const uint8_t* src, uint8_t* dst, uint32_t* cmp_size) {
  state_t* s = malloc(sizeof(state_t));

  if (s == NULL) {
    return 0;
  }

  memset(s, 0, sizeof(state_t));

  s->src_data = src;
  s->src_stream_pos = 0;
  s->tiles_num = cmp_stream_read_bits(s, 8) + (cmp_stream_read_bits(s, 2) << 8);
  s->dst_data_size = s->tiles_num * TILE_4BIT_SIZE;

  uint16_t set_nums;
  if (s->tiles_num > MAX_SET_NUMS) {
    set_nums = get_stream(s, MAX_SET_NUMS);
  }
  else {
    set_nums = get_stream(s, s->tiles_num);
  }

  cvector_vector_type(uint16_t) list_of_set = NULL;

  cvector_push_back(list_of_set, cmp_stream_read_bits(s, 16));

  while (set_nums-- > 0) {
    if (cmp_stream_read_bits(s, 1) == 1) {
      cvector_push_back(list_of_set, cmp_stream_read_bits(s, 16));
    }
    else {
      uint32_t delta = get_stream(s, (uint32_t)cvector_size(list_of_set));
      uint32_t index = (uint32_t)(cvector_size(list_of_set) - delta - 1);
      uint16_t col_set = list_of_set[index];
      col_set ^= (1 << cmp_stream_read_bits(s, 4));
      cvector_push_back(list_of_set, col_set);
    }
  }

  uint32_t used_sets_count = 0;

  for (uint32_t i = 0; i < s->tiles_num; ++i) {
    uint32_t index = get_stream(s, used_sets_count + 1);

    if (index == 0) {
      index = used_sets_count++;
    }
    else {
      index = used_sets_count - index;
    }

    uint16_t pixels = list_of_set[index];

    if (cmp_stream_read_bits(s, 1) == 0) {
      uint32_t offset = 0xFFFFFFFF ^ get_stream(s, i);
      offset += i;

      // vmap
      uint8_t vmap = 0;

      if (cmp_stream_read_bits(s, 1) == 1) {
        vmap = get_stream(s, 0x0F);
        vmap ^= 0x0F;
        vmap <<= 4;
      }

      if (cmp_stream_read_bits(s, 1) == 1) {
        vmap |= 0x0F;
        vmap ^= get_stream(s, 0x0F);
      }

      // hmap
      uint8_t hmap = 0;

      if (cmp_stream_read_bits(s, 1) == 1) {
        hmap = get_stream(s, 0x0F);
        hmap ^= 0x0F;
        hmap <<= 4;
      }

      if (cmp_stream_read_bits(s, 1) == 1) {
        hmap |= 0x0F;
        hmap ^= get_stream(s, 0x0F);
      }

      for (int y = 7; y >= 0; --y) {
        if ((hmap & (1 << y))) {
          memcpy(s->tiles[i][7 - y], s->tiles[offset][7 - y], 8);
        }
        else {
          uint8_t vmaptmp = vmap;

          if ((hmap | (1 << y)) != 0xFF) {
            for (int x = 7; x >= 0; --x) {
              if (
                (vmaptmp == 0xFE) ||
                (vmaptmp == 0xFD) ||
                (vmaptmp == 0xFB) ||
                (vmaptmp == 0xF7) ||
                (vmaptmp == 0xEF) ||
                (vmaptmp == 0xDF) ||
                (vmaptmp == 0xBF) ||
                (vmaptmp == 0x7F)) {
                break;
              }

              if ((vmap & (1 << x)) == 0) {
                vmaptmp |= (cmp_stream_read_bits(s, 1) << x);
              }
            }
          }

          for (int x = 7; x >= 0; --x) {
            if ((vmaptmp & (1 << x)) == 0) {
              s->tiles[i][7 - y][7 - x] = mpixstream(s, s->tiles[offset][7 - y][7 - x], pixels);
            }
            else {
              s->tiles[i][7 - y][7 - x] = s->tiles[offset][7 - y][7 - x];
            }
          }
        }
      }
    }
    else {
      uint8_t hmap = 0;

      if (cmp_stream_read_bits(s, 1) == 1) {
        hmap = get_stream(s, 0x0F);
        hmap ^= 0x0F;
        hmap <<= 3;
      }

      if (cmp_stream_read_bits(s, 1) == 1) {
        hmap |= 7;
        hmap ^= get_stream(s, 7);
      }

      if (hmap & 8) {
        hmap ^= 7;
      }

      uint8_t vmap = 0;

      if (cmp_stream_read_bits(s, 1) == 1) {
        vmap = get_stream(s, 0x0F);
        vmap ^= 0x0F;
        vmap <<= 3;
      }

      if (cmp_stream_read_bits(s, 1) == 1) {
        vmap |= 7;
        vmap ^= get_stream(s, 7);
      }

      if (vmap & 8) {
        vmap ^= 7;
      }

      s->tiles[i][0][0] = pixstream(s, pixels);

      for (int x = 6; x >= 0; --x) {
        if (vmap & (1 << x)) {
          s->tiles[i][0][7 - x] = s->tiles[i][0][7 - x - 1];
        }
        else {
          if (cmp_stream_read_bits(s, 1) == 1) {
            s->tiles[i][0][7 - x] = mpixstream(s, s->tiles[i][0][7 - x - 1], pixels);
          }
          else {
            s->tiles[i][0][7 - x] = s->tiles[i][0][7 - x - 1];
          }
        }
      }

      int vpref = 1;

      for (int y = 6; y >= 0; --y) {
        if (hmap & (1 << y)) {
          memcpy(s->tiles[i][7 - y], s->tiles[i][7 - y - 1], 8);
        }
        else {
          pixels = list_of_set[index];

          if (cmp_stream_read_bits(s, 1) == 1) {
            s->tiles[i][7 - y][0] = mpixstream(s, s->tiles[i][7 - y - 1][0], pixels);
          }
          else {
            s->tiles[i][7 - y][0] = s->tiles[i][7 - y - 1][0];
          }

          for (int x = 6; x >= 0; --x) {
            if (vmap & (1 << x)) {
              s->tiles[i][7 - y][7 - x] = s->tiles[i][7 - y][7 - x - 1];
            }
            else {
              if (vpref) {
                if (cmp_stream_read_bits(s, 1) == 1) {
                  pixels = list_of_set[index];

                  if (s->tiles[i][7 - y][7 - x - 1] == s->tiles[i][7 - y - 1][7 - x]) {
                    s->tiles[i][7 - y][7 - x] = mpixstream(s, s->tiles[i][7 - y][7 - x - 1], pixels);
                  }
                  else {
                    if (cmp_stream_read_bits(s, 1) == 1) {
                      pixels &= ~(1 << s->tiles[i][7 - y - 1][7 - x]);
                      pixels &= ~(1 << s->tiles[i][7 - y][7 - x - 1]);
                      s->tiles[i][7 - y][7 - x] = pixstream(s, pixels);
                    }
                    else {
                      vpref = 0;
                      s->tiles[i][7 - y][7 - x] = s->tiles[i][7 - y - 1][7 - x];
                    }
                  }
                }
                else {
                  s->tiles[i][7 - y][7 - x] = s->tiles[i][7 - y][7 - x - 1];
                }
              }
              else {
                if (cmp_stream_read_bits(s, 1) == 1) {
                  pixels = list_of_set[index];

                  if (s->tiles[i][7 - y][7 - x - 1] == s->tiles[i][7 - y - 1][7 - x]) {
                    s->tiles[i][7 - y][7 - x] = mpixstream(s, s->tiles[i][7 - y][7 - x - 1], pixels);
                  }
                  else {
                    if (cmp_stream_read_bits(s, 1) == 1) {
                      pixels &= ~(1 << s->tiles[i][7 - y - 1][7 - x]);
                      pixels &= ~(1 << s->tiles[i][7 - y][7 - x - 1]);
                      s->tiles[i][7 - y][7 - x] = pixstream(s, pixels);
                    }
                    else {
                      vpref = 1;
                      s->tiles[i][7 - y][7 - x] = s->tiles[i][7 - y][7 - x - 1];
                    }
                  }
                }
                else {
                  s->tiles[i][7 - y][7 - x] = s->tiles[i][7 - y - 1][7 - x];
                }
              }
            }
          }
        }
      }
    }

    tile4_t tile;
    _8bpp_to_4bpp(s->tiles[i], tile);
    memcpy(&dst[s->dst_stream_pos], tile, sizeof(tile4_t));
    s->dst_stream_pos += sizeof(tile4_t);
  }

  if (cmp_size != NULL) {
    *cmp_size = s->src_stream_pos;
  }

  uint32_t result = s->dst_data_size;

  free(s);
  cvector_free(list_of_set);

  return result;
}

uint32_t get_decompressed_size(const uint8_t* src) {
  state_t* s = malloc(sizeof(state_t));

  if (s == NULL) {
    return 0;
  }

  memset(s, 0, sizeof(state_t));

  s->src_data = src;
  s->src_stream_pos = 0;
  s->tiles_num = cmp_stream_read_bits(s, 8) + (cmp_stream_read_bits(s, 2) << 8);
  uint32_t result = s->tiles_num * TILE_4BIT_SIZE;

  free(s);

  return result;
}
