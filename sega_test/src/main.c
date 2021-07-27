#include <genesis.h>
#include "test.h"

u32 volatile frames, prev_frames;

static void vb_callback() {
    frames++;
}

static void call_init_mega() {
    register volatile u8* a2 asm ("a2") = (volatile u8*)0xFFD4CA;
    asm volatile (
        "jsr init_mega+0"
        : "+a" (a2)
        : "a" (a2)
        : "d0", "d1", "d2", "d3", "d4", "d5", "d6", "d7", "a0", "a1", "a3", "a4", "a5", "a6");
}

static void call_megaunp(const u8* data, u8* dest) {
    register const u8* a0 asm ("a0") = data;
    register u8* a1 asm ("a1") = dest;
    asm volatile (
        "jsr megaunp+0"
        : "+a" (a0), "+a" (a1)
        : "a" (a0), "a" (a1)
        : "d0", "d1", "d2", "d3", "d4", "d5", "d6", "d7", "a2", "a3", "a4", "a5", "a6");
}

int main(u16 hard) {
    char tmp[16];
    u8* test_dest = MEM_alloc(0x8000);
    SYS_setVIntCallback(vb_callback);

    call_init_mega();

	while (TRUE) {
        frames = 0;

        for (u16 i = 0; i < 20; ++i) {
            call_megaunp(test, test_dest);
        }

        sprintf(tmp , "%lu", frames);
        VDP_drawText(tmp, 16, 16);

        SYS_doVBlankProcess();

        frames = 0;
	}

	MEM_free(test_dest);

    return 0;
}
