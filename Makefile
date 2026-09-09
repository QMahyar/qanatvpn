# Makefile - QANATVPN per SPEC.md:Commands
#
# Builds libbox aar/dll from the pinned amnezia-box fork.
# Fork: hoaxisr/amnezia-box @ 1.14.0-rc.1-awgm.15 (SHA 57276220a20679cad762c9644f6abdaf39ab7688)
# Recipe mirrors go/amnezia-box/cmd/internal/build_libbox (official tags) + with_awg.
# Requires: Go 1.25+, sagernet/gomobile v0.1.13 (gomobile + gobind in GOPATH/bin),
# ANDROID_HOME + ANDROID_NDK_HOME (NDK 28), JDK 17.

FORK := go/amnezia-box
PKG := ./experimental/libbox
VERSION := 1.14.0-rc.1-awgm.15
LDFLAGS := "-X github.com/sagernet/sing-box/constant.Version=$(VERSION) -X runtime.godebugDefault=multipathtcp=0,tlssha1=1,tlsunsafeekm=1 -checklinkname=0 -s -w -buildid="

TAGS_MAIN := with_gvisor,with_quic,with_wireguard,with_utls,with_naive_outbound,with_clash_api,with_usbip,with_openvpn,with_openconnect,badlinkname,tfogo_checklinkname0,with_tailscale,ts_omit_logtail,ts_omit_ssh,ts_omit_drive,ts_omit_taildrop,ts_omit_webclient,ts_omit_doctor,ts_omit_capture,ts_omit_kube,ts_omit_aws,ts_omit_synology,ts_omit_bird,with_awg
TAGS_WINDOWS := $(TAGS_MAIN),with_purego
TAGS_LEGACY := $(filter-out with_naive_outbound,$(TAGS_MAIN))

.PHONY: lib_android lib_legacy lib_windows test_libbox

lib_android:
	cd $(FORK) && gomobile bind -v -o ../../android/app/libs/libbox.aar -target android -androidapi 24 -javapkg=com.qanatvpn -libname=box -trimpath -buildvcs=false -ldflags $(LDFLAGS) -tags "$(TAGS_MAIN)" $(PKG)

lib_legacy:
	cd $(FORK) && gomobile bind -v -o ../../android/app/libs/libbox-legacy.aar -target android -androidapi 21 -javapkg=com.qanatvpn -libname=box -trimpath -buildvcs=false -ldflags $(LDFLAGS) -tags "$(TAGS_LEGACY)" $(PKG)

# Windows: sing-box.exe subprocess (upstream has no c-shared dll; libbox is a
# library package, and the app talks to the box command server / clash API).
# Needs CGO_ENABLED=1 + gcc (WinLibs UCRT) only for cgo builds; exe is CGO_ENABLED=0.
lib_windows:
	cd $(FORK) && CGO_ENABLED=0 go build -trimpath -buildvcs=false -ldflags $(LDFLAGS) -tags "$(TAGS_WINDOWS)" -o ../../windows/sing-box.exe ./cmd/sing-box

test_libbox:
	cd $(FORK) && go test -tags "$(TAGS_MAIN)" ./option/... ./experimental/libbox/...
