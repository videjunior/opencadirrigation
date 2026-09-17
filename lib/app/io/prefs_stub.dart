final Map<String, String> _memory = {};

String? getPref(String key) => _memory[key];
void setPref(String key, String value) => _memory[key] = value;
void removePref(String key) => _memory.remove(key);
