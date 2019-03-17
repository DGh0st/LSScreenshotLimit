export ARCHS = armv7 arm64
export TARGET = iphone:clang:8.1:latest

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LSScreenshotLimit
LSScreenshotLimit_FILES = Tweak.xm
LSScreenshotLimit_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
SUBPROJECTS += lsscreenshotlimit
include $(THEOS_MAKE_PATH)/aggregate.mk
