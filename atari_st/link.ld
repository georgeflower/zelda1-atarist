/*
 * A TOS .PRG is a flat image, so everything lands in one output section.
 *
 * Order matters twice over:
 *  - .data (variables, stack, the digidrum engine) comes first, right behind the boot jump, so
 *    PC-relative references to it from anywhere in the first 32 KB of code stay in the 68000's
 *    signed 16-bit displacement however large the code grows. It also must come before the
 *    large .rodata tables.
 *  - .stack goes last for the same reason: it is 4KB of zeros nothing needs
 *    to reach with a displacement.
 */
SECTIONS
{
  . = 0;

  .text :
  {
    *(.text.boot)
    *(.data*)
    *(.text)
    *(.text.late)
    *(.rodata*)
    *(.stack*)
  }

  /DISCARD/ :
  {
    *(.comment*)
    *(.note*)
    *(.eh_frame*)
  }
}
