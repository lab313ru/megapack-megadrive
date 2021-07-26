#include <stdio.h>
#include "mega.h"

static void print_info() {
  printf("Mega (Un)packer v1.0 [27/07/2021]\n");
  printf("Original code for 68k: Codemasters (Jon Menzies)\n");
  printf("Thanks to Derek Leigh-Gilchrist for 'megaunp.s'\n");
  printf("Source code (Delphi) by: MAPAT\n");
  printf("Source code (C) by: DrMefistO\n\n");
}

static void print_help() {
  printf("Usage (unpack): megapacker <source.bin> <dest.bin> d [hex_offset]\n");
  printf("Usage   (pack): megapacker <source.bin> <dest.bin> c\n\n");
}

int main(int argc, char* argv[]) {
  print_info();

  if (argc < 4) {
    print_help();
    return -1;
  }

  int mode = argv[3][0];
  uint32_t offset = 0;

  if (mode != 'd' && mode != 'c') {
    printf("Incorrect usage mode. Valid are: [d, c]. Passed: %c\n", mode & 0xFF);
    print_help();
    return -1;
  }

  if (mode == 'd' && argc == 5) {
    offset = (uint32_t)strtol(argv[4], NULL, 16);
  }

  FILE* f = fopen(argv[1], "rb");

  if (f == NULL) {
    printf("Cannot open source file!\n");
    return -1;
  }

  fseek(f, 0, SEEK_END);
  uint32_t src_size = ftell(f) - offset;
  fseek(f, offset, SEEK_SET);

  uint8_t* src_data = (uint8_t*)malloc(src_size);

  if (src_data == NULL) {
    fclose(f);
    printf("Cannot allocate source data memory!\n");
    return -1;
  }

  if (fread(src_data, 1, src_size, f) != src_size) {
    free(src_data);
    fclose(f);
    printf("Cannot read source data!\n");
    return -1;
  }

  fclose(f);

  FILE* w = fopen(argv[2], "wb");

  if (w == NULL) {
    free(src_data);
    printf("Cannot open destination file!\n");
    return -1;
  }

  uint32_t dst_size = 0;

  if (mode == 'd') {
    dst_size = get_decompressed_size(src_data);

    if (dst_size == 0) {
      free(src_data);
      fclose(w);
      printf("Wrong source binary data! Decompression size is 0!\n");
      return -1;
    }
  }
  else {
    dst_size = src_size;
  }
  
  uint8_t* dst_data = (uint8_t*)malloc(dst_size);

  if (dst_data == NULL) {
    free(src_data);
    fclose(w);
    printf("Cannot allocate destination data memory!\n");
    return -1;
  }

  if (mode == 'd') {
    decompress(src_data, dst_data, &src_size);

    printf("Successfully decompressed!\n");
  }
  else {
    dst_size = compress(src_data, src_size, dst_data);

    printf("Successfully compressed!\n");
  }

  fwrite(dst_data, 1, dst_size, w);
  fclose(w);
  free(dst_data);
  free(src_data);

  printf("Original size / Result size: %lu/%lu\n", src_size, dst_size);

  return 0;
}