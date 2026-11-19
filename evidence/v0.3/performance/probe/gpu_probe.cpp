// Temporary diagnostic for a local copy of the project. Execute the three
// methods on Godot's rendering thread with a current OpenGL context.
#define GL_SILENCE_DEPRECATION
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl3.h>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

#include <algorithm>
#include <cstdio>
#include <vector>

using namespace godot;

class TaoistFrameGpuProbe : public RefCounted {
    GDCLASS(TaoistFrameGpuProbe, RefCounted)
    struct Query {
        GLuint begin = 0, end = 0;
        int64_t frame = 0;
        bool elapsed = false;
    };
    CGLContextObj context = nullptr;
    bool discovered = false, ready = false, active = false, finished = false;
    bool clock_pair = false;
    int no_context = 0, changed_context = 0, rejected = 0, skipped = 0;
    Query current;
    std::vector<Query> queued;
    std::vector<double> samples;
    std::vector<int64_t> sample_frames;
    void discover(CGLContextObj c) {
        discovered = true;
        context = c;
        GLint time_bits = 0, stamp_bits = 0;
        glGetQueryiv(GL_TIME_ELAPSED, GL_QUERY_COUNTER_BITS, &time_bits);
        glGetQueryiv(GL_TIMESTAMP, GL_QUERY_COUNTER_BITS, &stamp_bits);
        auto code = glGetError();
        clock_pair = time_bits == 0;
        ready = (time_bits > 0 || stamp_bits > 0) && code == GL_NO_ERROR;
        std::printf("GPU_QUERY_CAPS renderer=%s gl=%s elapsed_bits=%d timestamp_bits=%d error=0x%x\n",
            glGetString(GL_RENDERER), glGetString(GL_VERSION), time_bits, stamp_bits, code);
        std::fflush(stdout);
    }
    void collect(bool drain) {
        auto it = queued.begin();
        for (; it != queued.end(); ++it) {
            GLuint available = GL_FALSE;
            glGetQueryObjectuiv(it->end, GL_QUERY_RESULT_AVAILABLE, &available);
            if (!available && !drain) break;
            GLuint64 begin = 0, end = 0;
            if (!it->elapsed) glGetQueryObjectui64v(it->begin, GL_QUERY_RESULT, &begin);
            glGetQueryObjectui64v(it->end, GL_QUERY_RESULT, &end);
            if (it->begin) glDeleteQueries(1, &it->begin);
            glDeleteQueries(1, &it->end);
            if (end > begin && glGetError() == GL_NO_ERROR) {
                samples.push_back(double(end - begin) / 1.0e6);
                sample_frames.push_back(it->frame);
            } else ++rejected;
        }
        queued.erase(queued.begin(), it);
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("before_frame", "frame"), &TaoistFrameGpuProbe::before_frame);
        ClassDB::bind_method(D_METHOD("after_frame"), &TaoistFrameGpuProbe::after_frame);
        ClassDB::bind_method(D_METHOD("finish"), &TaoistFrameGpuProbe::finish);
    }

public:
    void before_frame(int64_t frame) {
        CGLContextObj c = CGLGetCurrentContext();
        if (!c) { ++no_context; return; }
        if (!discovered) discover(c);
        if (c != context) { ++changed_context; return; }
        if (!ready || finished || active) return;
        collect(false);
        if (queued.size() >= 256) { ++skipped; return; }
        current = {};
        current.frame = frame;
        if (clock_pair) {
            glGenQueries(1, &current.begin);
            glGenQueries(1, &current.end);
            glQueryCounter(current.begin, GL_TIMESTAMP);
        } else {
            // Leave any query opened by Godot itself undisturbed.
            GLint existing = 0;
            glGetQueryiv(GL_TIME_ELAPSED, GL_CURRENT_QUERY, &existing);
            if (existing) { ++skipped; return; }
            current.elapsed = true;
            glGenQueries(1, &current.end);
            glBeginQuery(GL_TIME_ELAPSED, current.end);
        }
        active = true;
    }

    void after_frame() {
        if (!active) return;
        if (context != CGLGetCurrentContext()) { ++changed_context; return; }
        if (current.elapsed) glEndQuery(GL_TIME_ELAPSED);
        else glQueryCounter(current.end, GL_TIMESTAMP);
        queued.push_back(current);
        active = false;
    }

    void finish() {
        if (finished) return;
        finished = true;
        if (ready && context == CGLGetCurrentContext()) {
            after_frame();
            glFlush();
            collect(true);
        }
        for (size_t i = 0; i < samples.size(); ++i)
            std::printf("GPU_FRAME_NATIVE frame=%lld ms=%.6f\n", (long long)sample_frames[i], samples[i]);
        std::printf("GPU_NATIVE_SUMMARY samples=%zu no_context=%d changed_context=%d rejected=%d skipped=%d",
            samples.size(), no_context, changed_context, rejected, skipped);
        if (!samples.empty()) {
            std::sort(samples.begin(), samples.end());
            std::printf(" timer=%s p50=%.3f p95=%.3f p99=%.3f", clock_pair ? "GL_TIMESTAMP" : "GL_TIME_ELAPSED",
                samples[samples.size()/2], samples[samples.size()*95/100], samples[samples.size()*99/100]);
        }
        std::printf("\n"); std::fflush(stdout);
    }
};

void init_probe(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) GDREGISTER_CLASS(TaoistFrameGpuProbe);
}
void stop_probe(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT taoist_gpu_probe_init(
    GDExtensionInterfaceGetProcAddress get, const GDExtensionClassLibraryPtr lib,
    GDExtensionInitialization *init) {
    GDExtensionBinding::InitObject extension(get, lib, init);
    extension.register_initializer(init_probe);
    extension.register_terminator(stop_probe);
    extension.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return extension.init();
}
