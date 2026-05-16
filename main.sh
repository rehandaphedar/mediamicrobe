#!/usr/bin/env bash

SOURCE_ROOT="videos"
DESTINATION_ROOT="static/videos"
CONTENT_ROOT="content/videos"

SOURCE_THUMBNAIL_NAME="thumbnail.webp"
SOURCE_TRACKS_NAME="tracks"
SOURCE_PAGE_NAME="_index.md"
SOURCE_VIDEO_NAME="video.mp4"
SOURCE_RENDITIONS_NAME="renditions"

DESTINATION_THUMBNAIL_NAME="thumbnail.webp"
DESTINATION_TRACKS_NAME="tracks"
DESTINATION_PREVIEW_THUMBNAILS_NAME="tracks/thumbnails"
DESTINATION_RENDITIONS_NAME="renditions"

CONTENT_PAGE_NAME="_index.md"

RENDITIONS=(
	"1080p:1080:5000k"
	"720p:720:2800k"
	"480p:480:1400k"
	"360p:360:800k"
)
ABR="128k"

FPS=30
# Note: FRAGMENT_DURATION and SEGMENT_DURATION must be exact multiples of GOP_SIZE
FRAGMENT_DURATION=2
SEGMENT_DURATION=$((FRAGMENT_DURATION * 3))
GOP_SIZE=$((FRAGMENT_DURATION * FPS))

HLS_MASTER_NAME="master.m3u8"
DASH_MANIFEST_NAME="manifest.mpd"

main() {
	mkdir -p "$DESTINATION_ROOT"
	mkdir -p "$CONTENT_ROOT"

	local dir slug
	local source_dir source_thumbnail source_tracks
	local source_page source_video
	local destination_dir destination_thumbnail destination_tracks
	local content_dir content_page
	local source_audio_dir source_audio

	for dir in "$SOURCE_ROOT"/*; do
		slug="$(basename "$dir")"

		source_dir="$(realpath "$dir")"
		source_thumbnail="$source_dir/$SOURCE_THUMBNAIL_NAME"
		source_tracks="$source_dir/$SOURCE_TRACKS_NAME"
		source_renditions="$source_dir/$SOURCE_RENDITIONS_NAME"

		source_page="$source_dir/$SOURCE_PAGE_NAME"
		source_video="$source_dir/$SOURCE_VIDEO_NAME"

		destination_dir="$DESTINATION_ROOT/$slug"
		destination_thumbnail="$DESTINATION_THUMBNAIL_NAME"
		destination_tracks="$DESTINATION_TRACKS_NAME"
		destination_renditions="$DESTINATION_RENDITIONS_NAME"

		content_dir="$CONTENT_ROOT/$slug"
		content_page="$content_dir/$CONTENT_PAGE_NAME"

		rm -rf "$content_dir"
		mkdir -p "$content_dir"
		cp "$source_page" "$content_page"

		mkdir -p "$destination_dir"
		(
			cd "$destination_dir"

			rm -f "$destination_thumbnail"
			cp "$source_thumbnail" "$destination_thumbnail"

			rm -rf "$destination_tracks"
			cp -r "$source_tracks" "$destination_tracks"

			mkdir -p "$DESTINATION_PREVIEW_THUMBNAILS_NAME"
			frametome -input "$source_video" -output "$DESTINATION_PREVIEW_THUMBNAILS_NAME" -path_prefix "$DESTINATION_PREVIEW_THUMBNAILS_NAME"

			stream_descriptors=()
			IFS=,

			if has_audio "$source_video"; then
				source_audio_dir="$source_renditions/audio"
				mkdir -p "$source_audio_dir"
				source_audio="$source_audio_dir/audio.m4a"

				destination_audio_dir="$destination_renditions/audio"

				if [[ ! -f "$source_audio" ]]; then
					ffmpeg -y -i "$source_video" \
						-map_metadata -1 \
						-vn -c:a aac -b:a "$ABR" \
						"$source_audio"
				fi

				stream_descriptor=(
					"in=$source_audio"
					"stream=audio"
					"segment_template=$destination_audio_dir/audio_segment_\$Number\$.m4s"
					"init_segment=$destination_audio_dir/audio_init.mp4"
					"playlist_name=$destination_audio_dir/audio.m3u8"
				)
				stream_descriptors+=("${stream_descriptor[*]}")
			fi

			source_height=$(get_height "$source_video")
			for rendition in "${RENDITIONS[@]}"; do
				IFS=: read -r name height vbr <<<"$rendition"

				source_rendition_dir="$source_renditions/$name"
				mkdir -p "$source_rendition_dir"
				source_rendition="$source_rendition_dir/video.mp4"

				destination_rendition_dir="$destination_renditions/$name"

				if [[ $height -gt $source_height ]]; then
					continue
				fi

				if [[ ! -f "$source_rendition" ]]; then
					ffmpeg -y -i "$source_video" \
						-map_metadata -1 \
						-vf "scale=-2:$height" \
						-c:v libx264 -b:v "$vbr" -an \
						-profile:v high -pix_fmt yuv420p \
						-r "$FPS" \
						-g "$GOP_SIZE" -keyint_min "$GOP_SIZE" -sc_threshold 0 \
						"$source_rendition"
				fi

				stream_descriptor=(
					"in=$source_rendition"
					"stream=video"
					"segment_template=$destination_rendition_dir/video_segment_\$Number\$.m4s"
					"init_segment=$destination_rendition_dir/video_init.mp4"
					"playlist_name=$destination_rendition_dir/video.m3u8"
					"iframe_playlist_name=$destination_rendition_dir/iframe.m3u8"
				)
				stream_descriptors+=("${stream_descriptor[*]}")
			done

			if [ "${#stream_descriptors[@]}" -eq 0 ]; then
				exit
			fi

			packager \
				"${stream_descriptors[@]}" \
				--segment_duration "$SEGMENT_DURATION" \
				--fragment_duration "$FRAGMENT_DURATION" \
				--generate_static_live_mpd \
				--hls_master_playlist_output "./$HLS_MASTER_NAME" \
				--mpd_output "./$DASH_MANIFEST_NAME"
		)
	done
}

get_height() {
	ffprobe -v quiet -select_streams v:0 \
		-show_entries stream=height \
		-of csv=p=0 "$1" 2>/dev/null
}

has_audio() {
	ffprobe -v quiet -select_streams a \
		-show_entries stream=index \
		-of csv=p=0 "$1" 2>/dev/null | grep -q .
}

main
