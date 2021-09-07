# oh-my-mrdoc

mrdoc 一键部署脚本

本项目是支持 [州的先生-mrdoc项目-GitHub](https://github.com/zmister2016/MrDoc) - [州的先生-mrdoc项目-Gitee](https://gitee.com/zmister/MrDoc) 在Linux下的一键部署脚本。

- [x] 采用 uwsgi 方式部署
- [x]  centos7.x / debian 10(树莓派3B) 测试通过
- [ ] Ubuntu 系列待测试

# 使用教程

> 使用前需知：由于目前脚本部署还处于早期阶段，为保证成功率，请尽量使用新机器！！！
> 当然部署了其它服务的机器也可以，需要注意端口占用问题！

在终端中运行以下命令 (二选一) 即可,可重复执行.


```bash
### github 链接
curl https://raw.githubusercontent.com/Jonnyan404/oh-my-mrdoc/main/mrdoc-install.sh | bash

### gitee 链接
curl https://gitee.com/jonnyan404/oh-my-mrdoc/raw/main/mrdoc-install.sh | bash
```

部署成功后，打开 `http://IP:10086` 即可访问，用户密码请查看脚本提示！**注意:自2021年9月7日去除nginx配置,但配置文件依然保留,供参考!**

# 管理mrdoc

```
# 启动mrdoc
systemctl start mrdoc
# 停止mrdoc
systemctl stop mrdoc
# 重启mrdoc
systemctl restart mrdoc
```

# FAQ

有任何问题,请反馈到 issue 里!

- gitee issue:<https://gitee.com/jonnyan404/oh-my-mrdoc/issues>
- github issue:<https://github.com/Jonnyan404/oh-my-mrdoc/issues>
- QQ群：`735507293`
- 电报群：<https://t.me/mrdocfun>

# TODO

- [ ] 增加脚本 ·安装/更新/卸载· 功能
- [ ] 增加脚本在线自更新
- [ ] 增加脚本管理（启动/停止/重启） mrdoc

# 更新日志

2021年5月20日 22:00:00 优化安装提示

2021年4月16日 21:11:40 首次更新!
