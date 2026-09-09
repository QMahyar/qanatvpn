@echo off
set ANDROID_HOME=C:\Users\qmahyar\AppData\Local\Android\Sdk
set ANDROID_NDK_HOME=%ANDROID_HOME%\ndk\28.2.13676358
set JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot
set PATH=C:\Users\qmahyar\go\bin;C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin;C:\Program Files\Git\usr\bin;C:\Program Files\Go\bin;%PATH%
set FORK=go/amnezia-box
set PKG=./experimental/libbox
set VERSION=1.14.0-rc.1-awgm.15
set LDFLAGS=-X github.com/sagernet/sing-box/constant.Version=%VERSION% -X runtime.godebugDefault=multipathtcp=0,tlssha1=1,tlsunsafeekm=1 -checklinkname=0 -s -w -buildid=
set TAGS_MAIN=with_gvisor,with_quic,with_wireguard,with_utls,with_naive_outbound,with_clash_api,with_usbip,with_openvpn,with_openconnect,badlinkname,tfogo_checklinkname0,with_tailscale,ts_omit_logtail,ts_omit_ssh,ts_omit_drive,ts_omit_taildrop,ts_omit_webclient,ts_omit_doctor,ts_omit_capture,ts_omit_kube,ts_omit_aws,ts_omit_synology,ts_omit_bird,with_awg
cd /d %FORK%
gomobile bind -v -o ../../android/app/libs/libbox.aar -target android -androidapi 24 -javapkg=com.qanatvpn -libname=box -trimpath -buildvcs=false -ldflags "%LDFLAGS%" -tags "%TAGS_MAIN%" ./experimental/libbox
