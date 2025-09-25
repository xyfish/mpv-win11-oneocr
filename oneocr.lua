local ffi = require("ffi")
local mp = require("mp")
local utils = require('mp.utils')

local function exec(args)
    mp.msg.error("args: "..utils.format_json(args))
    local ret = mp.command_native({
        name = "subprocess",
        args = args,
        capture_stdout = true,
        capture_stderr = true
    })
    return ret
end

-- DLL 與結構定義
ffi.cdef[[
typedef struct {
    int32_t t;
    int32_t col;
    int32_t row;
    int32_t _unk;
    int64_t step;
    int64_t data_ptr;
} Img;

int64_t CreateOcrInitOptions(int64_t *ctx);
int64_t GetOcrLineCount(int64_t instance, int64_t *count);
int64_t GetOcrLine(int64_t instance, int64_t idx, int64_t *line);
int64_t GetOcrLineContent(int64_t line, int64_t *content);
int64_t CreateOcrProcessOptions(int64_t *opt);
int64_t OcrInitOptionsSetUseModelDelayLoad(int64_t ctx, char val);
int64_t OcrProcessOptionsSetMaxRecognitionLineCount(int64_t opt, int64_t n);
int64_t CreateOcrPipeline(const char *model_path, const char *key, int64_t ctx, int64_t *pipeline);
int64_t RunOcrPipeline(int64_t pipeline, Img *img, int64_t opt, int64_t *instance);
]]

local oneocr = ffi.load("oneocr.dll")

-- OCR 初始化 (只初始化一次)
local ctx = ffi.new("int64_t[1]")
local pipeline = ffi.new("int64_t[1]")
local opt = ffi.new("int64_t[1]")

assert(oneocr.CreateOcrInitOptions(ctx) == 0)
assert(oneocr.OcrInitOptionsSetUseModelDelayLoad(ctx[0], 0) == 0)

local key = "kj)TGtrK>f]b[Piow.gU+nC@s\"\"\"\"\"\"4"
assert(oneocr.CreateOcrPipeline("oneocr.onemodel", key, ctx[0], pipeline) == 0)
assert(oneocr.CreateOcrProcessOptions(opt) == 0)
assert(oneocr.OcrProcessOptionsSetMaxRecognitionLineCount(opt[0], 1000) == 0)

local function capture_frame_ocr(callback)
    -- screenshot-raw async，format=rgba，會傳回 Lua byte array
    mp.command_native_async({
        name = "screenshot-raw",
        format = "rgba",
        flags = "window",
    }, function(success, result, error)
        if success then
            print("result:", result)
            for key, value in pairs(result) do
                if key ~= "data" then
                    mp.msg.info("result."..key..":", value)
                end
            end
            local img = ffi.new("Img")
            img.t = 3
            img.col = result.w
            img.row = result.h
            img._unk = 0
            img.step = result.stride
            img.data_ptr = tonumber(ffi.cast("intptr_t", result.data))
            callback(img)
        else
            mp.osd_message("screenshot-raw 失敗: "..tostring(error), 3)
        end
    end)
end

local function run_ocr(img)
    local instance = ffi.new("int64_t[1]")
    assert(oneocr.RunOcrPipeline(pipeline[0], img, opt[0], instance) == 0)

    local lc = ffi.new("int64_t[1]")
    assert(oneocr.GetOcrLineCount(instance[0], lc) == 0)
    local count = tonumber(lc[0])
    if count == 0 then
        mp.osd_message("OCR 無文字", 3)
        return
    end
    mp.osd_message("OCR 行數: "..count, 3)
    local text = ""
    for i = 0, count do
        local line = ffi.new("int64_t[1]")
        oneocr.GetOcrLine(instance[0], i, line)
        if line[0] ~= 0 then
            local content = ffi.new("int64_t[1]")
            oneocr.GetOcrLineContent(line[0], content)
            local str = ffi.string(ffi.cast("char*", content[0]))
            -- mp.osd_message(str, 3)
            text = text .. str .. "\n"
        end
    end
    local f = io.popen("clip", "w")
    if f then
        f:write(text)
        f:close()
    end
    local ps = [[Add-Type -AssemblyName System.Windows.Forms;$f=New-Object Windows.Forms.Form;$f.Text='複製OCR資訊';$f.Width=1000;$f.Height=800;$f.BackColor='Black';$tb=New-Object Windows.Forms.TextBox;$tb.Multiline=$true;$tb.Dock='Fill';$tb.ScrollBars='Both';$tb.WordWrap=$false;$tb.Text=[Windows.Forms.Clipboard]::GetText();$tb.Font=New-Object System.Drawing.Font('Sarasa Fixed TC',14);$tb.ForeColor='White';$tb.BackColor='Black';$f.Controls.Add($tb);$tb.SelectAll();$f.ShowDialog();]]
    -- os.execute('start powershell -NoProfile -WindowStyle Hidden -Command "'..ps..'"')
    exec({"powershell", "-Command", ps})
end

-- 綁定快捷鍵 ctrl+o
mp.add_key_binding("ctrl+o", "ocr_frame", function()
    capture_frame_ocr(function(img)
        run_ocr(img)
    end)
end)
