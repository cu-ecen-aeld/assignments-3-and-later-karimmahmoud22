CC = $(CROSS_COMPILE)gcc
CFLAGS = -Wall -Werror

all: writer

writer: writer.o
	$(CC) $(CFLAGS) -o writer writer.o

writer.o: finder-app/writer.c
	$(CC) $(CFLAGS) -c finder-app/writer.c

clean:
	rm -f writer writer.o
