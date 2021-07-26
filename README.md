# megapack-megadrive
Megadrive MEGAPACK source code. Original 68k compression algo by Jon Menzies.

## Information
This algorithm was used in Fantastic Dizzy game for Sega Mega Drive to compress characters and sprites data. The second algorithm is [Imploder](https://github.com/lab313ru/AmigaImploder) which was used for everything else.

## Usage
- **Decompression**: `megapack <source.bin> <dest.bin> d [hex_offset]`
- **Compression**: `megapack <source.bin> <dest.bin> c`

## Algorithm description by Derek Leigh-Gilchrist
> Characters and Sprites were compressed with a special compression system that analyzed the images before compressing them, and then used bit packing based on which colours were frequently next to other colours. The compression was an early form of 'deep learning' and it was created by a man called Jon Menzies who worked with us at Codemasters. We used this compression to help keep our games sitting on a 512k rom! It outperformed Lemppel-Ziv compression by about 30% on graphics files!

## Thanks to
- `МАРАТ (CHIEF-NET)` for Pascal compression and decompression source code
- `Derek Leigh-Gilchrist` for "*megaunp.s*"
