# 长句组块贪吃蛇 · Grammar Snake

把长句按**语法成分**切成词块,贪吃蛇按句子顺序吃块的语言学习小游戏。
首批数据为托福衔接班语法长句(10 句),任何学科都能换:`data/sentences.json` 换数据即玩。

Godot 4.7 · GDScript · 无第三方资源(美术为代码绘制的玩具糖果风,音效为程序生成)

## 玩法

- **四屏流程**:菜单选句 → 准备屏记词块顺序 → 游戏屏吃块 → 语法树看结构
- 蛇吃到**正确的下一个词块**:身体长一节(该节标注词块)、加分、提速、水波纹 + `Great!` 弹字与音效
- 吃到**错误词块**:
  - 练习模式 → 警告弹字,蛇短暂停顿
  - 挑战模式 → 扣一条命(共 3 条),命尽游戏结束
- 撞墙 / 咬到自己 → 结束,按错误数与用时评 1–3 星
- 每句结束可进**语法树**屏,按 `attach` 修饰关系展示成分结构

## 操作

| 平台 | 操作 |
|---|---|
| 桌面 | 方向键 / WASD 移动,`P` 或 `Esc` 暂停 |
| 手机竖屏 | 在棋盘上**滑动**转向 |

## 运行

需要 [Godot 4.7+](https://godotengine.org/download)(开源引擎,免安装单文件)。

```bash
# 方式一:有 godot 命令
./run.sh

# 方式二:指定引擎路径
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 ./run.sh
```

首次运行会自动 `--import` 生成 `.godot/` 缓存。

## 自动化验收(双分辨率断言 + 截图)

```bash
godot --path . res://tests/autotest.tscn -- --out=tests/shots
# 断言:10 句数据、场景加载、计数倒数、吃块成长/计分/通关、
#       挑战模式扣命、桌面 1440×900 与手机竖屏 390×844 截图
# 退出码 0 = 全部通过
```

实测结果见 `docs/screenshots/`(由 autotest 生成)。

## 测试钩子(给 AI/自动化验收用)

`game.gd` 暴露:`hook_start()` / `hook_set_dir(dir)` / `hook_eat_next()` / `hook_wrong()` / `hook_stats()`。
注意:测试时要给蛇下转向指令,否则 idle 的蛇会自己撞墙造成假失败。

## 数据格式

`data/sentences.json`:每句 `{ls, en, zh, chunks:[{en, zh, role, attach}]}`。

- `role`: `S` 主语 / `V` 谓语 / `O` 宾语 / `Attr` 定语 / `Adv` 状语 / `Clause` 从句
- `attach`: 该块修饰的块下标(-1 为句子根),支持嵌套从句
- 分块原则:**按修饰关系切意义块**,不按词数均切

## 目录

```
project.godot          Godot 4.7 工程配置(autoload: GameData / Sfx)
data/sentences.json    10 句语法长句 + 语法成分切块
scenes/                四屏场景(代码构建 UI)
scripts/scenes/        各屏逻辑;game.gd 含全部玩法与测试钩子
scripts/ui_kit.gd      糖果风 UI 控件库(CJK 字体走系统字体)
scripts/autoload/      GameData(数据) / Sfx(程序生成音效)
scripts/tests/         autotest.gd 自动验收
run.sh                 双击即玩启动器
```

## 关于美术管线

设计稿的「Blender 烘焙 → Godot 2.5D 贴图合成」管线需要 Blender;本仓库先用代码绘制
的软糖风几何体 + 柔光渐变达成交付,`scripts/scenes/game.gd` 的 `_draw_*` 函数即渲染层,
将来接入烘焙 PNG 时只需替换绘制实现,玩法逻辑不动。
