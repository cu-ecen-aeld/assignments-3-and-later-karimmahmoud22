# File: server/Makefile

CC ?= gcc
CFLAGS ?= -Wall -Wextra -Werror -std=gnu99

TARGET = aesdsocket
SRC = aesdsocket.c

all: $(TARGET)

default: all

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)

clean:
	rm -f $(TARGET)
