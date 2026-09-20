export THEOS = $(CURDIR)/theos
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GPTFloatBall GPTKeyBar

GPTFloatBall_FILES = Tweak.xm GPTSettings.m
GPTFloatBall_FRAMEWORKS = UIKit Foundation
GPTFloatBall_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
GPTFloatBall_LIBRARIES = substrate

GPTKeyBar_FILES = KeyBar.xm GPTSettings.m
GPTKeyBar_FRAMEWORKS = UIKit Foundation
GPTKeyBar_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
GPTKeyBar_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
