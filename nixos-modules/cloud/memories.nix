{
  stdenv,
  buildGo127Module,
  exiftool,
  fetchurl,
  ffmpeg-headless,
  fetchFromGitHub,
  lib,
  replaceVars,
}:
let
  inherit (lib) getExe getExe' licenses;
  version = "11.1.4";

  meta = {
    homepage = "https://apps.nextcloud.com/apps/memories";
    changelog = "https://github.com/pulsejet/memories/blob/v${version}/CHANGELOG.md";
    license = licenses.agpl3Only;
  };

  go-vod = buildGo127Module {
    pname = "go-vod";
    inherit version meta;

    src = fetchFromGitHub {
      owner = "pulsejet";
      repo = "memories";
      tag = "v${version}";
      hash = "sha256-8ZGPfx3bQyUHoh0huuYgA5utCl69SVkRYz0+tumGOGY=";
    };

    sourceRoot = "source/go-vod";
    vendorHash = "sha256-rEJXO55TKg3GMV5/5JQsRf0tktzNQovY9ONtDFuznqk=";
  };
in
stdenv.mkDerivation {
  pname = "nextcloud-app-memories";
  inherit version meta;

  src = fetchurl {
    url = "https://github.com/pulsejet/memories/releases/download/v${version}/memories.tar.gz";
    hash = "sha256-ObXsa/F1M0Qy6MQJoEhNqGb/+QPGNJQsyzxBgJ+QY1M=";
  };

  patches = [
    (replaceVars ./memories-paths.diff {
      exiftool = getExe exiftool;
      ffmpeg = getExe ffmpeg-headless;
      ffprobe = getExe' ffmpeg-headless "ffprobe";
      go-vod = getExe' go-vod "go-vod";
    })
  ];

  postPatch = ''
    rm appinfo/signature.json
    rm -r bin-ext/
    sed -i "s/EXIFTOOL_VER = .*/EXIFTOOL_VER = '${exiftool.version}';/" lib/Service/BinExt.php
  '';

  installPhase = ''
    cp -r . $out
  '';
}
