# ShiroDEB

ShiroDEB is a handy script-set for quickly packaging software into deb package in UOS specification.

This script-set is depends on `bash` and not compatible with old-style `sh`

[![asciicast](https://asciinema.org/a/yAoIWlQgPCRZ9KGVerzA9ai2w.svg)](https://asciinema.org/a/yAoIWlQgPCRZ9KGVerzA9ai2w)

---

## Depends

* bash, sed
* imagemagick: for general image operations
* inkscape: for converting svg icon to png
* unsquashfs: for unarchiving .snap files
* unar: for generic unarchiving .tar.* or .zip files

## Command

`shirodeb start [template]`

Start a new packaging project. If `template` is provided, shirodeb will copy it from `templates` folder.

`shirodeb make [--stage1 | --stage2] [--no-build]`

Build the package.

If `--stage1` is used, script will only build file-structure and not package into `.deb` file.

If `--stage2` is used, script will only package into `.deb` files without altering file-structure and content.

`--stage1` or `--stage2` is useful when you want to manually tune the contents of package.

If `--no-build` is used, script will not execute `function build` inside `build.sh`


`shirodeb download`

Download source file only.

`shirodeb purge`

Clean downloaded files and caches if existed.

`shirodeb clean`

Remove `src`, `pkg`, `downloads` and `output`. Make recipe folder clean.

`shirodeb save`

Save build artifacts and some information to `DEB_UPLOAD_PATH`, used for uploading software in UOS Developer Center. (This will save a `info.txt` which is used by MUSE user-script.)

`shirodeb install`

Install packaged software for test.

`shirodeb remove`

Remove installed package by AppID.

`shirodeb dir [src|pkg|download|output]`

Echo the folder path. Used with `cd $(shirodeb dir)`.

## build.sh

`build.sh` is the most important file for ShiroDEB which I call it a "recipe".

ShiroDEB source the `build.sh` for some necessary values and `function build` for building the file structure.

You could just repacking a existing binary package via `cp`, or using other build tools to make from source code. **I will generalize and support self-built shard libraries later.** That will be a key feature for ShiroDEB and make my work more easy to go.

There are some useful variable could be used inside `function build`:

|Variable|Description|
|--------|-----------|
| SRC_DIR | Source file dir, containing unarchived files downloaded from URL |
| PKG_DIR | Package dir, the destination of the root content of package (opt/ and debian/ inside) |
| APP_DIR | Application dir inside opt/apps/PACKAGE/ (files/ and entries/ inside) |
| ROOT_DIR | Dir containing `build.sh`, used for copying some package specified template file` |

And also some neat functions provided utils.sh you could read that file to check the usage.

Besides, some internal variables is treated as a necessary part of the recipes and be considered as exported API. These variables will be documented soon :tm:

## Environment variables

You could use global environment variables if you prefer. But if you don't want to populate your global environment. You could use a `profile` file inside the root of this project.

You could start with `profile.example`. All the needed environment variables is presenting there.

## Available Templates

* deb
  * Template for repacking an existing .deb package.

* appimage
  * Template for appimage.

* raw
  * Nothing but a boilerplates for anything.
