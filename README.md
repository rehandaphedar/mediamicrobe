# Introduction

A minimalist video sharing platform, inspired by PeerTube and sourcehut.

It is written to work with Hugo, but can be adapted for other SSGs or even as a website-less/cli video sharing platform.

# Installation

Ensure that the following dependencies are installed and in `$PATH`:
- ffmpeg
- [Shaka Packager](https://github.com/shaka-project/shaka-packager)
- [frametome](https://sr.ht/~rehandaphedar/frametome)

Then, copy `main.sh` to any directory in `$PATH` as `mediamicrobe` and mark it as executable.

# Demo

A demo can be seen at the [mediamicrobe-demo](https://sr.ht/~rehandaphedar/mediamicrobe-demo) repository.

# Expected Directory Structure

In the root of your site, a directory `videos` must be present.

Each video resides in a subdirectory.

The slug for a video is derived from the subdirectory name. Therefore, the subdirectory name must include only (alphanumeric + dash).

Each video should have the following files:
- `video.mp4`: The video file. It will be transcoded and packaged by the program.
- `thumbnail.webp`: The thumbnail for the video.
- `_index.md`: The page for the video. It should be written in Hugo compatible markdown.
- `tracks/chapters.vtt`: The chapters track.
- `tracks/subtitles/[name].vtt`: The subtitles track. You can include multiple editions (eg. languages).

# Usage

Now, run the program:
```sh
mediamicrobe
```

It will iterate over all the videos and perform the following actions:
- Copies `_index.md` into `content/videos/[slug]`.
- Copies `thumbnail.webp` and `tracks` into `static/videos/[slug]`.
- Generates files required for timeline preview under `tracks/thumbnails`: `index.vtt` and `sprites_{hash}_{index}.webp`.
- Transcodes `video.mp4` into `videos/[slug]/renditions`.
- Packages the renditions into `video.mp4` into `static/videos/[slug]/renditions`.

# Integrating A Video Player

This example uses [VidStack](https://vidstack.io).

It works by creating a `player` shortcode, which will be used in the video's page.

## Importing VidStack

Import VidStack by including this snippet the `<head>` of `layouts/baseof.html`:
```html
{{ if .Page.HasShortcode "player" }}
	<link
		rel="stylesheet"
		href="https://cdn.vidstack.io/player/theme.css"
	/>
	<link
		rel="stylesheet"
		href="https://cdn.vidstack.io/player/video.css"
	/>
	<script type="module" src="https://cdn.vidstack.io/player"></script>
{{ end }}
```

## The Player Shortcde

Save this as `layouts/shortcodes/player.html`:
```html
{{ $slug := .Get "slug" | default (.Page.File.Dir | path.Base) }}

{{ $hlsPath := printf "/videos/%s/master.m3u8" $slug }}
{{ $dashPath := printf "/videos/%s/manifest.mpd" $slug }}
{{ $thumbnailPath := printf "/videos/%s/thumbnail.webp" $slug }}
{{ $chaptersPath := printf "/videos/%s/tracks/chapters.vtt" $slug }}

{{ $subtitlesDir := printf "static/videos/%s/tracks/subtitles" $slug }}
{{ $subtitlesBasePath := printf "/videos/%s/tracks/subtitles" $slug }}

{{ $thumbnailsPath := printf "/videos/%s/tracks/thumbnails/index.vtt" $slug }}


<div style="display: flex; justify-content: center">
	<media-player
		src="{{ $hlsPath }}"
		playsinline
		style="aspect-ratio: auto;"
	>
		<media-provider>
			<media-poster
				class="vds-poster"
				src="{{ $thumbnailPath }}"
				></media-poster>
			<track
				src="{{ $chaptersPath }}"
				kind="chapters"
				label="Chapters"
				lang="en-US"
				default
			/>

			{{ range readDir $subtitlesDir }}
				{{ $language := path.BaseName .Name }}
				<track
					src="{{ $subtitlesBasePath }}/{{ .Name }}"
					kind="subtitles"
					lang="{{ $language }}"
				/>
			{{ end }}
		</media-provider>
		<media-video-layout
			thumbnails="{{ $thumbnailsPath }}"
		>
		</media-video-layout>
	</media-player>
</div>
<ul>
	Links:
	<li>
		<a href="{{ $hlsPath }}">HLS</a>
	</li>
	<li>
		<a href="{{ $dashPath }}">DASH</a>
	</li>
</ul>
```

Then, in the video page, include the shortcode:
```md
---
title: " Favorite Linux Commands: ls | RHEL Shorts "
---

In this bite-sized tech tutorial, we're putting the spotlight on the 'ls' command in Red Hat Enterprise Linux! Learn some key options of this essential tool for listing files and directories, all in under a minute.

{{< player >}}

Elevate your command line game and explore the power of 'ls' on RHEL with our latest YouTube Short!

Watch this other video as well:
{{< player slug="other-video-slug" >}}
```

This approach has two advantages:
1. You can put the player anywhere on the page as opposed to only at the top/bottom.
2. By default, the shortcode will play the video associated with the current page. But, you can pass a slug manually to make it play another video. This also means that you can embed any of your videos on any other page in your site!

## Pretty Names For Subtitle Tracks

To automatically set pretty language names, such as "English" for `en.vtt`, create a `params.languageNames` variable in `hugo.toml`. The given example includes all languages in [ISO 639](https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes):
```conf-toml
[params.languageNames]
  ab = "Abkhazian"
  aa = "Afar"
  af = "Afrikaans"
  ak = "Akan"
  sq = "Albanian"
  am = "Amharic"
  ar = "Arabic"
  an = "Aragonese"
  hy = "Armenian"
  as = "Assamese"
  av = "Avaric"
  ae = "Avestan"
  ay = "Aymara"
  az = "Azerbaijani"
  bm = "Bambara"
  ba = "Bashkir"
  eu = "Basque"
  be = "Belarusian"
  bn = "Bengali"
  bi = "Bislama"
  bs = "Bosnian"
  br = "Breton"
  bg = "Bulgarian"
  my = "Burmese"
  ca = "Catalan"
  km = "Central Khmer"
  ch = "Chamorro"
  ce = "Chechen"
  ny = "Chichewa"
  zh = "Chinese"
  cu = "Church Slavonic"
  cv = "Chuvash"
  kw = "Cornish"
  co = "Corsican"
  cr = "Cree"
  hr = "Croatian"
  cs = "Czech"
  da = "Danish"
  dv = "Divehi"
  nl = "Dutch"
  dz = "Dzongkha"
  en = "English"
  eo = "Esperanto"
  et = "Estonian"
  ee = "Ewe"
  fo = "Faroese"
  fj = "Fijian"
  fi = "Finnish"
  fr = "French"
  ff = "Fulah"
  gd = "Gaelic"
  gl = "Galician"
  lg = "Ganda"
  ka = "Georgian"
  de = "German"
  el = "Greek"
  gn = "Guarani"
  gu = "Gujarati"
  ht = "Haitian"
  ha = "Hausa"
  he = "Hebrew"
  hz = "Herero"
  hi = "Hindi"
  ho = "Hiri Motu"
  hu = "Hungarian"
  is = "Icelandic"
  io = "Ido"
  ig = "Igbo"
  id = "Indonesian"
  ia = "Interlingua (International Auxiliary Language Association)"
  ie = "Interlingue"
  iu = "Inuktitut"
  ik = "Inupiaq"
  ga = "Irish"
  it = "Italian"
  ja = "Japanese"
  jv = "Javanese"
  kl = "Kalaallisut"
  kn = "Kannada"
  kr = "Kanuri"
  ks = "Kashmiri"
  kk = "Kazakh"
  ki = "Kikuyu"
  rw = "Kinyarwanda"
  kv = "Komi"
  kg = "Kongo"
  ko = "Korean"
  kj = "Kuanyama"
  ku = "Kurdish"
  ky = "Kyrgyz"
  lo = "Lao"
  la = "Latin"
  lv = "Latvian"
  li = "Limburgan"
  ln = "Lingala"
  lt = "Lithuanian"
  lu = "Luba-Katanga"
  lb = "Luxembourgish"
  mk = "Macedonian"
  mg = "Malagasy"
  ms = "Malay"
  ml = "Malayalam"
  mt = "Maltese"
  gv = "Manx"
  mi = "Maori"
  mr = "Marathi"
  mh = "Marshallese"
  mn = "Mongolian"
  na = "Nauru"
  nv = "Navajo"
  ng = "Ndonga"
  ne = "Nepali"
  nd = "North Ndebele"
  se = "Northern Sami"
  no = "Norwegian"
  nb = "Norwegian Bokmål"
  nn = "Norwegian Nynorsk"
  oc = "Occitan"
  oj = "Ojibwa"
  or = "Oriya"
  om = "Oromo"
  os = "Ossetian"
  pi = "Pali"
  ps = "Pashto"
  fa = "Persian"
  pl = "Polish"
  pt = "Portuguese"
  pa = "Punjabi"
  qu = "Quechua"
  ro = "Romanian"
  rm = "Romansh"
  rn = "Rundi"
  ru = "Russian"
  sm = "Samoan"
  sg = "Sango"
  sa = "Sanskrit"
  sc = "Sardinian"
  sr = "Serbian"
  sn = "Shona"
  ii = "Sichuan Yi"
  sd = "Sindhi"
  si = "Sinhala"
  sk = "Slovak"
  sl = "Slovenian"
  so = "Somali"
  nr = "South Ndebele"
  st = "Southern Sotho"
  es = "Spanish"
  su = "Sundanese"
  sw = "Swahili"
  ss = "Swati"
  sv = "Swedish"
  tl = "Tagalog"
  ty = "Tahitian"
  tg = "Tajik"
  ta = "Tamil"
  tt = "Tatar"
  te = "Telugu"
  th = "Thai"
  bo = "Tibetan"
  ti = "Tigrinya"
  to = "Tonga (Tonga Islands)"
  ts = "Tsonga"
  tn = "Tswana"
  tr = "Turkish"
  tk = "Turkmen"
  tw = "Twi"
  ug = "Uighur"
  uk = "Ukrainian"
  ur = "Urdu"
  uz = "Uzbek"
  ve = "Venda"
  vi = "Vietnamese"
  vo = "Volapük"
  wa = "Walloon"
  cy = "Welsh"
  fy = "Western Frisian"
  wo = "Wolof"
  xh = "Xhosa"
  yi = "Yiddish"
  yo = "Yoruba"
  za = "Zhuang"
  zu = "Zulu"
```

Then modify the track creation snippet like so:
```html
{{ range readDir $subtitlesDir }}
	{{ $language := path.BaseName .Name }}
	{{ $label := index site.Params.languageNames $language | default $language }}
	<track
		src="{{ $subtitlesBasePath }}/{{ .Name }}"
		kind="subtitles"
		label="{{ $label }}"
		lang="{{ $language }}"
	/>
{{ end }}
```

Note that this approach can also be used for things other than language, such as "With sound effects" vs "Without sound effects" tracks, etc.
