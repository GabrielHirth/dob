#ifndef DOB_INSTALLER_CONFIG_H
#define DOB_INSTALLER_CONFIG_H

#ifndef DOB_UNIT_TEST
#include <QString>
#else
// Minimal QString stub for unit testing
#include <string>
class QString {
public:
    QString() = default;
    QString(const char* s) : data(s) {}
    QString(const std::string& s) : data(s) {}

    QString& operator=(const char* s) { data = s; return *this; }
    QString& operator=(const std::string& s) { data = s; return *this; }

    bool operator==(const QString& other) const { return data == other.data; }
    bool operator==(const char* s) const { return data == s; }
    bool operator!=(const QString& other) const { return data != other.data; }

    const char* toUtf8() const { return data.c_str(); }
    const std::string& toStdString() const { return data; }

    QString operator+(const QString& other) const { return QString(data + other.data); }
    QString operator+(const char* s) const { return QString(data + s); }
    QString& operator+=(const QString& other) { data += other.data; return *this; }

private:
    std::string data;
};
#endif

// InstallConfig holds the user's installation choices.
// Consumed by installer pages (Tasks 7-9).
struct InstallConfig {
    enum FsType { ZFS, UFS };

    QString language;    // default "en"
    QString keymap;      // default "us"
    QString diskTarget;  // device path, e.g. /dev/ada0
    FsType fsType = ZFS; // ZFS default
    QString userName;
    QString password;
    QString hostname;
    bool autologin = false;

    InstallConfig();
};

#endif // DOB_INSTALLER_CONFIG_H
