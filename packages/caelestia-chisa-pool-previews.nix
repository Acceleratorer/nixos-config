{
  caelestiaRealGreeter,
  lib,
  libglvnd,
  mesa,
  stdenvNoCC,
  xorgserver,
}:

stdenvNoCC.mkDerivation {
  pname = "caelestia-chisa-pool-previews";
  version = "1.0.0";
  dontUnpack = true;

  buildPhase = ''
    runHook preBuild

    export CAELESTIA_GREETER_RUNTIME_DIR="$TMPDIR/caelestia-real-greeter"
    export FONTCONFIG_FILE=${caelestiaRealGreeter.fontconfig}
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
    export LIBGL_ALWAYS_SOFTWARE=1
    export LIBGL_DRIVERS_PATH=${mesa}/lib/dri
    export LD_LIBRARY_PATH=${mesa}/lib:${libglvnd}/lib
    export MESA_LOADER_DRIVER_OVERRIDE=swrast
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    export QT_QPA_PLATFORM=xcb
    export QT_XCB_GL_INTEGRATION=xcb_glx
    export QSG_RHI_BACKEND=opengl
    export XDG_RUNTIME_DIR="$TMPDIR/runtime"
    install -dm 0700 "$XDG_RUNTIME_DIR"

    displayNumber=$((100 + $$ % 400))
    display=":$displayNumber"
    socket="/tmp/.X11-unix/X$displayNumber"
    ${xorgserver}/bin/Xvfb "$display" -screen 0 1920x1080x24 +iglx -nolisten tcp > "$TMPDIR/xvfb.log" 2>&1 &
    xvfbPid=$!
    trap 'kill "$xvfbPid" 2>/dev/null || true' EXIT
    export DISPLAY="$display"

    for _ in $(seq 1 100); do
      if test -S "$socket"; then
        break
      fi
      sleep 0.05
    done
    test -S "$socket"

    render() {
      name=$1
      executable=$2
      runtime="$TMPDIR/$name-runtime"
      install -dm 0700 "$runtime/greeter"
      CAELESTIA_SCREENSHOT="$TMPDIR/$name.png" \
      CAELESTIA_SCREENSHOT_DELAY_MS=2600 \
      CAELESTIA_GREETER_RUNTIME_DIR="$runtime/greeter" \
        timeout 30 "$executable"
      test -s "$TMPDIR/$name.png"
      test "$(od -An -t u4 -j 16 -N 8 --endian=big "$TMPDIR/$name.png" | tr -s ' ' | sed 's/^ //')" = \
        "1920 1080"
    }

    render greeter ${caelestiaRealGreeter}/bin/caelestia-real-greeter-preview
    render lock ${caelestiaRealGreeter}/bin/caelestia-real-lock-preview

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -dm 0755 "$out/share/caelestia-chisa-pool-previews"
    install -m 0444 "$TMPDIR/greeter.png" \
      "$out/share/caelestia-chisa-pool-previews/greeter.png"
    install -m 0444 "$TMPDIR/lock.png" \
      "$out/share/caelestia-chisa-pool-previews/lock.png"

    runHook postInstall
  '';

  meta = {
    description = "Build-only Caelestia chisa-pool greeter and lock previews";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
