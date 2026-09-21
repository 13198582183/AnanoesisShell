# Harness — 约束系统

> 通过 Guides（前馈控制）与 Sensors（反馈控制）约束 AI 代理行为，是 SDD 的落地门禁层。

## 结构

    .harness/
    ├── README.md               # 本文件
    ├── guides/                 # 前馈控制：代理行动前注入约束
    │   ├── workflow.md         # 开发工作流 Explore→Plan→Implement→Verify→Complete
    │   └── coding-standards.md # 编码与注释规范
    └── sensors/                # 反馈控制：代理行动后校验
        ├── quality.md          # 质量门禁检查点
        └── drift-detection.md  # Spec 漂移检测

## Guides（前馈控制）
在代理开始任务**前**注入上下文与约束，防止偏差发生。

## Sensors（反馈控制）
在代理完成行动**后**检查输出，检测并纠正偏差；未通过门禁禁止合并 / 归档。

## 使用方式
`AGENTS.md` / `CLAUDE.md` 引用本目录：遵循 `guides/`，对照 `sensors/` 校验。
