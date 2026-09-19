export THEOS = $(CURDIR)/theos

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
else ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
else
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
endif

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GPTFloatBall
GPTFloatBall_FILES = Tweak.xm GPTChatViewController.m GPTSettings.m
GPTFloatBall_FRAMEWORKS = UIKit Foundation CoreGraphics
GPTFloatBall_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
GPTFloatBall_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
