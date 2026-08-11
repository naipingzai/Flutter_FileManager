#include "text_ops.h"

#include <algorithm>
#include <fstream>
#include <string>
#include <vector>

class TextOps {
public:
    int open(const char* path)
    {
        close();

        if (path == nullptr || path[0] == '\0') {
            error_ = "invalid path";
            return -1;
        }

        std::ifstream file(
            path,
            std::ios::binary | std::ios::ate
        );

        if (!file.is_open()) {
            error_ = "failed to open file";
            return -2;
        }

        const std::streampos file_size = file.tellg();

        if (file_size < 0) {
            error_ = "failed to get file size";
            return -3;
        }

        content_.resize(
            static_cast<size_t>(file_size)
        );

        file.seekg(0, std::ios::beg);

        if (!content_.empty()) {
            file.read(
                content_.data(),
                static_cast<std::streamsize>(
                    content_.size()
                )
            );

            if (!file) {
                close();
                error_ = "failed to read file";
                return -3;
            }
        }

        path_ = path;
        buildLineIndex();

        opened_ = true;
        error_.clear();

        return 0;
    }

    void close()
    {
        opened_ = false;
        path_.clear();
        content_.clear();
        line_offsets_.clear();
        error_.clear();
    }

    bool isOpen() const
    {
        return opened_;
    }

    size_t size() const
    {
        return content_.size();
    }

    const char* path() const
    {
        return path_.c_str();
    }

    size_t read(
        size_t offset,
        size_t length,
        char* buffer,
        size_t buffer_size)
    {
        if (!opened_) {
            error_ = "file is not open";
            return 0;
        }

        if (buffer == nullptr || buffer_size == 0) {
            error_ = "invalid buffer";
            return 0;
        }

        if (offset >= content_.size()) {
            buffer[0] = '\0';
            return 0;
        }

        const size_t available =
            content_.size() - offset;

        const size_t count =
            std::min(length, available);

        if (count + 1 > buffer_size) {
            error_ = "buffer is too small";
            return 0;
        }

        std::copy_n(
            content_.data() + offset,
            count,
            buffer
        );

        buffer[count] = '\0';

        return count;
    }

    size_t lineCount() const
    {
        return line_offsets_.size();
    }

    size_t readLine(
        size_t line,
        char* buffer,
        size_t buffer_size)
    {
        if (!opened_) {
            error_ = "file is not open";
            return 0;
        }

        if (buffer == nullptr || buffer_size == 0) {
            error_ = "invalid buffer";
            return 0;
        }

        if (line >= line_offsets_.size()) {
            error_ = "line out of range";
            return 0;
        }

        const size_t start =
            line_offsets_[line];

        size_t end;

        if (line + 1 < line_offsets_.size()) {
            end = line_offsets_[line + 1];
        } else {
            end = content_.size();
        }

        if (end > start &&
            content_[end - 1] == '\n') {
            --end;
        }

        if (end > start &&
            content_[end - 1] == '\r') {
            --end;
        }

        const size_t length = end - start;

        if (length + 1 > buffer_size) {
            error_ = "buffer is too small";
            return 0;
        }

        if (length > 0) {
            std::copy_n(
                content_.data() + start,
                length,
                buffer
            );
        }

        buffer[length] = '\0';

        return length;
    }

    const char* error() const
    {
        return error_.c_str();
    }

private:
    void buildLineIndex()
    {
        line_offsets_.clear();

        if (content_.empty()) {
            return;
        }

        line_offsets_.push_back(0);

        for (size_t i = 0; i < content_.size(); ++i) {
            if (content_[i] == '\n' &&
                i + 1 < content_.size()) {

                line_offsets_.push_back(i + 1);
            }
        }
    }

private:
    bool opened_ = false;

    std::string path_;
    std::string content_;

    std::vector<size_t> line_offsets_;

    std::string error_;
};


// ============================================================
// C API
// ============================================================

extern "C"
TextOpsHandle text_ops_create(void)
{
    try {
        return new TextOps();
    } catch (...) {
        return nullptr;
    }
}

extern "C"
void text_ops_destroy(TextOpsHandle handle)
{
    delete static_cast<TextOps*>(handle);
}

extern "C"
int text_ops_open(
    TextOpsHandle handle,
    const char* path)
{
    if (handle == nullptr) {
        return -1;
    }

    return static_cast<TextOps*>(handle)->open(path);
}

extern "C"
void text_ops_close(TextOpsHandle handle)
{
    if (handle == nullptr) {
        return;
    }

    static_cast<TextOps*>(handle)->close();
}

extern "C"
int text_ops_is_open(TextOpsHandle handle)
{
    if (handle == nullptr) {
        return 0;
    }

    return static_cast<TextOps*>(handle)->isOpen()
        ? 1
        : 0;
}

extern "C"
size_t text_ops_size(TextOpsHandle handle)
{
    if (handle == nullptr) {
        return 0;
    }

    return static_cast<TextOps*>(handle)->size();
}

extern "C"
const char* text_ops_path(TextOpsHandle handle)
{
    if (handle == nullptr) {
        return "";
    }

    return static_cast<TextOps*>(handle)->path();
}

extern "C"
size_t text_ops_read(
    TextOpsHandle handle,
    size_t offset,
    size_t length,
    char* buffer,
    size_t buffer_size)
{
    if (handle == nullptr) {
        return 0;
    }

    return static_cast<TextOps*>(handle)->read(
        offset,
        length,
        buffer,
        buffer_size
    );
}

extern "C"
size_t text_ops_line_count(TextOpsHandle handle)
{
    if (handle == nullptr) {
        return 0;
    }

    return static_cast<TextOps*>(handle)->lineCount();
}

extern "C"
size_t text_ops_read_line(
    TextOpsHandle handle,
    size_t line,
    char* buffer,
    size_t buffer_size)
{
    if (handle == nullptr) {
        return 0;
    }

    return static_cast<TextOps*>(handle)->readLine(
        line,
        buffer,
        buffer_size
    );
}

extern "C"
const char* text_ops_error(TextOpsHandle handle)
{
    if (handle == nullptr) {
        return "invalid handle";
    }

    return static_cast<TextOps*>(handle)->error();
}