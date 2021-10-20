# oh-my-mrdoc

mrdoc 一键部署脚本

本项目是支持 [州的先生-mrdoc项目-GitHub](https://github.com/zmister2016/MrDoc) - [州的先生-mrdoc项目-Gitee](https://gitee.com/zmister/MrDoc) 在Linux下的一键部署脚本。

- [x] 采用 uwsgi 方式部署
- [x]  centos7.x / debian 10(树莓派3B) 测试通过
- [x] Ubuntu 系列测试通过

# 使用教程

在终端中运行以下命令,可重复执行.


```bash
### github 链接(二选一)
git clone https://github.com/Jonnyan404/oh-my-mrdoc.git

### gitee 链接(二选一)
git clone https://gitee.com/jonnyan404/oh-my-mrdoc.git
---
cd oh-my-mrdoc
bash mrdoc.sh -i
```

部署成功后，打开 `http://IP:10086` 即可访问，用户密码请查看脚本提示！**注意:自2021年9月7日去除nginx配置,但配置文件依然保留,供参考!**

# 管理mrdoc

```
root@raspberrypi:/opt/oh-my-mrdoc# bash mrdoc.sh -h
./mrdoc.sh [-h] [-i] [-start] [-stop] [-restart] [-u] [-c] [--remove] [-v]
  -h, --help              Show help | 展示帮助选项
  -i, --install           To install mrdoc | 安装 mrdoc
  -start, --start         Start mrdoc | 启动 mrdoc
  -stop, --stop           Stop mrdoc | 停止 mrdoc
  -restart, --restart     Restart mrdoc | 重启 mrdoc
  -u, --update            Update mrdoc version | 更新 mrdoc 源码
      --remove            Remove installed mrdoc | 卸载 mrdoc
  -c, --check             Check for update | 检查mrdoc安装脚本是否可更新
  -v, --version           Look script version | 查看脚本版本号
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
2021年10月20日 18:00 重构脚本,增加功能.

2021年5月20日 22:00:00 优化安装提示

2021年4月16日 21:11:40 首次更新!
