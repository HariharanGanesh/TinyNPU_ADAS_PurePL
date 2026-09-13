.section .text
.global _start
_start:
    /* Initialize stack pointer to end of 4KB BRAM */
    li sp, 0x00001000
    
    /* Call main */
    call main
    
    /* Loop forever if main returns */
1:
    j 1b
