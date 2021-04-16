# oh-my-mrdoc

mrdoc 一键部署脚本,目前功能还不是很完善,待后续更新!

- [x] 采用 `uwsgi/nginx` 方式部署
- [x] centos7.x 测试通过
- [ ] Ubuntu待测试

# 使用教程

在终端中运行以下命令 **(二选一)** 即可,可重复执行.

默认 nginx 端口为 10086,可先执行 `export port=xxx` 来自定义端口,或者后续自行更改 `/etc/nginx/conf.d/mrdoc_nginx.conf` 文件.

```bash
# github 链接
curl https://raw.githubusercontent.com/Jonnyan404/oh-my-mrdoc/main/mrdoc-install.sh | bash

# gitee 链接
curl https://gitee.com/jonnyan404/oh-my-mrdoc/raw/main/mrdoc-install.sh | bash
```


# FAQ

有问题,请反馈到 issue 里!



## 更新日志

- 2021年4月16日 21:11:40 首次更新!
