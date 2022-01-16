# oh-my-mrdoc

mrdoc 一键部署脚本

本项目是支持 [州的先生-mrdoc项目-GitHub](https://github.com/zmister2016/MrDoc) - [州的先生-mrdoc项目-Gitee](https://gitee.com/zmister/MrDoc) 在Linux下的一键部署脚本。

- 使用 uwsgi 方式部署；
- 使用 systemctl 进行进程守护；
- 支持 MrDoc 开源版、专业版；

平台测试情况：

- [x] CentOS 8.5.2111-x86_64（开源版测试通过）
- [x] CentOS 7-x68_64（开源版测试通过）
- [x] Debian 8.11.1-i386（不通过，源自带的Python3版本为3.4，不满足MrDoc版本要求，可自行安装Python3.6+）
- [x] Debian 9.13.0-i386（不通过，源自带的Python3版本为3.5，部分依赖库版本不支持3.5，可自行安装Python3.6+）
- [x] Debian 10.11.0-i386（开源版测试通过）
- [x] Debian 11.2.0-i386（开源版测试通过）

# 使用教程

在终端中运行以下命令,可重复执行.


```bash
### github 链接(二选一)
git clone https://github.com/Jonnyan404/oh-my-mrdoc.git

### gitee 链接(二选一)
git clone https://gitee.com/jonnyan404/oh-my-mrdoc.git
---开源版---
cd oh-my-mrdoc
export mrdocport=10086;bash mrdoc.sh -i
---专业版---
cd oh-my-mrdoc
export mrdocport=10085;bash mrdoc.sh -i https://test:123456@git.mrdoc.pro/MrDoc/MrDocPro.git
```

部署成功后，打开 `http://IP:10086` 即可访问，用户密码请查看脚本提示！**注意:自2021年9月7日去除nginx配置,但配置文件依然保留,供参考!**

# 管理mrdoc

- 方式一:

```
2022.1.14日,新版本把脚本写入到了环境变量里,可以在任意位置执行命令.
例如 `mrdoc -h` 即可看到方式二的效果(如果无效,请继续方式二.).依此类推,其它命令等效.
```

- 方式二:

```
root@raspberrypi:/opt/oh-my-mrdoc# bash mrdoc.sh -h
./mrdoc.sh [-h] [-i link] [-start pro] [-stop pro] [-status pro] [-restart pro] [-u pro] [-c] [--remove pro] [-v] [--initdb pro]
  -h, --help              Show help | 展示帮助选项
  -i, --install           To install mrdoc | 安装 mrdoc
  -start, --start         Start mrdoc | 启动 mrdoc
  -stop, --stop           Stop mrdoc | 停止 mrdoc
  -status, --status       mrdoc status | 查看 mrdoc 当前运行状态
  -restart, --restart     Restart mrdoc | 重启 mrdoc
  -u, --update            Update mrdoc version | 更新 mrdoc 源码
      --remove            Remove installed mrdoc | 卸载 mrdoc
  -c, --check             Check for update | 检查mrdoc安装脚本是否可更新
  -v, --version           Look script version | 查看脚本版本号
      --changepwd         Changepassword | 修改用户密码
      --createsu          Createsuperuser | 创建新的管理员用户
      --initdb            Initialize database | 初始化数据库,更换数据库时需要执行.
```

# FAQ

有任何问题,请反馈到 issue 里!

- gitee issue:<https://gitee.com/jonnyan404/oh-my-mrdoc/issues>
- github issue:<https://github.com/Jonnyan404/oh-my-mrdoc/issues>
- QQ群：`735507293`
- 电报群：<https://t.me/mrdocfun>

# TODO

- [x] 增加脚本 ·安装/更新/卸载· 功能
- [ ] 增加脚本在线自更新
- [x] 增加脚本管理（启动/停止/重启） mrdoc

# 更新日志
2022年1月14日 18:18  增加查看服务运行状态+初始化数据库选项

2021年11月01日 13:00 增加修改密码+创建管理员用户选项

2021年10月20日 18:00 重构脚本,增加功能

2021年5月20日 22:00:00 优化安装提示

2021年4月16日 21:11:40 首次更新!
