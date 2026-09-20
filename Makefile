include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = GPTFloatBallPrefs
GPTFloatBallPrefs_FILES = P.m
GPTFloatBallPrefs_INSTALL_PATH = /Library/PreferenceBundles
GPTFloatBallPrefs_FRAMEWORKS = UIKit
GPTFloatBallPrefs_CFLAGS = -fobjc-arc
GPTFloatBallPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/GPTFloatBall.plist$(ECHO_END)
