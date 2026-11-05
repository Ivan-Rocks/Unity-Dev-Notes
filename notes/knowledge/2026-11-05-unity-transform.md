---
id: 2026-11-05-unity-transform
title: Unity 中设置物体的 Transform
category: knowledge
status: formalized
tags: [transform, position, rotation, scale]
created: 2026-11-05
updated: 2026-11-05
author: DSH
unity_version: "6000.3"
related: []
source: []
---

## Summary

Transform 是每个 GameObject 必带的组件，决定它在场景中的位置（position）、旋转（rotation）和缩放（scale）。在 Inspector 里直接改数值即可；代码里用 transform.position / rotation / localScale；注意区分世界坐标（position）和本地坐标（localPosition）。

## 正文

### 三个属性

- `position` / `rotation` / `scale` —— 世界空间
- `localPosition` / `localRotation` / `localScale` —— 相对父物体的本地空间
- 无父物体时，本地 = 世界

### Inspector 里设置

1. 选中物体 → Inspector 面板顶部就是 Transform
2. 直接输入数值；或用坐标轴手柄拖动（移动 W / 旋转 E / 缩放 R）

### 代码里设置

```csharp
transform.position = new Vector3(1, 2, 3);         // 世界位置
transform.localPosition = new Vector3(0, 1, 0);    // 相对父物体
transform.rotation = Quaternion.Euler(0, 90, 0);   // 绕 Y 轴转 90 度
transform.localScale = new Vector3(2, 2, 2);       // 放大一倍
```

## AI Prompt

- 生成指令：「写一段 Unity C#，把物体放到世界坐标 (5,0,5)，绕 Y 轴转 45 度，并说明 transform.position 和 localPosition 的区别。」
- 补充：旋转用 Quaternion（四元数）赋值，欧拉角用 Quaternion.Euler 转换，不要直接给 rotation 赋欧拉角数值。
- 注意：UI 的 RectTransform 继承自 Transform，但要用 anchoredPosition / sizeDelta，不要用 position。
