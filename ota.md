
## Installation

    - rebased against recent master (fixed conflicts)
    - depends on modified SDK/libmain.a
        added to Makefile: $(OBJCOPY) -W Cache_Read_Enable_New $(SDK_DIR)/lib/libmain.a $(SDK_DIR)/lib/libmain2.a
    - depends on esptool2
        - currently, to live inside root folder
        - purpose of this program is not clear to me
        - can esptool.py be enhanced?
        
## warnings

On compilation, I get this. Is it important?

../tools/esptool.py elf2image .output/eagle/debug/image/eagle.app.v6.out -o ../bin/
esptool.py v1.2-dev
WARNING: irom0 section offset is 0x00002010. ELF is probably linked for 'elf2image --version=2'        