[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## build for .app

```
cd macOS-pkg
mkdir build
```

安装打包工具需要的依赖

```
pip3 install -r requirements.txt
```

修改脚本package.py里的app_path，将其修改为你自己的zip文件

执行打包

```
python3 package.py
```

## build for pkg
Generate macOS installers for your applications and products from one command.

For more detailed process please refer medium blog about the macOS installer builder: https://medium.com/swlh/the-easiest-way-to-build-macos-installer-for-your-application-34a11dd08744
<p align="center"> 
  <img src="https://cdn.dribbble.com/users/1161517/screenshots/7896076/apple-logo-animation.gif" width="600" height="450" />
</p>

Please suggest any modifications that will improve these implementations by reporting an issue. Happy to help you!

Cheers!! 🍺
