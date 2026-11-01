原型：https://github.com/jza10086/AuctionMaster

保留原型代码来源及 MIT 许可；此目录为 API 4 多人适配，不依赖 tmp。

当前使用 `assets/items/realistic/` 下 100 张原创写实 PNG，由内置 imagegen 生成，全部采用透明背景、不带外部投影。Pillow 按用户授权清理低透明度边缘、透明像素的隐藏 RGB，裁剪、缩放并补透明留白。逐张生成提示词及原始生成文件名见同目录 `generation_prompts.json`；实际透明素材以该目录 PNG 为准。审阅表的棋盘底为 HTML 展示背景，不包含在素材中。

视觉方向参考《竞拍之王》《三角洲行动》《逃离塔科夫》的写实物资呈现；小体积高价值宝石采用原创名称、图像及数值，没有下载或复制参考游戏的图片、商标、字体。原有 40 张程序绘制 SVG 仍留在 `assets/items/`，不再被运行时引用。

玩法参考：https://store.steampowered.com/app/4128580/?l=schinese （《BidKing：竞拍之王》官方页面，暗标竞拍与藏品估值方向）。本包物资、数值、同仓 tag 羁绊独立设计，不声称复现参考游戏的数值或羁绊规则。
