export THEOS = $(CURDIR)/theos
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = GPTFloatBall
GPTFloatBall_FILES = Tweak.xm GPTSettings.m
GPTFloatBall_FRAMEWORKS = UIKit Foundation CoreGraphics
GPTFloatBall_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
GPTFloatBall_LIBRARIES = substrate
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += prefs app
include $(THEOS_MAKE_PATH)/aggregate.mk
