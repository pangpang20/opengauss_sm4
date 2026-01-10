# SM4 Extension Makefile for OpenGauss

OGHOME ?= /usr/local/opengauss

CXX = g++
CXXFLAGS = -O2 -Wall -fPIC -std=c++11

INCLUDES = -I$(OGHOME)/include/postgresql/server \
           -I$(OGHOME)/include/postgresql/internal \
           -I$(OGHOME)/include

OBJS = sm4.o sm4_ext.o
TARGET = sm4.so

LIBDIR = $(OGHOME)/lib/postgresql
EXTDIR = $(OGHOME)/share/postgresql/extension

DOCKER_BUILD ?= 0

.PHONY: all clean install

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) -shared -o $@ $(OBJS)

sm4.o: sm4.c sm4.h
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c -o $@ $<

sm4_ext.o: sm4_ext.cpp sm4.h
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c -o $@ $<

install: $(TARGET)
ifeq ($(DOCKER_BUILD),1)
	mkdir -p $(LIBDIR)
	mkdir -p $(EXTDIR)
endif
	cp $(TARGET) $(LIBDIR)/
	cp sm4.control $(EXTDIR)/
	cp sm4--1.0.sql $(EXTDIR)/
	@echo "Installation complete!"

clean:
	rm -f $(OBJS) $(TARGET)