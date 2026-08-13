// text_ops - 大文本文件高效读取
// 打开时扫描建立行偏移索引，支持 O(1) 按行读取 + 按偏移读取
#include "fs.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <string>
#include <vector>

namespace {

constexpr size_t kErrorBufSize = 256;

struct TextOpsImpl {
    FILE* fp = nullptr;
    std::string path;
    size_t file_size = 0;
    // 每行起始偏移（0-based），line_count = offsets.size()
    std::vector<size_t> line_offsets;
    char error[kErrorBufSize] = {0};

    void set_error(const char* msg) {
        snprintf(error, kErrorBufSize, "%s", msg ? msg : "unknown error");
    }
};

// 扫描文件建立行偏移索引
bool build_line_index(TextOpsImpl* impl) {
    if (!impl || !impl->fp) return false;
    fseek(impl->fp, 0, SEEK_END);
    long size = ftell(impl->fp);
    if (size < 0) return false;
    impl->file_size = (size_t)size;
    fseek(impl->fp, 0, SEEK_SET);

    impl->line_offsets.clear();
    impl->line_offsets.push_back(0); // 第 0 行从偏移 0 开始

    const size_t kBufSize = 64 * 1024;
    std::vector<char> buf(kBufSize);
    size_t pos = 0;
    while (pos < impl->file_size) {
        size_t to_read = kBufSize;
        if (impl->file_size - pos < to_read) {
            to_read = impl->file_size - pos;
        }
        size_t rd = fread(buf.data(), 1, to_read, impl->fp);
        if (rd == 0) break;
        for (size_t i = 0; i < rd; i++) {
            if (buf[i] == '\n') {
                impl->line_offsets.push_back(pos + i + 1);
            }
        }
        pos += rd;
    }
    return true;
}

} // namespace

// ============================================================
// C API 实现（extern "C" 保证符号不被 name-mangle）
// ============================================================
extern "C" {

FsTextReader fs_text_create(void) {
    return new TextOpsImpl();
}

void fs_text_destroy(FsTextReader handle) {
    TextOpsImpl* impl = static_cast<TextOpsImpl*>(handle);
    if (!impl) return;
    if (impl->fp) fclose(impl->fp);
    delete impl;
}

int fs_text_open(FsTextReader handle, const char* path) {
    TextOpsImpl* impl = static_cast<TextOpsImpl*>(handle);
    if (!impl || !path) return -1;

    if (impl->fp) {
        fclose(impl->fp);
        impl->fp = nullptr;
    }
    impl->line_offsets.clear();
    impl->file_size = 0;
    impl->path.clear();
    impl->error[0] = '\0';

    FILE* fp = fopen(path, "rb");
    if (!fp) {
        impl->set_error("open failed");
        return -1;
    }
    impl->fp = fp;
    impl->path = path;

    if (!build_line_index(impl)) {
        impl->set_error("scan failed");
        fclose(impl->fp);
        impl->fp = nullptr;
        return -1;
    }
    return 0;
}

void fs_text_close(FsTextReader handle) {
    TextOpsImpl* impl = static_cast<TextOpsImpl*>(handle);
    if (!impl) return;
    if (impl->fp) {
        fclose(impl->fp);
        impl->fp = nullptr;
    }
    impl->line_offsets.clear();
    impl->file_size = 0;
    impl->path.clear();
}

int fs_text_is_open(FsTextReader handle) {
    TextOpsImpl* impl = static_cast<TextOpsImpl*>(handle);
    return (impl && impl->fp) ? 1 : 0;
}

size_t fs_text_size(FsTextReader handle) {
    TextOpsImpl* impl = static_cast<TextOpsImpl*>(handle);
    return impl ? impl->file_size : 0;
}

const char* fs_text_path(FsTextReader handle) {
    TextOpsImpl* impl = static_cast<TextOpsImpl*>(handle);
    return (impl && !impl->path.empty()) ? impl->path.c_str() : "";
}

size_t fs_text_read(FsTextReader handle, size_t offset, size_t length,
                     unsigned char* buffer, size_t buffer_size) {
    TextOpsImpl* impl = static_cast<TextOpsImpl*>(handle);
    if (!impl || !impl->fp || !buffer || buffer_size == 0) return 0;
    if (offset >= impl->file_size || length == 0) return 0;

    size_t avail = impl->file_size - offset;
    size_t to_read = length < avail ? length : avail;
    if (to_read > buffer_size - 1) {
        to_read = buffer_size - 1;
    }
    if (to_read == 0) return 0;

    if (fseek(impl->fp, (long)offset, SEEK_SET) != 0) {
        impl->set_error("seek failed");
        return 0;
    }
    size_t rd = fread(buffer, 1, to_read, impl->fp);
    return rd;
}

size_t fs_text_line_count(FsTextReader handle) {
    TextOpsImpl* impl = static_cast<TextOpsImpl*>(handle);
    return impl ? impl->line_offsets.size() : 0;
}

size_t fs_text_read_line(FsTextReader handle, size_t line,
                          unsigned char* buffer, size_t buffer_size) {
    TextOpsImpl* impl = static_cast<TextOpsImpl*>(handle);
    if (!impl || !impl->fp || !buffer || buffer_size == 0) return 0;
    if (line >= impl->line_offsets.size()) return 0;

    size_t start = impl->line_offsets[line];
    size_t end;
    if (line + 1 < impl->line_offsets.size()) {
        end = impl->line_offsets[line + 1];
    } else {
        end = impl->file_size;
    }
    // 去掉行尾换行符
    if (end > start && (impl->file_size > 0)) {
        // 读该行内容到临时缓冲判断末尾
        size_t len = end - start;
        if (len > buffer_size - 1) len = buffer_size - 1;
        if (fseek(impl->fp, (long)start, SEEK_SET) != 0) {
            impl->set_error("seek failed");
            return 0;
        }
        size_t rd = fread(buffer, 1, len, impl->fp);
        if (rd > 0 && (buffer[rd - 1] == '\n')) rd--;
        if (rd > 0 && (buffer[rd - 1] == '\r')) rd--;
        return rd;
    }
    return 0;
}

const char* fs_text_error(FsTextReader handle) {
    TextOpsImpl* impl = static_cast<TextOpsImpl*>(handle);
    return impl ? impl->error : "";
}

} // extern "C"
