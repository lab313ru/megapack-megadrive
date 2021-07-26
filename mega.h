#pragma once

#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "cvector.h"

#define TILE_4BIT_SIZE (32)
#define TILE_8BIT_SIZE_W (8)
#define TILE_8BIT_SIZE_H (8)
#define TILE_8BIT_SIZE (TILE_8BIT_SIZE_W * TILE_8BIT_SIZE_H)
#define MAX_SET_NUMS (512)

typedef uint8_t tile4_t[TILE_4BIT_SIZE];
typedef uint8_t tile8_t[TILE_8BIT_SIZE_W][TILE_8BIT_SIZE_H];

typedef struct bstream_t {
  uint8_t data[128]; // seems to be enough
  uint8_t bits;
  uint8_t byte;
  uint8_t total;
} bstream_t;

typedef struct packed_tile_t {
  uint8_t hhi, hlo;
  uint8_t vhi, vlo;
  uint8_t vbits[8];
  uint16_t pixels;
  bstream_t packed;
  uint16_t size;
} packed_tile_t;

typedef struct state_t {
  uint32_t cmp_long;
  uint8_t cmp_bits_used;
  uint32_t src_stream_pos;
  uint32_t dst_stream_pos;
  uint32_t tiles_num;

  const uint8_t* src_data;
  uint32_t src_data_size;

  uint8_t* dst_data;
  uint32_t dst_data_size;

  tile8_t tiles[1024];
  packed_tile_t similar_tiles[1024];
  packed_tile_t line_repeats_tiles[1024];
} state_t;

uint32_t get_decompressed_size(const uint8_t* src);
uint32_t decompress(const uint8_t* src, uint8_t* dst, uint32_t* cmp_size);
uint32_t compress(const uint8_t* src, uint32_t size, uint8_t* dest);
