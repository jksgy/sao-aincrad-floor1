# NOTICE — 版权与素材说明

## 同人性质

本项目是基于《Sword Art Online》（ソードアート・オンライン）艾恩葛朗特篇的**非商业同人作品**，用于个人学习与 Godot 技术实践。
《Sword Art Online》原作、角色（桐人、亚丝娜、克莱因等）与世界观版权归 **川原砾 / abec / KADOKAWA / Aniplex** 所有。
本项目与版权方无任何关联，不使用原作的美术、音频或文本资源。

若版权方有异议，请联系删除。

## 代码许可

除下述第三方资源外，本仓库的 GDScript 代码、场景、数据文件与生成脚本以 **MIT License** 授权（见 `LICENSE`）。

## 第三方资源

| 资源 | 许可 | 来源 |
|------|------|------|
| Godot Engine 4.4.1 | MIT | https://godotengine.org |
| Noto Sans SC 字体 | SIL Open Font License 1.1 | https://fonts.google.com/noto/specimen/Noto+Sans+SC |

## 本项目自行生成的内容

- `project/assets/tiles|chars|enem|objs|fx|ui/*.png`：由 `tools/gen_art.py` 使用 Pillow 程序化绘制。
- `project/assets/audio/*.wav`：由 `tools/gen_audio.py` 程序化合成（芯片音风格）。
- `project/data/maps/*.txt`：由 `tools/gen_maps.py` 手工布局 + 脚本导出，并以 `tools/check_maps.py` 验证连通性。
- 其余场景、脚本、JSON 数据：手写。

## 存档与用户数据

游戏运行时不收集、不上传任何数据。存档仅写入本机 `%APPDATA%\AincradProto\`。
