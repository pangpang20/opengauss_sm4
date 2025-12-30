# SM4 Extension Makefile for OpenGauss

# OpenGauss安装路径
OGHOME ?= /usr/local/opengauss

# 编译器 (必须用g++)
CXX = g++
CXXFLAGS = -O2 -Wall -fPIC -std=c++11

# 包含路径
INCLUDES = -I$(OGHOME)/include/postgresql/server \
           -I$(OGHOME)/include/postgresql/internal \
           -I$(OGHOME)/include

# 目标文件
OBJS = sm4.o sm4_ext.o
TARGET = sm4.so

# 安装路径
LIBDIR = $(OGHOME)/lib/postgresql
EXTDIR = $(OGHOME)/share/postgresql/extension

.PHONY: all clean install

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) -shared -o $@ $(OBJS)

sm4.o: sm4.c sm4.h
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c -o $@ $<

sm4_ext.o: sm4_ext.c sm4.h
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c -o $@ $<

install: $(TARGET)
	cp $(TARGET) $(LIBDIR)/
	cp sm4.control $(EXTDIR)/
	cp sm4--1.0.sql $(EXTDIR)/
	@echo "安装完成!"

clean:
	rm -f $(OBJS) $(TARGET)
