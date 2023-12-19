# ShiroDEB

ShiroDEB是一系列用来打包Deb包的脚本组合，主要用来构建符合UOS规范的deb软件包。

本项目依赖新版的`bash`（以UOS v20自带的版本为基准），并不兼容 POSIX 标准`sh`

[![asciicast](https://asciinema.org/a/0BKyGaKRv97FZQS2qMKTtxQAC.svg)](https://asciinema.org/a/0BKyGaKRv97FZQS2qMKTtxQAC)

---

## 依赖

* bash, sed, dh-make, jq: 必要依赖
* imagemagick: 用于处理图标
* inkscape: 用于处理svg图标
* unsquashfs: 用于解包`.snap`格式的软件包，不需要安装（snap支持尚不完备）
* unar：用于解包一般格式的压缩包，例如`.tar.*`或`.zip`等。

## 可用指令

在使用ShiroDEB之前请将项目目录下的bin文件夹加入到你的PATH环境变量中以使用`shirodeb`指令。当然你也可以直接使用路径调用`shirodeb.sh`，两种方法没有功能上的区别。

约定俗成的说明：使用方括号`[]`包裹的参数代表可选参数，使用尖括号`<>`包裹的参数代表必选参数

* ### `shirodeb start [template]`

  创建一个新打包工程，如果template参数给出，则从项目的`templates/boilerplates`文件夹中拷贝响应的模板文件。

  目前可用的模板：`appimage`、`deb`、`raw`

* ### `shirodeb make [--stage1 | --stage2] [--no-build]`

  构建软件包。
  如果使用`--stage1`，则脚本构建完文件结构后就会结束，并不会调用dh_make构建deb包。
  如果使用`--stage2`，则脚本不会修改文件结构，直接将现有的文件打包成deb包。
  `--stage1`和`--stage2`提供了一种十分灵活的控制方式，尤其是你希望手动调整包内容的时候，虽然不是很建议，因为这样违背了脚本设计的初衷。**花一小时自动化一个一分钟的流程是程序员的浪漫**
  如果使用`--no-build`，则脚本不会执行`build.sh`中的`build`函数。

* ### `shirodeb download`

  仅下载构建所需的文件。

* ### `shirodeb purge`

  清除下载的文件，同时清理缓存的下载内容。

* ### `shirodeb clean`

  删除项目文件夹下的`src`, `pkg`, `downloads`和`output`文件夹，保持项目文件夹整洁。（这四个文件夹也是不纳入版本管理系统的文件夹）

* ### `shirodeb save`

  保存构建好的deb文件和一些相关信息到`DEB_UPLOAD_PATH`文件夹。会将软件包的图标单独提取保存，同时生成一个`info.txt`包含一些软件包信息。`info.txt`用于使用MUSE插件在UOS上传后台中自动填写部分信息（而不用手动复制，当然不使用MUSE插件的话也可以手动复制info.txt中的内容啦）

* ### `shirodeb install`

  安装构建好的软件包。运行此命令前须保证软件包已经被构建。

* ### `shirodeb remove`

  卸载被安装的软件包（通过包名卸载）

* ### `shirodeb dir [src|pkg|download|output]`

  在标准输出中输出文件夹绝对路径，一般这么用：`cd $(shirodeb dir)`。

## build.sh 文件

`build.sh` 对于ShiroDEB来说是最重要的文件，称之为“Recipe（菜谱）”

ShiroDEB通过`source`引用`build.sh`来获取里面的必要信息，以及对于不同软件包也有的`build`函数（当然对于一些流程大同小异的软件包，可以共享`build`函数，即上文提到的模板。）。在构建过程中，ShiroDEB会通过执行`build.sh`来构建软件包需要的文件结构。

最简单的`build`函数就是直接从上游发布的二进制包中复制文件出来，或者更进一步，使用`cmake`、`make`等构建系统从源码构建程序。

目前ShiroDEB已经全面支持第三方自建库，从而摆脱UOS V20系统库版本过低的桎梏。关于这方面的细节会在其他文档说明。你也可以关注[ingredients仓库](https://github.com/shirodeb/ingredients)来获取更多信息。

### `function build` 函数说明

以下是一些在`build`函数内推荐使用的变量：

|变量名|描述|
|-|-|
| SRC_DIR | 源代码文件夹，通过URL自动下载的文件会自动解压到此目录(若不支持或关闭了自动解压则会链接至此目录) |
| PKG_DIR | 打包文件夹, 包含会被打包成deb的文件。（例如`opt/`或者`debian/`） |
| APP_DIR | 软件文件夹，为`$PKG_DIR/opt/apps/$PACKAGE`，包含软件文件的文件夹（`files/`、`entries`和`info`，详情参见[UOS打包规范](https://doc.chinauos.com/content/M7kCi3QB_uwzIp6HyF5J)）。|
| ROOT_DIR | `build.sh`所在的文件夹，主要用来拷贝一些特定的模板文件。 |
| SRC_NAMES | 自动解压后的路径名，顺序与`URL`中出现的顺序相同。若文件类型尚不支持自动解压后的路径名获取，则为空。（建议用于`.deb`和`.AppImage`两种文件） |

还有一些比较实用的函数于`utils.sh`中提供，可以阅读函数自带的注释了解使用方法。相关文档可能在后期完善。

<!-- 除此之外，脚本可能还有一些比较有用的内部变量，说不定之后会出文档，我会尽快:tm:完善。 -->

### `function prepare` 函数说明

`prepare` 函数用来完成元信息（下载地址、描述、版本号甚至包名等）的自动获取（`INGREDIENTS`变量不能在此处重新赋值，但应该可以通过调用`ingredients.add xxx`来追加（不太确定））

对于不支持的源码获取方式（例如通过`git`等版本控制系统拉取源码等）也可以在此处完成，例：
```bash
function prepare() {
    if [[ "$1" != "download" && "$1" != "make" ]]; then
        return 0
    fi
    local giturl="https://github.com/siyuan-note/siyuan"
    mkdir -p "$ROOT_DIR/src"
    pushd "$ROOT_DIR/src"
    if [[ -d "$PACKAGE-$VERSION/.git" ]]; then
        if [[ $(git -C "$PACKAGE-$VERSION" describe --tags) != "v$VERSION" ]]; then
            log.info "delete old checkout"
            rm -rf "$PACKAGE-$VERSION"
            git clone --depth 1 --recursive --branch "v$VERSION" "$giturl" "$PACKAGE-$VERSION"
        else
            log.info "already checkout the tagged version"
        fi
    else
        git clone --depth 1 --recursive --branch "v$VERSION" "$giturl" "$PACKAGE-$VERSION"
    fi
    popd
}
```

## 环境变量

一些环境变量会影响脚本行为，这些环境变量可以通过任何你想的方式配置。通常，通过如下三种方式配置环境变量是推荐的：

1. 直接修改`~/.bashrc`、`~/.profile`等全局启动脚本来修改环境变量。
2. 通过拷贝项目文件夹的`profile.example`到`profile`后，在其中修改环境变量。脚本在每次执行的时候都会自动包含`profile`中的内容。
3. 在`build.sh`中修改环境变量。

通过方法1和方法2修改的环境变量是全局的，而通过方法3修改的环境变量则只针对特定的打包项目有效。

### 环境变量表

|变量名|描述|推荐作用域|
|-|-|-|
|LOCAL_DOWNLOAD_DIR|下载缓存文件夹（为空则不使用缓存）||
|DEB_UPLOAD_PATH|保存文件夹，使用`shirodeb save`时会向其中拷贝相关文件||
|DEBFULLNAME|打包者全名||
|DEBEMAIL|打包者邮箱||
|PREFERRED_DOWNLOADER|`aria2`或`curl`，指定下载`URL`的方式||
|INGREDIENTS_DIR|Ingredients文件夹，请参考[此仓库](https://github.com/shirodeb/ingredients)||
|DO_NOT_UNARCHIVE|若非空，则不会自动解压下载的文件。|`build.sh`|

环境变量仅能在其推荐的作用域中指派，在其他作用域指派环境变量*可能*会导致构建脚本功能失常

## 可用模板

通过模板构建可以批量重新打包较为一致的二进制软件包，例如AppImage。也可以减少部分通用流程的重复劳动。

* deb
  * 重新打包适用于Debian、Ubuntu等的deb二进制包。会自动从其中继承control文件的内容。需要手动指定EXEC_PATH，或可选地调整文件结构。可以使用`shirodeb make check`快速查看deb文件的内容。

* appimage
  * 重新打包AppImage应用，需要手动填写元信息。可以使用`shirodeb make test`来测试AppImage是否可以在系统上运行。

* raw
  * 空白模板，一生万物。

## Docker

目前ShiroDEB可以通过Docker进行软件包的构建。通过`docker pull shiroko/shirodeb`拉取最新版的ShiroDEB镜像，然后通过如下命令进行构建（请根据实际情况对绑定和环境变量进行修改）：

```bash
docker run \
  -e DEBFULLNAME="shiroko" \
  -e DEBEMAIL="hhx.xxm@gmail.com" \
  -v $(pwd)/artifacts:/artifacts \
  -v $(pwd)/downloads:/downloads \
  -v $(pwd)/org.wireshark:/recipe \
  shiroko/shirodeb
```

当前本Docker镜像的基础系统为UOS V20 Eagle，但之后可能会逐渐转移到deepin V23 Beige。