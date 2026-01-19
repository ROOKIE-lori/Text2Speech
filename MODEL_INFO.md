# Sherpa-ONNX TTS 模型信息

## 当前使用的模型

### 1. 女声模型：vits-zh-aishell3

- **模型名称**: `vits-zh-aishell3`
- **下载地址**: https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-aishell3.tar.bz2
- **模型类型**: VITS (Variational Inference with adversarial learning for end-to-end Text-to-Speech)
- **语言**: 中文（普通话）
- **语音类型**: 女声

#### 模型文件信息（从代码日志中获取）

根据应用运行时的日志输出，模型文件信息如下：

- **主模型文件**: `vits-aishell3.onnx`
  - 文件大小：约 **121 MB** (121,383,104 字节)
  - 格式：ONNX (FP32)

- **量化模型文件**: `vits-aishell3.int8.onnx`
  - 文件大小：约 **38 MB** (39,870,124 字节)
  - 格式：ONNX (INT8 量化)

- **其他文件**:
  - `tokens.txt`: 1,671 字节（词汇表）
  - `lexicon.txt`: 2,042,943 字节（约 2 MB，词典）
  - `rule.far`: 180,717,014 字节（约 172 MB，规则文件）
  - 其他 FST 文件（date.fst, phone.fst, number.fst, new_heteronym.fst）

#### 压缩包大小

- **压缩包**: `vits-zh-aishell3.tar.bz2`
- **解压后总大小**: 约 **350-400 MB**

#### 参数量估算

基于模型文件大小估算：
- **FP32 模型** (121 MB): 约 **30-35 百万参数** (30-35M)
  - 计算：121 MB ÷ 4 字节/参数 ≈ 30.25M 参数
- **INT8 模型** (38 MB): 参数量相同，但精度降低

### 2. 男声模型：vits-melo-tts-zh_en

- **模型名称**: `vits-melo-tts-zh_en`
- **下载地址**: https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2
- **模型类型**: VITS (MeloTTS 版本)
- **语言**: 中文 + 英文（双语）
- **语音类型**: 男声

#### 模型文件信息

- **压缩包**: `vits-melo-tts-zh_en.tar.bz2`
- **预估大小**: 与 vits-zh-aishell3 类似，约 **300-400 MB**（解压后）

## 模型架构说明

### VITS 模型特点

1. **端到端训练**: 直接从文本生成语音波形，无需中间特征
2. **高质量合成**: 生成自然、流畅的语音
3. **支持中文**: 针对中文语音优化

### 模型文件结构

```
模型目录/
├── vits-aishell3.onnx          # 主模型（FP32）
├── vits-aishell3.int8.onnx     # 量化模型（INT8，可选）
├── tokens.txt                  # 词汇表
├── lexicon.txt                 # 词典（可选）
├── rule.far                    # 规则文件（中文文本处理）
├── date.fst                    # 日期处理规则
├── phone.fst                   # 音素处理规则
├── number.fst                  # 数字处理规则
└── new_heteronym.fst           # 多音字处理规则
```

## 性能对比

| 模型版本 | 文件大小 | 参数量（估算） | 推理速度 | 音质 |
|---------|---------|--------------|---------|------|
| FP32 | ~121 MB | ~30-35M | 较慢 | 最佳 |
| INT8 | ~38 MB | ~30-35M | 较快 | 良好 |

## 使用建议

1. **默认使用 FP32 模型**: 音质更好
2. **设备性能较低时**: 可使用 INT8 量化模型，速度更快
3. **存储空间**: 确保设备有至少 500 MB 可用空间（包含解压后的所有文件）

## 下载和存储

- **下载位置**: 应用文档目录下的 `sherpa-onnx-tts-model/` 文件夹
- **按语音类型分类**: 
  - `female/` - 女声模型
  - `male/` - 男声模型
- **首次使用**: 需要从 GitHub 下载，下载时间取决于网络速度

## 参考链接

- Sherpa-ONNX 官方仓库: https://github.com/k2-fsa/sherpa-onnx
- 模型下载页面: https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models
- VITS 论文: https://arxiv.org/abs/2106.06103
