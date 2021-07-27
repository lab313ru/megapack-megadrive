# megapack-megadrive
Megadrive MEGAPACK source code. Original 68k compression algo by Jon Menzies.

## Information
This algorithm was used in Fantastic Dizzy game for Sega Mega Drive to compress characters and sprites data. The second algorithm is [Imploder](https://github.com/lab313ru/AmigaImploder) which was used for everything else.

## Usage
- **Decompression**: `megapack <source.bin> <dest.bin> d [hex_offset]`
- **Compression**: `megapack <source.bin> <dest.bin> c`

## Comparison
Original file: [dump_02d6ee_unp.zip](https://github.com/lab313ru/megapack-megadrive/files/6881795/dump_02d6ee_unp.zip)


| Algo  | Size  |
|---|---|
| Original  | 18752  |
|---|---|
| MEGAPACK (*Fantastic Dizzy*) | 10387  |
| LZMA2  | 10867  |
| GZIP  | 11159  |
| LZH Compression (*Thunder Force 3*)  | 11386  |
| Nemesis Compression (*Many Sega games*) | 11652  |
| ApLib  | 12682  |
| RNC ProPack (*Many Sega games*) | 13297  |
| Imploder Cruncher (*Codemasters Sega games*) | 13584  |
| PowerPacker Cruncher (*Amiga games*) | 13728  |
| LZCaptsu Compression (*Tecmo Cup*) | 14774  |
| LZKN1 Compression (*Konami Sega games*) | 15011  |
| LZToshio Compression (*Crusader of Centy*)  | 15204  |
| The Lost Vikings Compression | 15207  |
| LZKN3 Compression (*Konami Sega games*) | 15392  |
| Fact5LZ Compression (*Internation Superstar Soccer Deluxe*) | 15686  |
| LZKN2 Compression (*Konami Sega games*) | 16204  |
| I.T.L. Compression (*Bonanza Bros.*) | 16512  |

## Screenshots
![](/img/image.png?raw=true "Console window")

## Algorithm description by Derek Leigh-Gilchrist
> Characters and Sprites were compressed with a special compression system that analyzed the images before compressing them, and then used bit packing based on which colours were frequently next to other colours. The compression was an early form of 'deep learning' and it was created by a man called Jon Menzies who worked with us at Codemasters. We used this compression to help keep our games sitting on a 512k rom! It outperformed Lemppel-Ziv compression by about 30% on graphics files!

## Thanks to
- `МАРАТ (CHIEF-NET)` for Pascal compression and decompression source code
- `Derek Leigh-Gilchrist` for "*megaunp.s*"
