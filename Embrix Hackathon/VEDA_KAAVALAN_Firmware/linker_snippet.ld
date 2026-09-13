/* Linker script snippet for VEDA KAAVALAN */
MEMORY
{
  FLASH (rx) : ORIGIN = 0x20000000, LENGTH = 2048K  /* 2MB Flash */
  SRAM (rwx) : ORIGIN = 0x80000000, LENGTH = 256K   /* 256KB SRAM */
}

SECTIONS
{
  .text : {
    *(.text*)
  } > FLASH

  .rodata : {
    . = ALIGN(4);
    *(.rodata*)        /* Constants, CNN weights, LUTs stay in FLASH */
    *(.srodata*)
    . = ALIGN(4);
  } > FLASH

  .data : {
    . = ALIGN(4);
    _sdata = .;
    *(.data*)          /* Initialized globals copied to SRAM at boot */
    *(.sdata*)
    . = ALIGN(4);
    _edata = .;
  } > SRAM AT > FLASH

  .bss (NOLOAD) : {
    *(.bss*)
    *(.sbss*)
    *(COMMON)
  } > SRAM
}
