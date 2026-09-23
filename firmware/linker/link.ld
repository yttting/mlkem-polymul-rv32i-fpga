ENTRY(_start)

MEMORY
{
  ram (rwx) : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS
{
  . = ORIGIN(ram);

  .text : {
    *(.text.startup*)
    *(.text*)
  } > ram

  .rodata : {
    . = ALIGN(4);
    *(.rodata*)
  } > ram

  .data : {
    . = ALIGN(4);
    *(.data*)
  } > ram

  .bss (NOLOAD) : {
    . = ALIGN(4);
    *(.bss*)
    *(COMMON)
  } > ram

  _end = .;
  ASSERT(_end <= 0x00000e00,
         "profiling firmware leaves less than 496 bytes below the 0x0ff0 stack")
}
