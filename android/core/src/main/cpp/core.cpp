#include <jni.h>

#ifdef LIBCLASH

#include "jni_helper.h"
#include "libclash.h"
#include "bride.h"

#include <cstdlib>
#include <cstring>
#include <unistd.h>

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_follow_clash_core_Core_startTun(JNIEnv *env, jobject thiz, jint fd, jobject cb,
                                         jstring stack, jstring address, jstring dns) {
    if (cb == nullptr || stack == nullptr || address == nullptr || dns == nullptr) {
        close(fd);
        return JNI_FALSE;
    }
    const auto interface = new_global(cb);
    if (interface == nullptr || jni_catch_exception(env)) {
        close(fd);
        return JNI_FALSE;
    }
    return startTUN(interface, fd, get_string(stack), get_string(address), get_string(dns))
           ? JNI_TRUE : JNI_FALSE;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_stopTun(JNIEnv *env, jobject thiz) {
    stopTun();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_forceGC(JNIEnv *env, jobject thiz) {
    forceGC();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_updateDNS(JNIEnv *env, jobject thiz, jstring dns) {
    updateDns(get_string(dns));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_invokeAction(JNIEnv *env, jobject thiz, jstring data, jobject cb) {
    if (data == nullptr || cb == nullptr) return;
    const auto interface = new_global(cb);
    if (interface == nullptr || jni_catch_exception(env)) return;
    invokeAction(interface, get_string(data));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_setEventListener(JNIEnv *env, jobject thiz, jobject cb) {
    if (cb != nullptr) {
        const auto interface = new_global(cb);
        if (interface == nullptr || jni_catch_exception(env)) return;
        setEventListener(interface);
    } else {
        setEventListener(nullptr);
    }
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getTraffic(JNIEnv *env, jobject thiz,
                                           const jboolean only_statistics_proxy) {
    char *traffic = getTraffic(only_statistics_proxy);
    jstring result = new_string(traffic);
    free_string(traffic);
    return result;
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getTotalTraffic(JNIEnv *env, jobject thiz,
                                                const jboolean only_statistics_proxy) {
    char *traffic = getTotalTraffic(only_statistics_proxy);
    jstring result = new_string(traffic);
    free_string(traffic);
    return result;
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getTrafficSnapshot(JNIEnv *env, jobject thiz,
                                                   const jboolean only_statistics_proxy) {
    char *traffic = getTrafficSnapshot(only_statistics_proxy);
    jstring result = new_string(traffic);
    free_string(traffic);
    return result;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_suspended(JNIEnv *env, jobject thiz, jboolean suspended) {
    suspend(suspended);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_quickSetup(JNIEnv *env, jobject thiz, jstring init_params_string,
                                           jstring setup_params_string, jobject cb) {
    if (init_params_string == nullptr || setup_params_string == nullptr || cb == nullptr) return;
    const auto interface = new_global(cb);
    if (interface == nullptr || jni_catch_exception(env)) return;
    quickSetup(interface, get_string(init_params_string), get_string(setup_params_string));
}


static jmethodID m_tun_interface_protect;
static jmethodID m_tun_interface_resolve_process;
static jmethodID m_invoke_interface_result;


static void release_jni_object_impl(void *obj) {
    if (obj == nullptr) return;
    ATTACH_JNI();
    del_global(static_cast<jobject>(obj));
    jni_catch_exception(env);
}

static void free_string_impl(char *str) {
    free(str);
}

static void call_tun_interface_protect_impl(void *tun_interface, const int fd) {
    if (tun_interface == nullptr || m_tun_interface_protect == nullptr) return;
    ATTACH_JNI();
    env->CallVoidMethod(static_cast<jobject>(tun_interface),
                        m_tun_interface_protect,
                        fd);
    jni_catch_exception(env);
}

static char *
call_tun_interface_resolve_process_impl(void *tun_interface, const int protocol,
                                        const char *source,
                                        const char *target,
                                        const int uid) {
    if (tun_interface == nullptr || m_tun_interface_resolve_process == nullptr ||
        source == nullptr || target == nullptr) {
        return strdup("");
    }
    ATTACH_JNI();
    const auto j_source = new_string(source);
    const auto j_target = new_string(target);
    if (j_source == nullptr || j_target == nullptr || jni_catch_exception(env)) {
        if (j_source != nullptr) env->DeleteLocalRef(j_source);
        if (j_target != nullptr) env->DeleteLocalRef(j_target);
        return strdup("");
    }
    const auto packageName = reinterpret_cast<jstring>(env->CallObjectMethod(
            static_cast<jobject>(tun_interface),
            m_tun_interface_resolve_process,
            protocol,
            j_source,
            j_target,
            uid));
    if (jni_catch_exception(env)) {
        env->DeleteLocalRef(j_source);
        env->DeleteLocalRef(j_target);
        return strdup("");
    }
    char *result;
    if (packageName != nullptr) {
        result = get_string(packageName);
        env->DeleteLocalRef(packageName);
    } else {
        result = static_cast<char *>(malloc(1));
        result[0] = 0;
    }
    env->DeleteLocalRef(j_source);
    env->DeleteLocalRef(j_target);
    return result;
}

static void call_invoke_interface_result_impl(void *invoke_interface, const char *data) {
    if (invoke_interface == nullptr || m_invoke_interface_result == nullptr || data == nullptr) return;
    ATTACH_JNI();
    const auto j_data = new_string(data);
    if (j_data == nullptr || jni_catch_exception(env)) return;
    env->CallVoidMethod(static_cast<jobject>(invoke_interface),
                        m_invoke_interface_result,
                        j_data);
    jni_catch_exception(env);
    env->DeleteLocalRef(j_data);
}

extern "C"
JNIEXPORT jint JNICALL
JNI_OnLoad(JavaVM *vm, void *) {
    JNIEnv *env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }

    initialize_jni(vm, env);

    const auto c_tun_interface = find_class("com/follow/clash/core/TunInterface");
    if (c_tun_interface == nullptr || jni_catch_exception(env)) return JNI_ERR;

    const auto c_invoke_interface = find_class("com/follow/clash/core/InvokeInterface");
    if (c_invoke_interface == nullptr || jni_catch_exception(env)) return JNI_ERR;

    m_tun_interface_protect = find_method(c_tun_interface, "protect", "(I)V");
    m_tun_interface_resolve_process = find_method(c_tun_interface, "resolverProcess",
                                                  "(ILjava/lang/String;Ljava/lang/String;I)Ljava/lang/String;");
    m_invoke_interface_result = find_method(c_invoke_interface, "onResult",
                                            "(Ljava/lang/String;)V");

    if (jni_catch_exception(env) || m_tun_interface_protect == nullptr ||
        m_tun_interface_resolve_process == nullptr ||
        m_invoke_interface_result == nullptr) {
        return JNI_ERR;
    }


    protect_func = &call_tun_interface_protect_impl;
    resolve_process_func = &call_tun_interface_resolve_process_impl;
    result_func = &call_invoke_interface_result_impl;
    release_object_func = &release_jni_object_impl;
    free_string_func = &free_string_impl;

    return JNI_VERSION_1_6;
}
#else
extern "C"
JNIEXPORT jboolean JNICALL
Java_com_follow_clash_core_Core_startTun(JNIEnv *env, jobject thiz, jint fd, jobject cb,
                                         jstring stack, jstring address, jstring dns) {
    return JNI_FALSE;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_stopTun(JNIEnv *env, jobject thiz) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_invokeAction(JNIEnv *env, jobject thiz, jstring data, jobject cb) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_forceGC(JNIEnv *env, jobject thiz) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_updateDNS(JNIEnv *env, jobject thiz, jstring dns) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_setEventListener(JNIEnv *env, jobject thiz, jobject cb) {
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getTraffic(JNIEnv *env, jobject thiz,
                                           const jboolean only_statistics_proxy) {
}
extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getTotalTraffic(JNIEnv *env, jobject thiz,
                                                const jboolean only_statistics_proxy) {
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_follow_clash_core_Core_getTrafficSnapshot(JNIEnv *env, jobject thiz,
                                                   const jboolean only_statistics_proxy) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_suspended(JNIEnv *env, jobject thiz, jboolean suspended) {
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clash_core_Core_quickSetup(JNIEnv *env, jobject thiz, jstring init_params_string,
                                           jstring setup_params_string, jobject cb) {
}
#endif
