# You can put your build options here
-include config.mk

CC=cc
CCFLAGS=-Wall
LDFLAGS=
TARGET=test

all: test

test: test.o color.o
	$(CC) -o $@ $^  $(LDFLAGS) 
	@rm -f *.o
	@cp color.c ../color.c
	@cp color.h ../color.h
	@echo "--- end output make ---"
	@echo


%.o: %.c 
	$(CC) $(CCFLAGS) -c $<
		 

clean:
	@rm -f *.o $(TARGET)
	@ls | grep -v Makefile | grep -v \\. | xargs rm

.PHONY: all clean $(TARGET)

