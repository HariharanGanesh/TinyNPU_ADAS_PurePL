MEMORY {
    BRAM (rwx) : ORIGIN = 0x00000000, LENGTH = 4096
}
SECTIONS {
    .text : {
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
    } > BRAM

    .data : {
        *(.data)
        *(.sdata)
    } > BRAM

    .bss : {
        *(.bss)
        *(.sbss)
        *(COMMON)
    } > BRAM
}
