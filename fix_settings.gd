extends SceneTree
func _init():
    var es = EditorInterface.get_editor_settings()
    if es:
        es.set("export/android/android_sdk_path", "/usr/local/lib/android/sdk")
        es.set("export/android/debug_keystore", "/home/runner/work/LiarsBarGodot/LiarsBarGodot/debug.keystore")
        es.set("export/android/debug_keystore_user", "androiddebugkey")
        es.set("export/android/debug_keystore_pass", "android")
        es.save()
        print("Settings saved")
    quit()
