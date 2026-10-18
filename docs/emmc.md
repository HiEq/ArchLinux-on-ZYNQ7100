# 板载 eMMC 调查

## 1. 硬件

| 项 | 内容 |
|---|---|
| 器件 | 三星 KLM8G1GETF-B041，153-ball，核心板 U20，已贴件 |
| 数据接口 | 8 位（DAT0~DAT7），实际只连接 DAT0~DAT3 |
| VCC | +3.3 V |
| VCCQ | +1.8 V，CMD/DAT 上拉电阻接 +1.8 V |
| TF 卡槽 | PS SD0，MIO40~45 |

Zynq PS 的 SD0/SD1 均为 4 位数据总线；eMMC 的 I/O 为 1.8 V，而 TF 卡槽所在
MIO bank 为 3.3 V。同一 bank 不能同时为两种电压，因此 eMMC 未接在 PS SD 控制器上，
信号经 `MMC_CCLK/CMD/DATA0~3` 网络引至 PL 侧。

## 2. 尝试：由设备树启用 SD1

原理图中 `PS0MIO45` 之后直接跳到 `PS0MIO52`，MIO46~51 未引至连接器，据此推测 eMMC 接
SD1（MIO46~51）。`ps7_init.c` 无 SDIO1 配置，但内核启用 `CONFIG_PINCTRL_ZYNQ`，
可由设备树完成 MIO 复用：

```dts
/* /axi/mmc@e0101000 */
status = "okay";
bus-width = <4>;
non-removable;
disable-wp;
no-1-8-v;
max-frequency = <50000000>;
pinctrl-names = "default";
pinctrl-0 = <&sdhci1_default>;

/* /axi/slcr@f8000000/pinctrl@700 */
sdhci1-default {
    mux  { groups = "sdio1_3_grp"; function = "sdio1"; };
    conf { groups = "sdio1_3_grp"; slew-rate = <0>; io-standard = <2>; };
};
```

## 3. 结果

```
mmc1: SDHCI controller on e0101000.mmc [e0101000.mmc] using ADMA
mmc1: Failed to initialize a non-removable card
```

控制器 probe 成功、MIO 复用生效，但总线上无设备响应。结合第 1 节的电压与位宽结论，
eMMC 不在 PS SD 控制器上。

内核未启用 `CONFIG_DEBUG_FS`，无法通过 `/sys/kernel/debug/pinctrl/*/pinmux-pins`
核对引脚状态；`CONFIG_DEVMEM=y` 且未启用 `STRICT_DEVMEM`，可用 `/dev/mem` 读
`MIO_PIN_46..51`（`0xF80007B8..0xF80007CC`）进一步确认。

## 4. 结论

- 纯 PS 方案不使用 eMMC：需在 PL 内实现 SD/MMC 控制器并加载比特流。
- 设备树保留 `sdhci1` 启用无副作用，仅多一行初始化失败提示；需要完全静默时使用
  `boot/system-sdonly.dtb`。
