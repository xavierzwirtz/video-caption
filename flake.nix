{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      {
        packages = rec {
          video-caption = pkgs.writeShellApplication {
            name ="video-caption";
            runtimeInputs = [ pkgs.ffmpeg pkgs.imagemagick ];
            text = ''
              export FONTCONFIG_FILE="${pkgs.makeFontsConf {
                   fontDirectories = with pkgs; [ open-sans ];
              }}"
              working=$(mktemp -d)
              trap '{ rm -rf -- "$working"; }' EXIT
              mkdir -p "$working/frames" "$working/frames_mod"

              framerate=$(ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate "$1")
              codec=$(ffprobe -v 0 -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$1")

              ffmpeg \
                -hide_banner \
                -loglevel error \
                -i "$1" \
                "$working/frames/%d.png"

              width=$(identify -ping -format '%w' "$working/frames/1.png")
              height=$(identify -ping -format '%h' "$working/frames/1.png")
              caption_height=$((height / 2))
              convert \
                -background white \
                -fill black \
                -font Open-Sans-Bold \
                -size "$((width - 40))x''${caption_height}" \
                -extent "''${width}x" \
                -gravity center \
                label:"$2" \
                "$working/header.png"
              for f in "$working/frames/"*
              do
                 convert \
                   -append "$working/header.png" \
                   "$f" \
                   "$working/frames_mod/$(basename "$f")"
              done

              ffmpeg \
                -hide_banner \
                -loglevel error \
                -y \
                -framerate "$framerate" \
                -i "$working/frames_mod/%d.png" \
                -i "$1" \
                -c copy -map 0:0 -map 1:1 \
                -c:v "$codec" \
                -pix_fmt yuv420p \
                "$3"
            '';
          };
          default = video-caption;
        };
      }
    );
}
