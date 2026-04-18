# RCT Challenge - Build System

AS = nasm
LD = ld

ASFLAGS = -f elf64 -g
LDFLAGS = -static

TARGET = rct_engine

SRCS = $(wildcard *.asm)
OBJS = $(SRCS:.asm=.o)

.PHONY: all clean run debug

all: $(TARGET)

$(TARGET): $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $^

%.o: %.asm
	$(AS) $(ASFLAGS) -o $@ $<

run: $(TARGET)
	sudo ./$(TARGET)

debug: $(TARGET)
	sudo gdb ./$(TARGET)

clean:
	rm -f $(TARGET) *.o
