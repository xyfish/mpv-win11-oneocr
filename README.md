# mpv-win11-oneocr

mpv lua script based on [b1tg/win11-oneocr](https://github.com/b1tg/win11-oneocr), key binding is ctrl+o

![](./ocr.jpg)

How to use:

The code depends on the DLLs and offline AI model, the easiest way is copy those files from SnippingTool folder, puts them in the same folder of mpv.exe

includes:

- oneocr.dll
- oneocr.onemodel
- onnxruntime.dll

## Advantages

### Compared to [Windows Photos](https://apps.microsoft.com/detail/9wzdncrfjbh4)
- Supports OCR on **GIFs** and **videos**
- Can recognize text in images inside **compressed archives** (ZIP, RAR, etc.)
- Works with **low-resolution images** — simply enlarge the window for better results
  - (Windows Photos fails to recognize text at all if the resolution is too low)

### Compared to [b1tg/win11-oneocr](https://github.com/b1tg/win11-oneocr)
- No compilation required
- No OpenCV dependency
