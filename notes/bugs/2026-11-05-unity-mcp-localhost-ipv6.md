---
id: 2026-11-05-unity-mcp-localhost-ipv6
title: Unity MCP 显示在线但客户端连接被拒：检查 IPv4 与 IPv6 回环地址
category: bugs
status: draft
tags: [unity, mcp, windows, ipv6, connection]
created: '2026-11-05'
updated: '2026-11-05'
author: Adinto
unity_version: '2022.3.62f3'
related: []
source:
  - title: MCP Unity 1.4.0 网桥监听实现
    url: https://github.com/CoderGamester/mcp-unity/blob/1.4.0/Editor/UnityBridge/McpUnityServer.cs
    accessed: '2026-11-05'
  - title: dsh-unity-mcp 使用说明
    url: https://github.com/thyeff/dsh-unity-mcp
    accessed: '2026-11-05'
---

## Summary

在本次 Windows 11、Unity 2022.3.62f3 与 MCP Unity 1.4.0 环境中，网桥显示在线，但连接 `127.0.0.1:8090` 被拒。
实际监听地址为 IPv6 回环地址 `::1`；将客户端 `UNITY_HOST` 改为 `localhost` 后连接成功。
适用于端口正确、服务在线但 IPv4 连接失败的排查，不代表所有 Windows 环境都会出现。

## 现象

Unity 的 Server Window 显示 Server Online，但客户端访问 `127.0.0.1:8090` 返回 `ECONNREFUSED`。

## 原因

网桥在禁用远程连接时以 `localhost` 创建监听器。本机实际只监听 `::1:8090`；客户端强制使用 IPv4 地址 `127.0.0.1`，与监听地址不匹配。

## 解决

1. 执行 `Get-NetTCPConnection -LocalPort 8090 -State Listen`，确认实际监听地址。
2. 本次将 MCP 客户端的 `UNITY_HOST` 从 `127.0.0.1` 改为 `localhost`，重新启动 MCP 客户端。
3. 调用 `get_scenes_hierarchy`，能读到真实场景后，再创建物体并保存场景验证写入。本次这两项均通过。

## AI Prompt

> Unity MCP 显示 Server Online，但客户端返回 ECONNREFUSED。请先确认编辑器已加载网桥、端口一致，并比较 localhost、127.0.0.1、::1 的连接结果。如果网桥仅监听 IPv6 回环地址，不要把客户端强制指向 IPv4。调整客户端地址后，先读取真实场景层级，再在独立测试项目中验证创建物体与保存。若是双栈监听或其他地址，请依据实际结果继续排查。
