
susi_linux install on desktop
------------------------------
docker pull debian:stretch-slim
docker run -it debian:stretch-slim /bin/bash
adduser pi
	- use password "raspberry"
	- TODO add pi to sudo group?
mkdir /usr/share/man/man1
	-- this is necessary otherwise openjdk installation fails due to update-alternatives problems
	-- setting up links 
apt-get install -y ca-certificates git openssl wget python3-setuptools perl libterm-readline-gnu-perl python3-pip sox libsox-fmt-all flac libportaudio2 libatlas3-base libpulse0 libasound2 vlc-bin vlc-plugin-base vlc-plugin-video-splitter python3-cairo python3-flask flite openjdk-8-jdk-headless pixz udisks2 vlc-nox i2c-tools libasound2-plugins
	-- make sure python-config is found
ln -s python3-config  /usr/bin/python-config
	-- python3 library deps
	-- instead of pip3 install...
apt-get install -y swig python3-requests python3-service-identity python3-pyaudio python3-levenshtein python3-pafy python3-colorlog python3-watson-developer-cloud libpulse-dev libasound2-dev
	-- TODO pip3 install snowboy fails!!!
	-- g++ -I../../ -O3 -fPIC -D_GLIBCXX_USE_CXX11_ABI=0 -std=c++0x  -shared snowboy-detect-swig.o \
  ../..//lib/ubuntu64/libsnowboy-detect.a -L/usr/lib/python3.5/config-3.5m-x86_64-linux-gnu -L/usr/lib -lpython3.5m -lpthread -ldl  -lutil -lm  -Xlinker -export-dynamic -Wl,-O1 -Wl,-Bsymbolic-functions -lm -ldl -lf77blas -lcblas -llapack_atlas -latlas -o _snowboydetect.so
	--  snowboy-detect-swig.o: file not recognized: File format not recognized
	-- see https://github.com/Kitt-AI/snowboy/issues/568

	-- build deps for snowboy
apt-get install -y libatlas-base-dev libasound2-dev
	-- fix broken snowboy pip3 installation
pip3 download --no-deps snowboy
	-- TODO what to do when version number changes?
tar -xf snowboy-1.2.0b1.tar.gz
cd snowboy-1.2.0b1/swig/Python
rm snowboy-detect-swig.cc snowboy-detect-swig.o
cd ../..
python3 setup.py build
python3 setup.py install
cd ..
rm -rf snowboy*
	-- end snowboy fixed installation

cd /home/pi
git clone https://github.com/fossasia/susi_linux.git
SCRIPT_PATH=$(realpath susi_linux/install.sh)
DIR_PATH=$(dirname $SCRIPT_PATH)
git clone https://github.com/fossasia/susi_api_wrapper.git
mv susi_api_wrapper/python_wrapper/susi_python susi_linux/susi_python
mv susi_api_wrapper/python_wrapper/requirements.txt susi_linux/requirements.txt
rm -rf susi_api_wrapper
chown -R pi.pi susi_linux
cd susi_linux
pip3 install -r requirements.txt
	-- remove spidev and RPi.GPIO from requirements.hw
sed -e 's/^spidev//' -e 's/^RPi\.GPIO//' requirements-hw.txt > req-hw.txt
pip3 install -r req-hw.txt
pip3 install -r requirements-special.txt

wget https://raw.githubusercontent.com/videolan/vlc/master/share/lua/playlist/youtube.lua
	-- TODO make PR to susi_linux to improve the arch detection
mv youtube.lua /usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/vlc/lua/playlist/youtube.luac

	-- install susi_server
mkdir $DIR_PATH/susi_server
wget -P /tmp/ http://download.susi.ai/susi_server/susi_server_binary_latest.tar.gz
tar -xzf /tmp/susi_server_binary_latest.tar.gz -C "/tmp"
SUSI_SERVER_PATH=$DIR_PATH/susi_server/susi_server
mv "/tmp/susi_server_binary_latest" "$SUSI_SERVER_PATH"
rm "/tmp/susi_server_binary_latest.tar.gz" || true

SKILL_DATA_PATH=$DIR_PATH/susi_server/susi_skill_data
git clone https://github.com/fossasia/susi_skill_data.git $SKILL_DATA_PATH

	-- again update permissions
chown -R pi.pi /home/pi/susi_linux

	-- update systemd file
$DIR_PATH/Deploy/auto_boot.sh


	-- TODO
	-- here we should CLEAN UP unnecessary stuff to get smaller image!!!

	-- exit from container
docker commit <ID> susi
	-- now we have an image susi

	-- we can start susi_server - works
	-- starting ss-susi-linux service gives:
pi@1d305a8ecf63:~/SUSI.AI/susi_linux$ python3 -m main -v --short-log
connected to local server
Traceback (most recent call last):
  File "/usr/lib/python3.5/runpy.py", line 183, in _run_module_as_main
    mod_name, mod_spec, code = _get_module_details(mod_name, _Error)
  File "/usr/lib/python3.5/runpy.py", line 142, in _get_module_details
    return _get_module_details(pkg_main_name, error)
  File "/usr/lib/python3.5/runpy.py", line 109, in _get_module_details
    __import__(pkg_name)
  File "/home/pi/SUSI.AI/susi_linux/main/__init__.py", line 3, in <module>
    from .states import SusiStateMachine
  File "/home/pi/SUSI.AI/susi_linux/main/states/__init__.py", line 3, in <module>
    from .susi_state_machine import SusiStateMachine
  File "/home/pi/SUSI.AI/susi_linux/main/states/susi_state_machine.py", line 13, in <module>
    from .busy_state import BusyState
  File "/home/pi/SUSI.AI/susi_linux/main/states/busy_state.py", line 11, in <module>
    from ..hotword_engine.stop_detection import StopDetector
  File "/home/pi/SUSI.AI/susi_linux/main/hotword_engine/stop_detection.py", line 5, in <module>
    from snowboy import snowboydecoder
  File "/usr/local/lib/python3.5/dist-packages/snowboy-1.2.0b1-py3.5.egg/snowboy/snowboydecoder.py", line 5, in <module>
    import snowboydetect
ImportError: No module named 'snowboydetect'
pi@1d305a8ecf63:~/SUSI.AI/susi_linux$ 

??

Reason
	/usr/local/lib/python3.5/dist-packages/snowboy-1.2.0b1-py3.5.egg/snowboy/snowboydecoder.py
uses
	import snowboydetect
instead of
	import snowboy.snowboydetect
change this get us further...



-----

next: main/states/led.py need spidev, which is not available, but we shouldn't
play with leds anyway!

leds is only used in lights.py and that is used a lot around, we need to define
	lights.speak/wakeup/think/off()


Fixed by letting led be loadable and detect that it doesn't have a seeed attached

---------

next: no soundcard detected ...

$ python3 -m main -v -v
connected to local server
No spidev, probably no raspi ...
2019-04-08 02:43:18 WARNING:main.states.susi_state_machine: This device doesn't have GPIO port
ALSA lib confmisc.c:767:(parse_card) cannot find card '0'
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_card_driver returned error: No such file or directory
ALSA lib confmisc.c:392:(snd_func_concat) error evaluating strings
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_concat returned error: No such file or directory
ALSA lib confmisc.c:1246:(snd_func_refer) error evaluating name
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_refer returned error: No such file or directory
ALSA lib conf.c:5007:(snd_config_expand) Evaluate error: No such file or directory
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM sysdefault
ALSA lib confmisc.c:767:(parse_card) cannot find card '0'
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_card_driver returned error: No such file or directory
ALSA lib confmisc.c:392:(snd_func_concat) error evaluating strings
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_concat returned error: No such file or directory
ALSA lib confmisc.c:1246:(snd_func_refer) error evaluating name
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_refer returned error: No such file or directory
ALSA lib conf.c:5007:(snd_config_expand) Evaluate error: No such file or directory
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM sysdefault
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.front
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.rear
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.center_lfe
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.side
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.surround21
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.surround21
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.surround40
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.surround41
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.surround50
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.surround51
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.surround71
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.iec958
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.iec958
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.iec958
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.hdmi
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.hdmi
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.modem
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.modem
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.phoneline
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM cards.pcm.phoneline
ALSA lib confmisc.c:767:(parse_card) cannot find card '0'
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_card_driver returned error: No such file or directory
ALSA lib confmisc.c:392:(snd_func_concat) error evaluating strings
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_concat returned error: No such file or directory
ALSA lib confmisc.c:1246:(snd_func_refer) error evaluating name
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_refer returned error: No such file or directory
ALSA lib conf.c:5007:(snd_config_expand) Evaluate error: No such file or directory
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM default
ALSA lib confmisc.c:767:(parse_card) cannot find card '0'
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_card_driver returned error: No such file or directory
ALSA lib confmisc.c:392:(snd_func_concat) error evaluating strings
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_concat returned error: No such file or directory
ALSA lib confmisc.c:1246:(snd_func_refer) error evaluating name
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_refer returned error: No such file or directory
ALSA lib conf.c:5007:(snd_config_expand) Evaluate error: No such file or directory
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM default
ALSA lib confmisc.c:767:(parse_card) cannot find card '0'
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_card_driver returned error: No such file or directory
ALSA lib confmisc.c:392:(snd_func_concat) error evaluating strings
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_concat returned error: No such file or directory
ALSA lib confmisc.c:1246:(snd_func_refer) error evaluating name
ALSA lib conf.c:4528:(_snd_config_evaluate) function snd_func_refer returned error: No such file or directory
ALSA lib conf.c:5007:(snd_config_expand) Evaluate error: No such file or directory
ALSA lib pcm.c:2495:(snd_pcm_open_noupdate) Unknown PCM dmix
Cannot connect to server socket err = No such file or directory
Cannot connect to server request channel
jack server is not running or cannot be started
JackShmReadWritePtr::~JackShmReadWritePtr - Init not done for 4294967295, skipping unlock
JackShmReadWritePtr::~JackShmReadWritePtr - Init not done for 4294967295, skipping unlock
Traceback (most recent call last):
  File "/usr/lib/python3.5/runpy.py", line 193, in _run_module_as_main
    "__main__", mod_spec)
  File "/usr/lib/python3.5/runpy.py", line 85, in _run_code
    exec(code, run_globals)
  File "/home/pi/SUSI.AI/susi_linux/main/__main__.py", line 57, in <module>
    susiStateMachine = SusiStateMachine()
  File "/home/pi/SUSI.AI/susi_linux/main/states/susi_state_machine.py", line 94, in __init__
    components = Components(renderer)
  File "/home/pi/SUSI.AI/susi_linux/main/states/susi_state_machine.py", line 42, in __init__
    self.microphone = Microphone()
  File "/usr/local/lib/python3.5/dist-packages/speech_recognition/__init__.py", line 86, in __init__
    device_info = audio.get_device_info_by_index(device_index) if device_index is not None else audio.get_default_input_device_info()
  File "/usr/lib/python3/dist-packages/pyaudio.py", line 949, in get_default_input_device_info
    device_index = pa.get_default_input_device()
OSError: No Default Input Device Available




