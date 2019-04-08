#!/bin/bash

### susi_linux install on desktop

release=stretch

## Warning
# This probably only works on a Debian/Stretch machine, not anything else
# we try to support buster here when release is set to buster, but
# this is somehow shaky, and needs more investigation

adduser --gecos "" --disabled-password pi
usermod -a -G audio,video,plugdev pi
	# for sound card access, but we throw in video and plugdev for good
	# TODO: use password "raspberry"?
	# TODO: add pi to sudo group?
mkdir -p /usr/share/man/man1
	# this is necessary otherwise openjdk installation fails due to update-alternatives problems
	# setting up links -- happens only in stretch-slim docker container, but not in real system
apt-get install -y ca-certificates git openssl wget python3-setuptools perl libterm-readline-gnu-perl python3-pip sox libsox-fmt-all flac libportaudio2 libatlas3-base libpulse0 libasound2 vlc-bin vlc-plugin-base vlc-plugin-video-splitter python3-cairo python3-flask flite openjdk-8-jdk-headless pixz udisks2 vlc-nox i2c-tools libasound2-plugins python3-dev
if [ "$release" = "stretch" ] ; then
	apt-get install -y vlc-nox
else
	apt-get install -y vlc-bin
fi

	# python3 library deps
	# instead of pip3 install...
apt-get install -y swig python3-requests python3-service-identity python3-pyaudio python3-levenshtein python3-pafy python3-colorlog python3-watson-developer-cloud libpulse-dev libasound2-dev libatlas-base-dev
	# TODO pip3 install snowboy fails!!!
	# g++ -I../../ -O3 -fPIC -D_GLIBCXX_USE_CXX11_ABI=0 -std=c++0x  -shared snowboy-detect-swig.o \
	#  ../..//lib/ubuntu64/libsnowboy-detect.a -L/usr/lib/python3.5/config-3.5m-x86_64-linux-gnu -L/usr/lib -lpython3.5m -lpthread -ldl  -lutil -lm  -Xlinker -export-dynamic -Wl,-O1 -Wl,-Bsymbolic-functions -lm -ldl -lf77blas -lcblas -llapack_atlas -latlas -o _snowboydetect.so
	#  snowboy-detect-swig.o: file not recognized: File format not recognized
	# see https://github.com/Kitt-AI/snowboy/issues/568

	# fix broken snowboy pip3 installation
pip3 download --no-deps snowboy
	# TODO what to do when version number changes?
tar -xf snowboy-1.2.0b1.tar.gz
cd snowboy-1.2.0b1/swig/Python
make clean
sed -i -e 's/python-config/python3-config/g' Makefile
cd ../..
python3 setup.py build
python3 setup.py install
cd ..
rm -rf snowboy*
	# end snowboy fixed installation

cd /home/pi
mkdir SUSI.AI
cd SUSI.AI
git clone https://github.com/fossasia/susi_linux.git
SCRIPT_PATH=$(realpath susi_linux/install.sh)
DIR_PATH=$(dirname $SCRIPT_PATH)
git clone https://github.com/fossasia/susi_api_wrapper.git
mv susi_api_wrapper/python_wrapper/susi_python susi_linux/susi_python
mv susi_api_wrapper/python_wrapper/requirements.txt susi_linux/requirements.txt
rm -rf susi_api_wrapper
chown -R pi.pi /home/pi/SUSI.AI
cd susi_linux
if [ "$release" = "stretch"] ; then
	pip3 install -U wheel	# necessary, otherwise "future" installation is broken
fi
pip3 install -r requirements.txt
	# remove spidev and RPi.GPIO from requirements.hw
sed -e 's/^spidev//' -e 's/^RPi\.GPIO//' requirements-hw.txt > req-hw.txt
if [ "$release" = "stretch"] ; then
	pip3 install -r req-hw.txt
else
	# req-hw has problems:
	# - server does not have packages for buster python 3.7
	# - rx is not available?
	pip3 install speechRecognition==3.8.1 service_identity pocketsphinx==0.1.15 pyaudio json_config google_speech async_promises python-Levenshtein pyalsaaudio 'youtube-dl>2018' python-vlc pafy colorlog
fi
pip3 install -r requirements-special.txt

wget https://raw.githubusercontent.com/videolan/vlc/master/share/lua/playlist/youtube.lua
	# TODO make PR to susi_linux to improve the arch detection
mv youtube.lua /usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/vlc/lua/playlist/youtube.luac

	# install susi_server
mkdir $DIR_PATH/susi_server
wget -P /tmp/ http://download.susi.ai/susi_server/susi_server_binary_latest.tar.gz
tar -xzf /tmp/susi_server_binary_latest.tar.gz -C "/tmp"
SUSI_SERVER_PATH=$DIR_PATH/susi_server/susi_server
mv "/tmp/susi_server_binary_latest" "$SUSI_SERVER_PATH"
rm "/tmp/susi_server_binary_latest.tar.gz" || true

SKILL_DATA_PATH=$DIR_PATH/susi_server/susi_skill_data
git clone https://github.com/fossasia/susi_skill_data.git $SKILL_DATA_PATH

	# again update permissions
chown -R pi.pi /home/pi/SUSI.AI

	# update systemd file
$DIR_PATH/Deploy/auto_boot.sh

	# fix snowboydecoder.py
	# Reason
	#	/usr/local/lib/python3.5/dist-packages/snowboy-1.2.0b1-py3.5.egg/snowboy/snowboydecoder.py
	# uses
	#	import snowboydetect
	# instead of
	#	import snowboy.snowboydetect
	# change this get us further...
sed -i -e 's/^import snowboydetect/import snowboy.snowboydetect/' \
	/usr/local/lib/python3.5/dist-packages/snowboy-1.2.0b1-py3.5.egg/snowboy/snowboydecoder.py



	# fix main/states/led.py
	# Fixed by letting led be loadable and detect that it doesn't have a seeed attached
cd $DIR_PATH
patch -p1 <<'EOF'
diff --git a/main/states/led.py b/main/states/led.py
index fa84f2a..7ec9e30 100644
--- a/main/states/led.py
+++ b/main/states/led.py
@@ -1,6 +1,10 @@
-import spidev
+try:
+    import spidev
+except ImportError:
+    print("No spidev, probably no raspi ...")
 import subprocess
 import sys
+import os
 from math import ceil
 
 RGB_MAP = {'rgb': [3, 2, 1], 'rbg': [3, 1, 2], 'grb': [
@@ -15,9 +19,12 @@ class LED_COLOR:
 
     def __init__(self, num_led, global_brightness=MAX_BRIGHTNESS,
                  order='rgb', bus=0, device=1, max_speed_hz=8000000):
-        output = subprocess.check_output(
-            ["cat", "/proc/asound/cards"]).decode(sys.stdout.encoding)
-        self.seeed_attached = output.find("seeed") != -1
+        if (os.access("/proc/asound/cards", os.R_OK)):
+            output = subprocess.check_output(
+                ["cat", "/proc/asound/cards"]).decode(sys.stdout.encoding)
+            self.seeed_attached = output.find("seeed") != -1
+        else:
+            self.seeed_attached = False
         if (not self.seeed_attached):
             return
         self.num_led = num_led  # The number of LEDs in the Strip
EOF




